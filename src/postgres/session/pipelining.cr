module CQL::Postgres
  class Session
    # A batch is written completely before any reply is read, so it has to fit
    # in the socket buffers: if the server's replies filled our receive buffer
    # while we were still writing, neither side could make progress.
    PIPELINE_BATCH_BYTES = 32 * 1024

    alias PipelineStatement = {String, Array(Types::Param)}

    private def run_pipeline(statements : Array(PipelineStatement)) : Array(Result | ServerError)
      statements.each { |(sql, _)| reject_copy(sql) }
      batches(statements).flat_map { |batch| run_batch(batch) }
    end

    private def batches(statements : Array(PipelineStatement)) : Array(Array(PipelineStatement))
      batches = [[] of PipelineStatement]
      size = 0
      statements.each do |statement|
        cost = request_size(statement)
        if size + cost > PIPELINE_BATCH_BYTES && !batches.last.empty?
          batches << [] of PipelineStatement
          size = 0
        end
        batches.last << statement
        size += cost
      end
      batches
    end

    # COPY changes the protocol state for everything queued behind it.
    private def reject_copy(sql : String) : Nil
      raise ArgumentError.new("COPY cannot be pipelined; use copy_in or copy_out") if sql.matches?(/\A(?:\s|--[^\n]*\n|\/\*.*?\*\/)*copy\b/im)
    end

    private def request_size(statement : PipelineStatement) : Int32
      sql, params = statement
      sql.bytesize + params.sum { |param| (param.value.try(&.size) || 0) + 8 } + 64
    end

    private def run_batch(statements : Array(PipelineStatement)) : Array(Result | ServerError)
      raise_if_deadline_passed
      prepared = prepare_for_pipeline(statements.map(&.first))
      statements.each do |sql, params|
        statement = prepared[sql]
        check_parameters(statement, params) if statement.is_a?(PreparedStatement)
      end
      statements.each do |sql, params|
        statement = prepared[sql]
        write_execution(statement, params) if statement.is_a?(PreparedStatement)
      end
      flush
      collect_batch(statements, prepared)
    end

    # Reads every slot even if one fails for a reason other than the server's
    # error, so no reply is left unread; that failure is raised afterwards.
    private def collect_batch(statements : Array(PipelineStatement), prepared : Hash(String, PreparedStatement | ServerError)) : Array(Result | ServerError)
      results = [] of Result | ServerError
      failure = nil
      statements.each do |(sql, _)|
        results << collect_in_pipeline(sql, prepared[sql])
        raise_if_deadline_passed
      rescue ex : CallerError
        failure ||= ex
      end
      raise failure if failure
      results
    end

    private def prepare_for_pipeline(sqls : Array(String)) : Hash(String, PreparedStatement | ServerError)
      prepared = {} of String => PreparedStatement | ServerError
      sqls.uniq.each { |sql| @cache.fetch(sql).try { |statement| prepared[sql] = statement } }
      missing = sqls.uniq.reject { |sql| prepared.has_key?(sql) }
      return prepared if missing.empty?

      in_use = prepared.values.compact_map { |entry| entry.as?(PreparedStatement).try(&.name) }.to_set
      evicted = @cache.evict(room: missing.size, keep: in_use)
      described = describe_all(missing, missing.map { @cache.next_name }, evicted)
      missing.each_with_index do |sql, index|
        outcome = described[index]
        @cache.store(sql, outcome) if outcome.is_a?(PreparedStatement)
        prepared[sql] = outcome
      end
      prepared
    end

    private def collect_in_pipeline(sql : String, statement : PreparedStatement | ServerError) : Result | ServerError
      return statement if statement.is_a?(ServerError)
      collect(statement.columns)
    rescue ex : ServerError
      raise ex if @closed
      forget_statements(sql, ex) if outdated_statement?(ex)
      ex
    end

    # The watchdog has canceled the statement that was running; whatever is
    # still queued is abandoned (the session is dropped by the caller's ensure).
    private def raise_if_deadline_passed : Nil
      raise QueryTimeout.new("the pipeline timed out; its remaining statements were abandoned") if @deadline_expired
    end
  end
end
