module CQL::Telemetry
  # Runs the handler on its own fiber, so `push` never waits. Call `close` when finished, or that fiber lives forever.
  class EventQueue(T)
    # Flushes that may be pending at once, timed-out ones included until the consumer reaches them.
    MAX_PENDING_FLUSHES = 8

    private MAX_CAPACITY = Int32::MAX - MAX_PENDING_FLUSHES
    private record Flush, done = Channel(Bool).new(1)

    # Free buffer slots of one kind. Every send first takes a slot, so the channel never fills up
    # and a plain `send` never parks, which keeps `push` free of an allocating `select`.
    private class Slots
      def initialize(count : Int32)
        @free = Atomic(Int32).new(count)
      end

      # Under contention the count can dip below zero for a moment: a spurious refusal, never more than the bound.
      def take? : Bool
        return false if @free.get(:relaxed) <= 0
        return true if @free.sub(1) > 0
        release
        false
      end

      def release : Nil
        @free.add(1)
      end
    end

    # *capacity* itself when a queue can hold that many events; raises ArgumentError otherwise.
    def self.checked_capacity(capacity : Int32) : Int32
      raise ArgumentError.new("capacity must be in 1..#{MAX_CAPACITY}, got #{capacity}") unless capacity.in?(1..MAX_CAPACITY)
      capacity
    end

    @dropped = Atomic(Int64).new(0)
    @consumer : Fiber

    def initialize(capacity : Int32, &@handler : T ->)
      capacity = self.class.checked_capacity(capacity)
      @event_slots = Slots.new(capacity)
      @flush_slots = Slots.new(MAX_PENDING_FLUSHES)
      @channel = Channel(T | Flush).new(capacity + MAX_PENDING_FLUSHES)
      @consumer = spawn(name: "cql.telemetry.event_queue") { drain }
    end

    # Enqueues *event* without waiting or allocating; false when closed or full (counted in `dropped`).
    def push(event : T) : Bool
      push { event }
    end

    # Like `push(event)`, but builds the event only once a slot is free, so a dropped event costs nothing.
    # A block that raises, breaks or returns gives its slot back.
    def push(& : -> T) : Bool
      return false if @channel.closed?
      unless @event_slots.take?
        @dropped.add(1)
        return false
      end
      built = false # ameba:disable Lint/UselessAssign (read by the ensure when the block raises, breaks or returns)
      begin
        event = yield
        built = true
      ensure
        @event_slots.release unless built
      end
      enqueue(event, @event_slots)
    end

    def dropped : Int64
      @dropped.get
    end

    # True once every event pushed before it was handled; false on timeout, on close, on the consumer fiber
    # or past `MAX_PENDING_FLUSHES`. Without a *timeout* it waits on the handler, even one waiting for the
    # flusher: keep it off hot paths.
    def flush(timeout : Time::Span? = nil) : Bool
      return false if @channel.closed? || Fiber.current.same?(@consumer) || !@flush_slots.take?
      marker = Flush.new
      return false unless enqueue(marker, @flush_slots)
      select
      when reached = marker.done.receive then reached
      when timeout(timeout || Int32::MAX.seconds) then false
      end
    end

    # Stops accepting events, then drains the buffer without waiting: events are skipped, flushes return false.
    def close : Nil
      @channel.close
      drain
    end

    # Sends *message*, whose slot is taken; the slot goes back if the queue closed meanwhile.
    private def enqueue(message : T | Flush, slots : Slots) : Bool
      @channel.send(message)
      true
    rescue Channel::ClosedError
      slots.release
      false
    end

    private def drain : Nil
      loop { handle(@channel.receive) }
    rescue Channel::ClosedError
    end

    private def handle(marker : Flush) : Nil
      @flush_slots.release
      marker.done.send(!@channel.closed?)
    end

    private def handle(event : T) : Nil
      @event_slots.release
      @handler.call(event) unless @channel.closed?
    rescue ex
      Log.error(exception: ex) { "telemetry event handler failed" }
    end
  end
end
