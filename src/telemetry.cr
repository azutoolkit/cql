require "./compat"

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

      def initialize(@sql, @param_count, @params, @duration, @error, @adapter, @operation, @rows_affected, @context)
      end

      def success? : Bool
        error.nil?
      end
    end

    # Runs a statement inside a span of some tracing system.
    abstract class Tracer
      # Must call the block exactly once and let its exceptions propagate.
      # The statement runs when the block is called; the return value is ignored.
      abstract def in_span(operation : Symbol, sql : String, &)
    end

    alias Subscriber = QueryEvent ->

    @@subscribers = {} of String => Subscriber
    @@contexts = {} of Fiber => String
    @@mutex = CQL::Compat::Mutex.new
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

    # Registers (or replaces) the subscriber called *name*.
    def self.subscribe(name : String, &block : QueryEvent ->) : Nil
      @@mutex.synchronize { @@subscribers = @@subscribers.merge({name => block}) }
    end

    def self.unsubscribe(name : String) : Nil
      @@mutex.synchronize { @@subscribers = @@subscribers.reject(name) }
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
      previous = @@mutex.synchronize { @@contexts.put(Fiber.current, context) { nil } }
      yield
    ensure
      @@mutex.synchronize do
        previous ? (@@contexts[Fiber.current] = previous) : @@contexts.delete(Fiber.current)
      end
    end

    def self.reset! : Nil
      @@mutex.synchronize do
        @@subscribers = {} of String => Subscriber
        @@contexts.clear
      end
      @@capture_params = false
      @@tracer = nil
    end

    # Runs the block as one observed statement: inside the tracer's span, then
    # reports the event to the subscribers.
    def self.observe(adapter : Adapter, operation : Symbol, sql : String, params : Array(DB::Any), & : -> T) : T forall T
      return in_span(operation, sql) { yield } if @@subscribers.empty?

      started = Time.instant
      begin
        result = in_span(operation, sql) { yield }
      rescue ex
        emit(adapter, operation, sql, params, Time.instant - started, ex, nil)
        raise ex
      end
      emit(adapter, operation, sql, params, Time.instant - started, nil, rows_affected(result))
      result
    end

    private def self.in_span(operation : Symbol, sql : String, & : -> T) : T forall T
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

    private def self.emit(adapter, operation, sql, params, duration, error, rows) : Nil
      context = @@mutex.synchronize { @@contexts[Fiber.current]? }
      event = QueryEvent.new(sql, params.size, (params.dup if @@capture_params), duration, error, adapter, operation, rows, context)
      @@subscribers.each do |name, subscriber|
        subscriber.call(event)
      rescue ex
        Log.error(exception: ex) { "telemetry subscriber #{name} failed" }
      end
    end
  end
end
