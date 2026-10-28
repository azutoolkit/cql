require "db"
require "./connection"
require "./connection_reset"
require "./circuit_breaker"

module CQL::Postgres
  # Bounded set of connections shared by many fibers. `checkout` times its wait
  # for a free slot, its health checks and its connect from one
  # `checkout_timeout`; `release` returns the connection, or
  # drops it if it is closed or still inside a transaction. Idle connections
  # that sat unused for `health_check_after`, or have input waiting, are pinged before being handed out.
  class Pool
    include ::DB::ConnectionContext

    # *min_size* connections are opened by `warm_up`; a connection is retired
    # after *max_queries* requests or after sitting idle for *max_idle_lifetime*
    # (checked when it would be lent out); every request counts, pings and
    # resets included. *setup* runs on every new connection, *reset_sql* every
    # time one is returned (followed by *setup* again, since a reset undoes it).
    record Options,
      max_size : Int32 = 10,
      min_size : Int32 = 0,
      checkout_timeout : Time::Span = 5.seconds,
      health_check_after : Time::Span = 30.seconds,
      max_queries : Int64? = nil,
      max_idle_lifetime : Time::Span? = nil,
      reset_sql : String? = nil,
      setup : Proc(Connection, Nil)? = nil,
      connect_failure_threshold : Int32 = 0,
      connect_retry_delay : Time::Span = 1.second do
      def self.from(config : Config) : Options
        driver = config.driver_options
        defaults = new
        new(
          max_size: Config.number(driver["pool_size"]?, "pool_size") || defaults.max_size,
          min_size: Config.number(driver["pool_min_size"]?, "pool_min_size") || defaults.min_size,
          checkout_timeout: Config.seconds(driver["checkout_timeout"]?, "checkout_timeout") || defaults.checkout_timeout,
          health_check_after: Config.seconds(driver["health_check_after"]?, "health_check_after") || defaults.health_check_after,
          max_queries: Config.whole(driver["max_queries"]?, "max_queries"),
          max_idle_lifetime: Config.seconds(driver["max_idle_lifetime"]?, "max_idle_lifetime"),
          reset_sql: reset_statement(driver["pool_reset"]?),
          connect_failure_threshold: Config.number(driver["connect_failure_threshold"]?, "connect_failure_threshold") || defaults.connect_failure_threshold,
          connect_retry_delay: Config.seconds(driver["connect_retry_delay"]?, "connect_retry_delay") || defaults.connect_retry_delay
        )
      end

      # Only DISCARD ALL keeps tenants apart: RESET ALL leaves the role, temp tables, LISTENs, advisory
      # locks and prepared statements (which the reset's cache flush would then leak) to the next borrower.
      private def self.reset_statement(value : String?) : String?
        return unless value
        raise ArgumentError.new("pool_reset must be discard_all, got #{value.inspect}") unless value == "discard_all"
        "DISCARD ALL"
      end
    end

    record Stats, max_size : Int32, idle : Int32, in_use : Int32 do
      def to_s(io : IO) : Nil
        io << in_use << " in use, " << idle << " idle, " << max_size << " max"
      end
    end

    getter config : Config
    getter options : Options

    def initialize(@config : Config, @options : Options = Options.from(config))
      raise ArgumentError.new("pool_size must be at least 1") if @options.max_size < 1
      raise ArgumentError.new("pool_min_size must be between 0 and pool_size") unless 0 <= @options.min_size <= @options.max_size
      raise ArgumentError.new("max_queries must be positive") if @options.max_queries.try { |limit| limit < 1 }
      raise ArgumentError.new("checkout_timeout must be nonnegative") if @options.checkout_timeout < Time::Span.zero
      @circuit = CircuitBreaker.new(@options.connect_failure_threshold, @options.connect_retry_delay)
      @reset = ConnectionReset.new(@options.reset_sql, @options.setup, @options.checkout_timeout)
      @slots = Channel(Nil).new(@options.max_size)
      @options.max_size.times { @slots.send(nil) }
      @idle = [] of Connection
      @in_use = Set(Connection).new
      @lock = CQL::Compat::Mutex.new
      @closed = false
    end

    def closed? : Bool
      @lock.synchronize { @closed }
    end

    def inspect(io : IO) : Nil
      io << "#<" << self.class << ' ' << stats << '>'
    end

    # Startup only, before fibers check out: opens `min_size` connections up front, so the first requests do not pay
    # for connecting and a wrong URL fails at startup. They are not refilled
    # when retired later; the pool then grows on demand.
    def warm_up : self
      raise PoolClosed.new("the pool is closed") if closed?
      opened = [] of Connection
      (@options.min_size - idle_count).times { opened << open }
      @lock.synchronize do
        raise PoolClosed.new("the pool closed during warm_up") if @closed
        @idle.concat(opened)
      end
      self
    rescue ex
      opened.try(&.each(&.close))
      raise ex
    end

    def stats : Stats
      @lock.synchronize { Stats.new(@options.max_size, @idle.size, @in_use.size) }
    end

    def checkout : Connection
      raise PoolClosed.new("the pool is closed") if closed?
      deadline = Time.instant + @options.checkout_timeout if @options.checkout_timeout.positive? # zero: no wait for a slot, no deadline
      wait_for_slot
      begin
        raise PoolClosed.new("the pool was closed while waiting for a connection") if closed?
        connection = healthy_idle(deadline) || open(deadline)
        connection.context = self
        connection.auto_release = false
        admitted = @lock.synchronize do
          next false if @closed
          @in_use << connection
          true
        end
        unless admitted
          connection.close
          raise PoolClosed.new("the pool closed while establishing a connection")
        end
        connection
      rescue ex
        return_slot
        raise ex
      end
    end

    # Checks a connection out for the block and always returns it.
    def with_connection(& : Connection -> T) : T forall T
      connection = checkout
      connection.auto_release = false
      begin
        yield connection
      ensure
        connection.release
      end
    end

    # Returns a checked-out connection. Release each checkout exactly once:
    # a second release after the connection was lent to someone else would
    # return that other lease.
    def release(connection : ::DB::Connection) : Nil
      return connection.close unless connection.is_a?(Connection) && reusable?(connection)
      connection.clear_handlers
      checked_in = @lock.synchronize do
        next false if @closed || !@in_use.delete(connection)
        @idle << connection
        true
      end
      return return_slot if checked_in
      connection.close
    end

    # The connection is gone for good (closed, or dropped by `release`).
    def discard(connection : ::DB::Connection) : Nil
      return unless connection.is_a?(Connection)
      returned_slot = @lock.synchronize { @in_use.delete(connection) }
      return_slot if returned_slot
    end

    def close : Nil
      idle = @lock.synchronize do
        @closed = true
        @idle.dup.tap { @idle.clear }
      end
      @slots.close # wakes fibers waiting for a connection; they raise PoolClosed
      idle.each(&.close)
    end

    private def wait_for_slot : Nil
      select
      when @slots.receive
      when timeout(@options.checkout_timeout)
        raise PoolTimeout.new("no connection to #{@config.address} became free within #{@options.checkout_timeout} (pool size #{@options.max_size})")
      end
    rescue Channel::ClosedError
      raise PoolClosed.new("the pool was closed while waiting for a connection")
    end

    # Hands a slot back; once the pool is closed there is nobody to give it to.
    private def return_slot : Nil
      @slots.send(nil)
    rescue Channel::ClosedError
    end

    private def open(deadline : Time::Instant? = nil) : Connection
      deadline ||= Time.instant + @options.checkout_timeout if @options.checkout_timeout.positive?
      ticket = @circuit.acquire
      begin
        connection = Connection.open(@config, deadline: deadline)
        if hook = @options.setup
          ConnectionSetup.run(connection, deadline) { hook.call(connection) }
        end
        @circuit.succeeded(ticket)
        connection
      rescue ex
        connection.try(&.close)
        @circuit.failed(ticket)
        raise ex
      end
    end

    private def idle_count : Int32
      @lock.synchronize { @idle.size }
    end

    # Health checks share the half of the time left that a `CQL::CheckoutBudget` gives them: a connection that
    # finds it spent is discarded unpinged.
    private def healthy_idle(deadline : Time::Instant?) : Connection?
      checks = CQL::CheckoutBudget.new(deadline)
      while connection = @lock.synchronize { @idle.pop? }
        verdict = quick_verdict(connection)
        if verdict.nil?
          wait = checks.check_wait(CQL::Postgres::Session::PING_TIMEOUT)
          verdict = wait ? connection.ping(wait) : false
        end
        return connection if verdict
        connection.close
      end
    end

    # true or false when the connection's age settles it, nil when it needs a ping: it is old, or the server
    # wrote to it or hung up while it sat idle (a backend's FATAL on a restart or failover is read by the ping).
    private def quick_verdict(connection : Connection) : Bool?
      return false if connection.closed? || connection.session.closed?
      idle_for = Time.instant - connection.session.last_used
      return false if @options.max_idle_lifetime.try { |lifetime| idle_for >= lifetime }
      idle_for < @options.health_check_after && !connection.session.input_pending? ? true : nil
    end

    private def reusable?(connection : Connection) : Bool
      return false if connection.closed? || connection.session.closed? || worn_out?(connection)
      @reset.call(connection)
    end

    private def worn_out?(connection : Connection) : Bool
      @options.max_queries.try { |limit| connection.session.requests >= limit } || false
    end
  end
end
