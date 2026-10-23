module CQL::Postgres
  class Session
    # Runs one statement and yields its rows `fetch_size` at a time (Execute
    # with a row limit; the portal stays open between fetches). The session is
    # locked for the whole block, so use another connection inside it. When the
    # block ends, however early, the portal is closed and the session left in
    # sync, ready for the pool; the stream cannot be read afterwards. *timeout*
    # bounds the whole stream, consumer time included: once it passes, the next
    # fetch raises `QueryTimeout` and the session is dropped unless the server
    # confirmed a cancel. `Session#cancel` ends a stream that still has rows to
    # fetch: it cancels the fetch in progress, or, if the portal is suspended and
    # the server has nothing to cancel, makes the next fetch raise `QueryCanceled`.
    # COPY cannot be streamed.
    def stream(sql : String, params : Array(Types::Param) = [] of Types::Param, fetch_size : Int32 = 1000,
               cache : Bool = true, timeout : Time::Span? = nil, & : RowStream -> T) : T forall T
      raise ArgumentError.new("fetch_size must be positive, got #{fetch_size}") unless fetch_size > 0
      exclusive(timeout) do
        @cancel_requested = false
        @streaming = true
        begin
          rows = open_stream(sql, params, cache, fetch_size)
          begin
            yield rows
          ensure
            finish_stream(rows)
          end
        ensure
          @streaming = false
        end
      end
    end

    # The fetches after the first. A cancel that came earlier (the server had
    # nothing running to cancel) ends the stream here; the first fetch always
    # goes out, so a Bind already staged is never left behind.
    protected def fetch_rows(rows : RowStream, fetch_size : Int32) : Nil
      raise QueryTimeout.new("the stream timed out") if @deadline_expired
      raise QueryCanceled.user_request if @cancel_requested
      request_batch(rows, fetch_size)
    end

    private def request_batch(rows : RowStream, fetch_size : Int32) : Nil
      Wire::Frontend.execute(@out, fetch_size)
      Wire::Frontend.flush(@out)
      flush
      read_batch(rows)
    end

    private def open_stream(sql : String, params : Array(Types::Param), cache : Bool, fetch_size : Int32, retried : Bool = false) : RowStream
      statement = prepared(sql, cache)
      rows = RowStream.new(self, statement.columns, fetch_size)
      binding(statement) do
        check_parameters(statement, params)
        Wire::Frontend.bind(@out, statement.name, params, statement.result_formats)
      end
      raise QueryTimeout.new("the stream timed out") if @deadline_expired
      request_batch(rows, fetch_size)
      rows
    rescue ex : ServerError
      forget_statements(sql, ex) if cache && outdated_statement?(ex)
      raise ex if retried || !retryable?(ex, cache)
      open_stream(sql, params, cache, fetch_size, retried: true)
    end

    # Reads until the portal is suspended (more rows wait) or complete. A
    # failure leaves the server skipping messages until a Sync, so the stream
    # is resynchronised before the error is raised. A value that cannot be
    # decoded is held until the fetch has been read to its end, which keeps
    # the session in sync.
    private def read_batch(rows : RowStream) : Nil
      decode_failure = nil
      loop do
        case message = receive
        when Wire::Backend::DataRow
          decode_failure ||= decode_into(rows, message)
        when Wire::Backend::PortalSuspended, Wire::Backend::CommandComplete, Wire::Backend::EmptyQueryResponse
          tag = message.is_a?(Wire::Backend::CommandComplete) ? message.tag : ""
          abandon_stream(rows, decode_failure) if decode_failure
          return message.is_a?(Wire::Backend::PortalSuspended) ? nil : rows.complete(tag)
        when Wire::Backend::ErrorResponse then abandon_stream(rows, ServerError.from(message.fields))
        when Wire::Backend::CopyResponse  then refuse_streamed_copy(rows, message)
        end
      end
    rescue ex : ServerError | ArgumentError | UnsupportedValue | QueryTimeout
      raise ex
    rescue ex
      rows.abort
      hard_close
      raise ex
    end

    private def decode_into(rows : RowStream, message : Wire::Backend::DataRow) : Exception?
      rows.add(decode(message, rows.columns))
      nil
    rescue ex : UnsupportedValue
      ex
    end

    private def abandon_stream(rows : RowStream, failure : Exception) : NoReturn
      rows.abort
      abandon_request(failure)
    end

    private def refuse_streamed_copy(rows : RowStream, message : Wire::Backend::CopyResponse) : NoReturn
      rows.abort
      Wire::Frontend.copy_fail(@out, "COPY cannot be streamed") if message.direction == 'G'
      queue_sync
      flush
      begin
        until_ready(extended: true) { }
      rescue ServerError
      end
      raise ArgumentError.new("COPY cannot be streamed; use copy_in or copy_out")
    end

    # Closing the portal matters inside a transaction, where Sync would
    # leave it (and its locks and sort memory) open until the transaction
    # ends; outside one, Sync destroys it anyway.
    private def finish_stream(rows : RowStream) : Nil
      rows.close
      return if rows.aborted? || @closed || @deadline_expired
      Wire::Frontend.close_portal(@out)
      queue_sync
      flush
      until_ready(extended: true) { }
    end
  end
end
