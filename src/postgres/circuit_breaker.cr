require "../compat"
require "./errors"

module CQL::Postgres
  # Limits new connection attempts during an outage. Existing healthy leases keep
  # working. A generation prevents late results from an older attempt changing
  # an open circuit; only one recovery probe is admitted after the cooldown.
  # Disabled by default. No statements are retried by this mechanism.
  class CircuitBreaker
    @failures = 0
    @generation = 0_u64
    @retry_at : Time::Instant? = nil
    @probing = false
    @lock = CQL::Compat::Mutex.new

    def initialize(@threshold : Int32, @cooldown : Time::Span)
      raise ArgumentError.new("connect_failure_threshold must be nonnegative (0 disables the circuit breaker)") if @threshold < 0
      raise ArgumentError.new("connect_retry_delay must be positive") unless @cooldown.positive?
    end

    def acquire(now : Time::Instant = Time.instant) : UInt64
      return 0_u64 if @threshold == 0
      @lock.synchronize do
        if retry_at = @retry_at
          if @probing || now < retry_at
            raise CircuitOpen.new("new connection attempts are paused after consecutive failures; retry after connect_retry_delay")
          end
          @probing = true
        end
        @generation
      end
    end

    def succeeded(ticket : UInt64) : Nil
      return if @threshold == 0
      @lock.synchronize do
        return unless ticket == @generation
        @failures = 0
        if @probing
          @retry_at = nil
          @probing = false
          @generation &+= 1
        end
      end
    end

    def failed(ticket : UInt64, now : Time::Instant = Time.instant) : Nil
      return if @threshold == 0
      @lock.synchronize do
        return unless ticket == @generation
        @failures += 1
        if @probing || @failures >= @threshold
          @retry_at = now + @cooldown
          @probing = false
          @generation &+= 1
        end
      end
    end
  end
end
