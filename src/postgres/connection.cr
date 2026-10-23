require "db"
require "./session"
require "./statement"

module CQL::Postgres
  # A crystal-db connection over a wire `Session`: what `Executor#exec_query`
  # yields, so every CQL statement type runs on it unchanged.
  class Connection < ::DB::Connection
    DRIVER_NAME = "postgres"

    getter session : CQL::Postgres::Session

    # crystal-db's own per-connection statement-wrapper cache is off: the
    # session already keeps a bounded cache of prepared statements.
    def self.open(config : Config, options : ::DB::Connection::Options = ::DB::Connection::Options.new(prepared_statements_cache: false)) : Connection
      new(CQL::Postgres::Session.connect(config), options)
    end

    def initialize(@session : CQL::Postgres::Session, options : ::DB::Connection::Options = ::DB::Connection::Options.new(prepared_statements_cache: false))
      super(options)
    end

    # A connection whose session was dropped (after a network error, a protocol
    # error or a timeout) is closed for good, even if nobody called `close`.
    def closed? : Bool
      super || @session.closed?
    end

    # crystal-db 0.15 requires it: the name the driver is registered with.
    def driver_name : String
      DRIVER_NAME
    end

    def build_prepared_statement(query) : ::DB::Statement
      Statement.new(self, query, prepared: true)
    end

    def build_unprepared_statement(query) : ::DB::Statement
      Statement.new(self, query, prepared: false)
    end

    # Runs a script of several statements; no rows come back.
    def exec_all(sql : String) : Nil
      translating_lost { @session.simple_query(sql) }
    end

    def inspect(io : IO) : Nil
      io << "#<" << self.class << ' '
      @session.inspect(io)
      io << '>'
    end

    def ping(timeout : Time::Span = CQL::Postgres::Session::PING_TIMEOUT) : Bool
      @session.ping(timeout)
    end

    # Per-borrower state (notice and notification handlers) does not outlive a checkout.
    def clear_handlers : Nil
      @session.on_notice = nil
      @session.on_notification = nil
    end

    def cancel : Nil
      @session.cancel
    end

    def in_transaction? : Bool
      @session.in_transaction?
    end

    def on_notice(&handler : Hash(Char, String) ->) : Nil
      @session.on_notice = handler
    end

    def on_notification(&handler : Notification ->) : Nil
      @session.on_notification = handler
    end

    def copy_in(sql : String, & : CopyIn ->) : Int64
      translating_lost { @session.copy_in(sql) { |copy| yield copy } }
    end

    def copy_out(sql : String, & : Bytes ->) : Int64
      translating_lost { @session.copy_out(sql) { |chunk| yield chunk } }
    end

    # Runs a query and yields a result set that reads rows from the server
    # *fetch_size* at a time, so a large result is never held whole. The
    # connection is busy until the block returns; stopping early is fine. See
    # `Session#stream` for the details, including the timeout.
    #
    # ```
    # connection.stream("SELECT id, name FROM users WHERE age > $1", 18, fetch_size: 500) do |rows|
    #   rows.each { puts rows.read(Int64) }
    # end
    # ```
    def stream(sql : String, *args, fetch_size : Int32 = 1000, timeout : Time::Span? = nil, & : ::DB::ResultSet -> T) : T forall T
      stream(sql, args.to_a, fetch_size, timeout) { |rows| yield rows }
    end

    def stream(sql : String, args : Enumerable, fetch_size : Int32 = 1000, timeout : Time::Span? = nil, & : ::DB::ResultSet -> T) : T forall T
      params = args.map { |arg| Types::ParamEncoder.encode(arg) }.to_a
      translating_lost do
        @session.stream(sql, params, fetch_size, timeout: timeout) do |rows|
          yield ResultSet.new(Statement.new(self, sql, prepared: true), rows)
        end
      end
    end

    # Several statements, one network round trip. See `Session#pipeline`.
    def pipeline(statements : Array({String, Array(Types::Param)})) : Array(Result | ServerError)
      translating_lost { @session.pipeline(statements) }
    end

    private def translating_lost(&)
      yield
    rescue ex : ConnectionLost
      raise ::DB::ConnectionLost.new(self, cause: ex)
    end

    protected def do_close
      super
      @session.close
    end
  end
end
