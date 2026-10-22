module CQL::Postgres
  class Session
    private def run_extended(sql : String, params : Array(Types::Param), cache : Bool, retried : Bool = false) : Result
      statement = prepared(sql, cache)
      execute_bound(statement, params)
      collect(statement.columns)
    rescue ex : ServerError
      forget_statements(sql, ex) if cache && outdated_statement?(ex)
      raise ex if retried || !retryable?(ex, cache)
      run_extended(sql, params, cache, retried: true)
    end

    # A stale cached plan, or a statement the server no longer knows (after
    # DEALLOCATE ALL, a pooler reset or a failover).
    private def outdated_statement?(error : ServerError) : Bool
      error.stale_plan? || error.sqlstate == "26000"
    end

    # Preparing again fixes it, unless a transaction is open (the failed
    # statement aborted it, so the caller has to roll back first).
    private def retryable?(error : ServerError, cache : Bool) : Bool
      cache && !in_transaction? && outdated_statement?(error)
    end

    private def forget_statements(sql : String, error : ServerError) : Nil
      if error.stale_plan?
        @cache.delete(sql).try { |stale| @retired << stale }
      else
        @cache.clear
      end
    end

    private def prepared(sql : String, cache : Bool) : PreparedStatement
      return unwrap(describe_all([sql], [""]).first) unless cache && @cache.enabled?
      @cache.fetch(sql) || begin
        evicted = @cache.evict(room: 1)
        unwrap(describe_all([sql], [@cache.next_name], evicted).first).tap { |statement| @cache.store(sql, statement) }
      end
    end

    # Parse + Describe each statement, every one ending in its own Sync so a
    # failed one doesn't swallow the rest. *evicted* and retired statements are
    # closed in the same round trip.
    private def describe_all(sqls : Array(String), names : Array(String), evicted : Array(PreparedStatement) = [] of PreparedStatement) : Array(PreparedStatement | ServerError)
      stage_describe(sqls, names, evicted + @retired)
      @retired.clear
      flush
      names.map { |name| read_description(name) }
    end

    # Frames for closing statements the cache gave up, then Parse + Describe
    # + Sync per statement. If a statement cannot be encoded nothing is sent and
    # the statements waiting to be closed are remembered for the next request.
    private def stage_describe(sqls : Array(String), names : Array(String), closing : Array(PreparedStatement)) : Nil
      closing.each { |statement| Wire::Frontend.close_statement(@out, statement.name) }
      sqls.each_with_index do |sql, index|
        Wire::Frontend.parse(@out, names[index], sql)
        Wire::Frontend.describe_statement(@out, names[index])
        queue_sync
      end
    rescue ex : ArgumentError
      @retired.concat(closing - @retired)
      raise ex
    end

    private def read_description(name : String) : PreparedStatement | ServerError
      param_count = 0
      columns = [] of Column
      until_ready do |message|
        case message
        when Wire::Backend::ParameterDescription then param_count = message.type_oids.size
        when Wire::Backend::RowDescription       then columns = message.fields.map { |field| Column.new(field.name, field.type_oid, Types.codec_for(field.type_oid)) }
        end
      end
      PreparedStatement.new(name, param_count, columns)
    rescue ex : ServerError
      ex
    end

    private def unwrap(statement : PreparedStatement | ServerError) : PreparedStatement
      statement.is_a?(ServerError) ? raise(statement) : statement
    end

    private def check_parameters(statement : PreparedStatement, params : Array(Types::Param)) : Nil
      return if params.size == statement.param_count
      raise ArgumentError.new("the statement takes #{statement.param_count} parameters, got #{params.size}")
    end

    private def write_execution(statement : PreparedStatement, params : Array(Types::Param)) : Nil
      Wire::Frontend.bind(@out, statement.name, params, statement.result_formats)
      Wire::Frontend.execute(@out)
      queue_sync
    end

    private def execute_bound(statement : PreparedStatement, params : Array(Types::Param)) : Nil
      check_parameters(statement, params)
      write_execution(statement, params)
      flush
    end

    private def collect(columns : Array(Column)) : Result
      rows = [] of Array(Types::Value)
      tag = ""
      until_ready(extended: true) do |message|
        case message
        when Wire::Backend::DataRow         then rows << decode(message, columns)
        when Wire::Backend::CommandComplete then tag = message.tag
        end
      end
      Result.new(columns, rows, tag)
    end

    private def decode(row : Wire::Backend::DataRow, columns : Array(Column)) : Array(Types::Value)
      raise ProtocolError.new("row has #{row.size} values for #{columns.size} columns") unless row.size == columns.size
      values = Array(Types::Value).new(columns.size)
      row.each_field do |field|
        values << field.try { |bytes| columns[values.size].codec.decode.call(bytes) }
      end
      values
    end

    private def run_simple(sql : String) : Array(Result)
      queue_query(sql)
      flush
      results = [] of Result
      columns = [] of Column
      rows = [] of Array(Types::Value)
      until_ready do |message|
        case message
        when Wire::Backend::RowDescription
          columns = message.fields.map { |field| Column.new(field.name, field.type_oid, Types::TEXT_CODEC) }
        when Wire::Backend::DataRow then rows << decode(message, columns)
        when Wire::Backend::CommandComplete
          results << Result.new(columns, rows, message.tag)
          columns, rows = [] of Column, [] of Array(Types::Value)
        end
      end
      results
    end
  end
end
