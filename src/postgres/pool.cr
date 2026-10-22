require "db"
require "./connection"

module CQL::Postgres
  # Bounded set of connections shared by many fibers. `checkout` waits (up to
  # `checkout_timeout`) for a free slot; `release` returns the connection, or
  # drops it if it is closed or still inside a transaction. Idle connections
  # that sat unused for `health_check_after` are pinged before being handed out.
  class Pool
    include ::DB::ConnectionContext

    record Options, max_size : Int32 = 10, checkout_timeout : Time::Span = 5.seconds, health_check_after : Time::Span = 30.seconds do
      def self.from(config : Config) : Options
        driver = config.driver_options
        defaults = new
        new(
          max_size: driver["pool_size"]?.try(&.to_i?) || defaults.max_size,
          checkout_timeout: driver["checkout_timeout"]?.try(&.to_f?).try(&.seconds) || defaults.checkout_timeout,
          health_check_after: driver["health_check_after"]?.try(&.to_f?).try(&.seconds) || defaults.health_check_after
        )
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
      @slots = Channel(Nil).new(@options.max_size)
      @options.max_size.times { @slots.send(nil) }
      @idle = [] of Connection
      @in_use = Set(Connection).new
      @lock = CQL::Compat::Mutex.new
      @closed = false
    end

    def closed? : Bool
      @closed
    end

    def stats : Stats
      @lock.synchronize { Stats.new(@options.max_size, @idle.size, @in_use.size) }
    end

    def checkout : Connection
      raise PoolClosed.new("the pool is closed") if @closed
      wait_for_slot
      begin
        raise PoolClosed.new("the pool was closed while waiting for a connection") if @closed
        connection = healthy_idle || open
        connection.context = self
        connection.auto_release = false
        @lock.synchronize { @in_use << connection }
        connection
      rescue ex
        @slots.send(nil)
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
      return @slots.send(nil) if checked_in
      connection.close
    end

    # The connection is gone for good (closed, or dropped by `release`).
    def discard(connection : ::DB::Connection) : Nil
      return unless connection.is_a?(Connection)
      returned_slot = @lock.synchronize { @in_use.delete(connection) }
      @slots.send(nil) if returned_slot
    end

    def close : Nil
      idle = @lock.synchronize do
        @closed = true
        @idle.dup.tap { @idle.clear }
      end
      idle.each(&.close)
    end

    private def wait_for_slot : Nil
      select
      when @slots.receive
      when timeout(@options.checkout_timeout)
        raise PoolTimeout.new("no connection became free within #{@options.checkout_timeout} (pool size #{@options.max_size})")
      end
    end

    private def open : Connection
      Connection.open(@config)
    end

    private def healthy_idle : Connection?
      while connection = @lock.synchronize { @idle.pop? }
        return connection if healthy?(connection)
        connection.close
      end
    end

    private def healthy?(connection : Connection) : Bool
      return false if connection.closed? || connection.session.closed?
      idle_for = Time.instant - connection.session.last_used
      idle_for < @options.health_check_after || connection.ping
    end

    private def reusable?(connection : Connection) : Bool
      !connection.closed? && !connection.session.closed? && !connection.in_transaction?
    end
  end
end
