require "log"
require "openssl"
require "./config"
require "./handshake"
require "./result"
require "./row_stream"
require "./statement_cache"
require "./copy_stream"

module CQL::Postgres
  # One protocol-v3 conversation with a server over a single stream.
  #
  # Every public operation takes the session's lock, so at most one request is
  # in flight and fibers can share a session safely (they queue). The session
  # counts the replies the server still owes (one ReadyForQuery per Sync or
  # simple query it was sent). After a `ServerError`, or an exception raised by
  # the caller's own block, nothing is owed and the session stays usable; any
  # failure that leaves replies unread closes it, since the stream could no
  # longer be matched up with requests.
  #
  # `on_notice` and `on_notification` handlers run while the session's lock is
  # held, so they must not use the same session.
  class Session
    Log = ::Log.for("cql.postgres")

    # Failures of the stream itself are `IO::Error` or, under TLS, `OpenSSL::Error`.
    # (Written out in each `rescue`: rescuing an alias of a union catches everything.)

    # Carries an exception raised by the caller's block through the reply loop,
    # so it is re-raised unchanged once the stream is back in sync.
    private class CallerError < ::Exception
    end

    # Who settled a statement's deadline: still running, the watchdog fired
    # first, or the request finished first.
    private enum Deadline
      Running
      Expiring
      Done
    end

    getter config : Config
    getter process_id : Int32
    getter secret_key : Bytes
    getter protocol_version : ProtocolVersion
    getter server_parameters : Hash(String, String)
    getter transaction_status : Char
    getter last_used : Time::Instant
    # Requests run on this session so far (a pipeline counts once).
    getter requests : Int64 = 0_i64
    property on_notice : Proc(Hash(Char, String), Nil)? = nil
    property on_notification : Proc(Notification, Nil)? = nil

    # Connects, asking for the newest protocol the config allows. A server that
    # rejects that version outright (before PostgreSQL 9.3.21, or some poolers)
    # gets one more try with 3.0 when the config allows it.
    def self.connect(config : Config) : Session
      requested = config.max_protocol_version
      attempt(config, requested)
    rescue ex : ServerError | UnrecognizedStartupReply
      raise ex unless rejected_version?(ex) && requested.try { |version| version > ProtocolVersion::V3_0 } && config.min_protocol_version <= ProtocolVersion::V3_0
      Log.info { "the server rejected protocol #{requested}; reconnecting with 3.0 (set max_protocol_version=3.0 to skip the first attempt)" }
      attempt(config, ProtocolVersion::V3_0)
    end

    private def self.rejected_version?(error : Error) : Bool
      case error
      when UnrecognizedStartupReply then true
      when ServerError              then error.sqlstate.in?("0A000", "08P01")
      else                               false
      end
    end

    private def self.attempt(config : Config, version : ProtocolVersion) : Session
      io = Transport.connect(config)
      begin
        outcome = Handshake.new(config, io, version).run
        Transport.relax(io)
        new(config, io, outcome)
      rescue ex
        io.close
        raise ex
      end
    end

    def initialize(@config : Config, @io : IO, outcome : Handshake::Outcome)
      @process_id = outcome.process_id
      @secret_key = outcome.secret_key
      @protocol_version = outcome.version
      @server_parameters = outcome.parameters
      @transaction_status = outcome.status
      @cache = StatementCache.new(config.statement_cache_size)
      @retired = [] of PreparedStatement
      @out = IO::Memory.new
      @lock = CQL::Compat::Mutex.new
      @closed = false
      @queued = 0
      @owed = 0
      @deadline_expired = false
      @last_used = Time.instant
    end

    def closed? : Bool
      @closed
    end

    def in_transaction? : Bool
      transaction_status != 'I'
    end

    # Runs one statement with bound parameters through the extended protocol,
    # preparing it once per connection when *cache* is on.
    def query(sql : String, params : Array(Types::Param) = [] of Types::Param, cache : Bool = true, timeout : Time::Span? = nil) : Result
      exclusive(timeout) { run_extended(sql, params, cache) }
    end

    # Runs text with the simple protocol, which allows several statements.
    # Every column comes back as text.
    def simple_query(sql : String, timeout : Time::Span? = nil) : Array(Result)
      exclusive(timeout) { run_simple(sql) }
    end

    # Sends several statements before reading any answer, so they cost one
    # network round trip (two for statements not prepared yet). Large batches
    # go out in chunks that fit the socket buffers. Each statement has its own
    # sync point: one failing leaves the others unaffected and shows up as a
    # `ServerError` in its slot. A *timeout* bounds the whole pipeline: when it
    # expires the running statement is canceled, the rest are abandoned, the
    # session is dropped and `QueryTimeout` is raised. A server FATAL raises the
    # error and drops the session; results already read are lost.
    def pipeline(statements : Array({String, Array(Types::Param)}), timeout : Time::Span? = nil) : Array(Result | ServerError)
      raise ArgumentError.new("pipelining needs the statement cache (statement_cache_size > 0)") unless @cache.enabled?
      exclusive(timeout) { run_pipeline(statements) }
    end

    # Streams `COPY ... FROM STDIN`; returns the number of rows copied. If the
    # block raises, the COPY is aborted and the exception re-raised.
    def copy_in(sql : String, timeout : Time::Span? = nil, & : CopyIn ->) : Int64
      exclusive(timeout) { run_copy_in(sql) { |writer| yield writer } }
    end

    # Streams `COPY ... TO STDOUT` chunks to the block; returns rows copied. If
    # the block raises, the remaining chunks are read and dropped before the
    # exception is re-raised.
    def copy_out(sql : String, timeout : Time::Span? = nil, & : Bytes ->) : Int64
      exclusive(timeout) { run_copy_out(sql) { |chunk| yield chunk } }
    end

    # One cheap round trip (an empty query).
    def ping : Bool
      exclusive { run_simple("") }
      true
    rescue Error
      false
    end

    # Asks the server, over a second connection, to cancel what this session is
    # running. Safe to call from any fiber.
    def cancel : Nil
      Transport.cancel(@config, @process_id, @secret_key)
    end

    # Forgets every cached statement after the server dropped them
    # (`DISCARD ALL`, `DEALLOCATE ALL`).
    def forget_prepared_statements : Nil
      @lock.synchronize do
        @cache.clear
        @retired.clear
      end
    end

    # Ends the session politely (Terminate) once any in-flight request is done.
    def close : Nil
      return if @closed
      @lock.synchronize do
        next if @closed
        begin
          Wire::Frontend.terminate(@out)
          flush
        rescue Error
        ensure
          hard_close
        end
      end
    end

    # Drops the stream immediately.
    def hard_close : Nil
      @closed = true
      @io.close
    rescue IO::Error | OpenSSL::Error
    end

    private def exclusive(timeout : Time::Span? = nil, &)
      @lock.synchronize do
        raise ConnectionLost.new("the connection is closed") if @closed
        @deadline_expired = false
        @requests += 1
        guarded { with_deadline(timeout) { yield } }
      ensure
        @last_used = Time.instant
      end
    end

    private def guarded(&)
      yield
    rescue ex : CallerError
      hard_close if @owed > 0 || ex.cause.is_a?(ProtocolError)
      raise ex.cause.not_nil!
    rescue ex : ServerError | QueryTimeout
      hard_close if @owed > 0
      raise ex
    rescue ex : ArgumentError
      hard_close if @owed > 0
      discard_unsent
      raise ex
    rescue ex : IO::TimeoutError
      hard_close
      raise QueryTimeout.new("no answer from the server within the read timeout")
    rescue ex : IO::Error | OpenSSL::Error
      hard_close
      raise ConnectionLost.new("lost the connection to the server: #{ex.message}", cause: ex)
    rescue ex : ProtocolError
      hard_close
      raise ex
    rescue ex
      hard_close if @owed > 0
      discard_unsent
      raise ex
    end

    # Cancels the statement when *timeout* passes. A cancel racing with a
    # statement that just finished could hit the next one, so unless the server
    # confirmed the cancel the session is dropped instead of reused. The
    # watchdog and the request fiber settle who got there first atomically.
    private def with_deadline(timeout : Time::Span?, &)
      return yield unless timeout
      state = Atomic(Deadline).new(Deadline::Running)
      finished = Channel(Nil).new
      cancel_sent = Channel(Nil).new(1)
      spawn do
        select
        when finished.receive?
        when timeout(timeout)
          if state.compare_and_set(Deadline::Running, Deadline::Expiring)[1]
            @deadline_expired = true
            cancel_or_drop
            cancel_sent.send(nil)
          end
        end
      end
      confirmed = false
      begin
        yield
      rescue ex : QueryCanceled
        confirmed = state.get.expiring?
        raise confirmed ? QueryTimeout.new("statement canceled after #{timeout}") : ex
      rescue ex : IO::Error | OpenSSL::Error | ConnectionLost
        raise ex unless state.get.expiring?
        raise undelivered_cancel(timeout)
      rescue ex : CallerError
        raise ex unless state.get.expiring? && (ex.cause.is_a?(ConnectionLost) || (ex.cause.is_a?(IO::Error) || ex.cause.is_a?(OpenSSL::Error)))
        raise undelivered_cancel(timeout)
      ensure
        finished.close
        unless state.compare_and_set(Deadline::Running, Deadline::Done)[1]
          cancel_sent.receive
          hard_close unless confirmed
        end
      end
    end

    private def undelivered_cancel(timeout : Time::Span) : QueryTimeout
      QueryTimeout.new("statement exceeded #{timeout} and the cancel request could not be delivered")
    end

    private def cancel_or_drop : Nil
      cancel
    rescue ex
      Log.warn { "could not send cancel request (#{ex.class}); dropping the connection" }
      hard_close
    end

    private def queue_sync : Nil
      Wire::Frontend.sync(@out)
      @queued += 1
    end

    private def queue_query(sql : String) : Nil
      Wire::Frontend.query(@out, sql)
      @queued += 1
    end

    # Forgets frames staged for a request that could not be completed.
    private def discard_unsent : Nil
      @out.clear
      @queued = 0
    end

    private def flush : Nil
      @owed += @queued
      @queued = 0
      @io.write(@out.to_slice)
      @io.flush
      @out.clear
    rescue ex : IO::Error | OpenSSL::Error
      hard_close
      raise ConnectionLost.new("lost the connection to the server: #{ex.message}", cause: ex)
    end

    # The next message the caller cares about; asynchronous ones are handled here.
    private def receive : Wire::Backend::Message
      loop do
        case message = Wire::Backend.read(@io)
        when Wire::Backend::NoticeResponse       then notify(message.fields)
        when Wire::Backend::NotificationResponse then deliver(Notification.new(message.process_id, message.channel, message.payload))
        when Wire::Backend::ParameterStatus      then @server_parameters[message.name] = message.value
        else                                          return message
        end
      end
    end

    # Without a handler only severity and SQLSTATE are logged: notice text can
    # quote data.
    private def notify(fields : Hash(Char, String)) : Nil
      return Log.info { "#{fields['S']?} (#{fields['C']?})" } unless handler = @on_notice
      handler.call(fields)
    rescue ex
      Log.error(exception: ex) { "on_notice handler failed" }
    end

    private def deliver(notification : Notification) : Nil
      @on_notification.try(&.call(notification))
    rescue ex
      Log.error(exception: ex) { "on_notification handler failed" }
    end

    # Feeds each message to the block until ReadyForQuery. Errors are held
    # until then so the stream is left in sync, then raised: the server's
    # error, or the block's own exception. After a failure the block is no
    # longer called. A server FATAL followed by the server hanging up raises
    # the FATAL, not a lost connection. *extended* says the request was sent
    # with the extended protocol, which matters if the server unexpectedly asks
    # for COPY data.
    private def until_ready(copy_in : Bool = false, extended : Bool = false, &) : Nil
      failure = nil
      loop do
        message = receive_unless_hung_up(failure)
        case message
        when Wire::Backend::ReadyForQuery
          @transaction_status = message.status
          @owed -= 1
          break
        when Wire::Backend::ErrorResponse
          failure ||= ServerError.from(message.fields)
        when Wire::Backend::CopyResponse
          if message.direction == 'G' && !copy_in
            refuse_copy_in(extended)
          else
            failure ||= run_block { yield message }
          end
        else
          failure ||= run_block { yield message }
        end
      end
      raise failure if failure
    end

    private def run_block(&) : CallerError?
      yield
      nil
    rescue ex
      CallerError.new(cause: ex)
    end

    private def receive_unless_hung_up(failure : Exception?) : Wire::Backend::Message
      receive
    rescue ex : IO::Error | OpenSSL::Error
      raise ex unless failure
      hard_close
      raise failure
    end

    # The server ignores a Sync that arrives while it waits for COPY data, so
    # after an extended-protocol request it needs another one to end the
    # request; after a simple query it must not get one (it would answer twice).
    private def refuse_copy_in(extended : Bool) : Nil
      Wire::Frontend.copy_fail(@out, "COPY FROM STDIN needs Session#copy_in")
      Wire::Frontend.sync(@out) if extended
      flush
    end
  end
end

require "./session/queries"
require "./session/pipelining"
require "./session/copying"
require "./session/streaming"
