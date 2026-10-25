require "./compat"
require "./telemetry/event_queue"

module CQL
  # Observability for every statement CQL runs: subscribers receive a `QueryEvent`
  # after each one (successful or not), and an optional `Tracer` wraps the
  # statement in a span (OpenTelemetry, Dashforge, ...).
  #
  # ```
  # CQL::Telemetry.subscribe("metrics") { |event| StatsD.timing("sql.#{event.operation}", event.duration) }
  # CQL::Telemetry.alert_on_slow(200.milliseconds) { |event| Alerts.warn("slow query: #{event.sql}") }
  # ```
  #
  # `subscribe_transactions` additionally reports `Schema#transaction`
  # begin/commit/rollback, and `Schema#pool_stats` exposes the connection pool.
  #
  # Parameter values are not included in events unless `capture_params` is on,
  # since they often contain personal data. A subscriber that raises is logged
  # and never affects the query.
  module Telemetry
    Log = ::Log.for(self)

    # What happened when one statement ran.
    struct QueryEvent
      getter sql : String
      getter param_count : Int32
      # The bound values, only when `Telemetry.capture_params` is on.
      getter params : Array(DB::Any)?
      getter duration : Time::Span
      getter error : Exception?
      getter adapter : Adapter
      # :select, :insert, :update, :delete, :ddl or :explain
      getter operation : Symbol
      getter rows_affected : Int64?
      getter context : String?
      # Time spent waiting for a pooled connection; about zero on a pinned or
      # transaction connection. Included in `duration`; measured by
      # `CQL::Execution.run` (zero in events built by `Telemetry.observe`).
      getter pool_wait : Time::Span

      def initialize(@sql, @param_count, @params, @duration, @error, @adapter, @operation, @rows_affected, @context,
                     @pool_wait = Time::Span.zero)
      end

      def success? : Bool
        error.nil?
      end
    end

    enum TransactionState
      Begin
      Commit
      Rollback
    end

    # A transaction opened by `Schema#transaction` changed state. `Begin` is
    # published before the connection is checked out, so `Commit`/`Rollback`
    # durations include pool wait time.
    struct TransactionEvent
      getter state : TransactionState
      # Shared by the Begin and the Commit/Rollback event of one transaction.
      getter id : Int64
      # Time since Begin; zero for Begin.
      getter duration : Time::Span
      # Informational: a transaction was already open on this fiber.
      getter nested : Bool
      # What ended the transaction in a Rollback (including `DB::Rollback`),
      # or what made the commit fail.
      getter error : Exception?
      getter adapter : Adapter

      def initialize(@state, @id, @duration, @nested, @error, @adapter)
      end
    end

    # Reports one transaction's lifecycle to the subscribers. Created by
    # `Telemetry.begin_transaction`, which has already published Begin.
    class TransactionObserver
      @started : Time::Instant = Time.instant
      @error : Exception? = nil

      getter id : Int64

      def initialize(@adapter : Adapter, @id : Int64, @nested : Bool)
      end

      # Remembers the first failure; later calls (e.g. the same exception seen again) are ignored.
      def failed(error : Exception) : Nil
        @error ||= error
      end

      def finish : Nil
        state = @error ? TransactionState::Rollback : TransactionState::Commit
        Telemetry.emit_transaction(TransactionEvent.new(state, @id, Time.instant - @started, @nested, @error, @adapter))
      end
    end

    # Runs a statement inside a span of some tracing system.
    abstract class Tracer
      # Must call the block exactly once and let its exceptions propagate.
      # The statement runs when the block is called; the return value is ignored.
      abstract def in_span(operation : Symbol, sql : String, &)
    end

    alias Subscriber = QueryEvent ->
    alias TransactionSubscriber = TransactionEvent ->

    private DEFAULT_ASYNC_QUEUE_CAPACITY = 4096

    @@subscribers = {} of String => Subscriber
    @@async_subscribers = {} of String => Subscriber
    @@async_queue : EventQueue(QueryEvent)? = nil
    @@transaction_subscribers = {} of String => TransactionSubscriber
    @@transaction_ids = Atomic(Int64).new(0)
    @@mutex = CQL::Compat::Mutex.new
    @@async_queue_capacity : Int32 = DEFAULT_ASYNC_QUEUE_CAPACITY
    @@capture_params = false
    @@tracer : Tracer? = nil

    def self.capture_params : Bool
      @@capture_params
    end

    def self.capture_params=(value : Bool)
      @@capture_params = value
    end

    def self.tracer : Tracer?
      @@tracer
    end

    def self.tracer=(value : Tracer?)
      @@tracer = value
    end

    # Events the async queue holds before it drops new ones. Set it before the first async subscriber: the queue
    # is built then and kept until `reset!`, which also restores the default.
    def self.async_queue_capacity : Int32
      @@async_queue_capacity
    end

    def self.async_queue_capacity=(value : Int32)
      @@async_queue_capacity = EventQueue(QueryEvent).checked_capacity(value)
    end

    # Registers (or replaces) the subscriber called *name*, by default called inline after each statement.
    #
    # An *async* subscriber runs on one background fiber after the statement returns, fed by a bounded
    # queue that drops events when full (`dropped_events`). On a single Crystal thread this moves its work
    # out of the query's latency, not out of the CPU; under multi-threading a push to a parked consumer
    # can cost a scheduler wake.
    def self.subscribe(name : String, *, async : Bool = false, &block : QueryEvent ->) : Nil
      @@mutex.synchronize do
        if async
          @@async_queue ||= EventQueue(QueryEvent).new(@@async_queue_capacity) { |event| notify(@@async_subscribers, event) }
          @@async_subscribers = @@async_subscribers.merge({name => block})
          @@subscribers = @@subscribers.reject(name)
        else
          @@subscribers = @@subscribers.merge({name => block})
          @@async_subscribers = @@async_subscribers.reject(name)
        end
      end
    end

    def self.unsubscribe(name : String) : Nil
      @@mutex.synchronize do
        @@subscribers = @@subscribers.reject(name)
        @@async_subscribers = @@async_subscribers.reject(name)
      end
    end

    # Waits until async subscribers have handled every event published before it; false on timeout, true without a queue.
    def self.flush(timeout : Time::Span? = nil) : Bool
      queue = @@async_queue
      queue.nil? || queue.flush(timeout)
    end

    # Events the async queue dropped because it was full.
    def self.dropped_events : Int64
      @@async_queue.try(&.dropped) || 0_i64
    end

    # Registers (or replaces) the transaction subscriber called *name*.
    def self.subscribe_transactions(name : String, &block : TransactionEvent ->) : Nil
      @@mutex.synchronize { @@transaction_subscribers = @@transaction_subscribers.merge({name => block}) }
    end

    def self.unsubscribe_transactions(name : String) : Nil
      @@mutex.synchronize { @@transaction_subscribers = @@transaction_subscribers.reject(name) }
    end

    # Whether a query or transaction subscriber is registered under *name*.
    def self.subscribed?(name : String) : Bool
      @@subscribers.has_key?(name) || @@async_subscribers.has_key?(name) || @@transaction_subscribers.has_key?(name)
    end

    # Process-wide, strictly increasing transaction id.
    def self.next_transaction_id : Int64
      @@transaction_ids.add(1) + 1
    end

    # Publishes Begin and returns the observer that publishes the end of the
    # transaction, or nil (without allocating or reading the clock) when nobody subscribed.
    def self.begin_transaction(adapter : Adapter, nested : Bool) : TransactionObserver?
      return if @@transaction_subscribers.empty?

      id = next_transaction_id
      emit_transaction(TransactionEvent.new(TransactionState::Begin, id, Time::Span.zero, nested, nil, adapter))
      TransactionObserver.new(adapter, id, nested)
    end

    # :nodoc:
    def self.emit_transaction(event : TransactionEvent) : Nil
      notify(@@transaction_subscribers, event)
    end

    # Calls the block for statements that took at least *threshold*.
    def self.alert_on_slow(threshold : Time::Span, name : String = "cql.slow_query", &block : QueryEvent ->) : Nil
      subscribe(name) { |event| block.call(event) if event.duration >= threshold }
    end

    # Logs one line per statement.
    def self.log_queries(severity : ::Log::Severity = ::Log::Severity::Debug, name : String = "cql.log") : Nil
      logger = ::Log.for("cql.telemetry")
      subscribe(name) do |event|
        failure = " FAILED: #{event.error.class}" if event.error
        message = "[#{event.operation}] #{event.duration.total_milliseconds.round(2)}ms #{event.sql} (#{event.param_count} params)#{failure}"
        case severity
        when .trace?, .debug? then logger.debug { message }
        when .info?, .notice? then logger.info { message }
        when .warn?           then logger.warn { message }
        else                       logger.error { message }
        end
      end
    end

    # Tags events emitted by the current fiber while the block runs.
    def self.with_context(context : String, &)
      previous = current_context
      Fiber.current.cql_telemetry_context = context
      yield
    ensure
      Fiber.current.cql_telemetry_context = previous
    end

    # The context set by `with_context` on the current fiber, if any.
    def self.current_context : String?
      Fiber.current.cql_telemetry_context
    end

    def self.reset! : Nil
      @@mutex.synchronize do
        @@subscribers = {} of String => Subscriber
        @@async_subscribers = {} of String => Subscriber
        @@transaction_subscribers = {} of String => TransactionSubscriber
        @@async_queue.try &.close
        @@async_queue = nil
        @@async_queue_capacity = DEFAULT_ASYNC_QUEUE_CAPACITY
      end
      @@capture_params = false
      @@tracer = nil
    end

    # Runs the block as one observed statement: inside the tracer's span, then
    # reports the event to the subscribers.
    def self.observe(adapter : Adapter, operation : Symbol, sql : String, params : Array(DB::Any), & : -> T) : T forall T
      return in_span(operation, sql) { yield } unless observing?

      started = Time.instant
      begin
        result = in_span(operation, sql) { yield }
      rescue ex
        publish(query_event(adapter, operation, sql, params, Time.instant - started, ex, nil))
        raise ex
      end
      publish(query_event(adapter, operation, sql, params, Time.instant - started, nil, result))
      result
    end

    # :nodoc:
    def self.observing? : Bool
      !@@subscribers.empty? || !@@async_subscribers.empty?
    end

    # :nodoc:
    def self.in_span(operation : Symbol, sql : String, & : -> T) : T forall T
      if tracer = @@tracer
        result = uninitialized T
        completed = false
        failure = nil
        tracer.in_span(operation, sql) do
          result = yield
          completed = true
        rescue ex
          failure = ex
          raise ex
        end
        raise failure if failure
        raise "#{tracer.class} did not run the statement inside in_span" unless completed
        result
      else
        yield
      end
    end

    private def self.rows_affected(result) : Int64?
      result.is_a?(DB::ExecResult) ? result.rows_affected : nil
    end

    # :nodoc:
    def self.query_event(adapter : Adapter, operation : Symbol, sql : String, params : Array(DB::Any),
                         duration : Time::Span, error : Exception?, result, pool_wait : Time::Span = Time::Span.zero) : QueryEvent
      QueryEvent.new(sql, params.size, (params.map(&.dup) if @@capture_params), duration, error, adapter, operation, rows_affected(result), current_context, pool_wait)
    end

    # :nodoc:
    def self.publish(event : QueryEvent) : Nil
      notify(@@subscribers, event)
      queue = @@async_queue
      queue.push(event) if queue && !@@async_subscribers.empty?
    end

    private def self.notify(subscribers, event) : Nil
      subscribers.each do |name, subscriber|
        subscriber.call(event)
      rescue ex
        Log.error(exception: ex) { "telemetry subscriber #{name} failed" }
      end
    end
  end
end

class ::Fiber
  # :nodoc:
  property cql_telemetry_context : String?
end
