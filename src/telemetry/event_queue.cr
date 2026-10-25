module CQL::Telemetry
  # Runs the handler on its own fiber, so `push` never waits. Call `close` when finished, or that fiber lives forever.
  class EventQueue(T)
    private record Flush, done = Channel(Bool).new(1)
    @dropped = Atomic(Int64).new(0)
    @consumer : Fiber

    def initialize(capacity : Int32, &@handler : T ->)
      @channel = Channel(T | Flush).new(capacity)
      @consumer = spawn(name: "cql.telemetry.event_queue") { drain }
    end

    # Enqueues *event* without waiting; false when closed or full (counted in `dropped`).
    def push(event : T) : Bool
      return false if @channel.closed?
      select
      when @channel.send(event) then true
      else
        @dropped.add(1)
        false
      end
    rescue Channel::ClosedError
      false
    end

    def dropped : Int64
      @dropped.get
    end

    # True once every event pushed before it was handled; false on timeout, on close or on the consumer fiber.
    # Without a *timeout* it can block on a full queue or on a handler waiting for the flusher: keep it off hot paths.
    def flush(timeout : Time::Span? = nil) : Bool
      return false if @channel.closed? || Fiber.current.same?(@consumer)
      deadline, marker = Time.instant + (timeout || Int32::MAX.seconds), Flush.new
      select
      when @channel.send(marker)
      when timeout(deadline - Time.instant) then return false
      end
      select
      when reached = marker.done.receive then reached
      when timeout(deadline - Time.instant) then false
      end
    rescue Channel::ClosedError
      false
    end

    # Stops accepting events, then drains the buffer without waiting: events are skipped, flushes return false.
    def close : Nil
      @channel.close
      drain
    end

    private def drain : Nil
      loop do
        message = @channel.receive
        message.is_a?(Flush) ? message.done.send(!@channel.closed?) : handle(message)
      end
    rescue Channel::ClosedError
    end

    private def handle(event : T) : Nil
      @handler.call(event) unless @channel.closed?
    rescue ex
      Log.error(exception: ex) { "telemetry event handler failed" }
    end
  end
end
