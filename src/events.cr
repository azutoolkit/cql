module CQL
  # Lightweight, synchronous pub/sub used to observe what CQL does without
  # coupling it to any consumer (dev dashboards, tracers, loggers...).
  #
  # Handlers run in the fiber that triggered the event, so fiber-local context
  # (e.g. the current HTTP request) is available to subscribers.
  #
  # ```
  # sub = CQL::Events.on_query { |e| puts "#{e.duration_ms}ms #{e.sql}" }
  # # ...
  # CQL::Events.unsubscribe(sub)
  # ```
  module Events
    QUERY       = "cql.query"
    TRANSACTION = "cql.transaction"
    CONNECT     = "cql.connect"

    abstract struct Event
    end

    # A SQL statement was executed.
    struct QueryEvent < Event
      getter sql : String
      getter params : Array(DB::Any)
      getter duration_ms : Float64
      getter rows : Int64?
      getter error : String?

      def initialize(@sql, @params, @duration_ms, @rows = nil, @error = nil)
      end

      def error? : Bool
        !@error.nil?
      end
    end

    enum TransactionState
      Begin
      Commit
      Rollback
    end

    # A transaction changed state. `id` is stable for one transaction.
    struct TransactionEvent < Event
      getter state : TransactionState
      getter id : Int64
      getter duration_ms : Float64
      getter nested : Bool
      getter error : String?

      def initialize(@state, @id, @duration_ms = 0.0, @nested = false, @error = nil)
      end
    end

    # A schema opened its database connection pool.
    struct ConnectEvent < Event
      getter schema : Symbol
      getter adapter : String
      getter uri : String

      def initialize(@schema, @adapter, @uri)
      end
    end

    alias Handler = Proc(Event, Nil)

    class Subscription
      getter name : String
      getter handler : Handler

      def initialize(@name, @handler)
      end
    end

    @@mutex = Mutex.new
    # Copy-on-write: the hash and its arrays are never mutated after publishing,
    # so readers (the hot path) need no lock.
    @@subscribers = {} of String => Array(Subscription)
    @@tx_ids = Atomic(Int64).new(0_i64)

    def self.subscribe(name : String, &handler : Event ->) : Subscription
      sub = Subscription.new(name, handler)
      @@mutex.synchronize do
        updated = @@subscribers.dup
        updated[name] = (updated[name]? || [] of Subscription) + [sub]
        @@subscribers = updated
      end
      sub
    end

    def self.on_query(&block : QueryEvent ->) : Subscription
      subscribe(QUERY) { |event| block.call(event.as(QueryEvent)) }
    end

    def self.on_transaction(&block : TransactionEvent ->) : Subscription
      subscribe(TRANSACTION) { |event| block.call(event.as(TransactionEvent)) }
    end

    def self.on_connect(&block : ConnectEvent ->) : Subscription
      subscribe(CONNECT) { |event| block.call(event.as(ConnectEvent)) }
    end

    def self.unsubscribe(subscription : Subscription) : Nil
      @@mutex.synchronize do
        list = @@subscribers[subscription.name]?
        return unless list
        updated = @@subscribers.dup
        updated[subscription.name] = list.reject { |s| s.same?(subscription) }
        @@subscribers = updated
      end
    end

    # Removes every subscriber (mostly useful in specs).
    def self.clear : Nil
      @@mutex.synchronize { @@subscribers = {} of String => Array(Subscription) }
    end

    # Cheap check callers use to skip building payloads when nobody listens.
    def self.subscribed?(name : String) : Bool
      list = @@subscribers[name]?
      !list.nil? && !list.empty?
    end

    # Delivers `event` to every subscriber of `name`. A failing handler never
    # breaks the query that triggered it.
    def self.emit(name : String, event : Event) : Nil
      list = @@subscribers[name]?
      return if list.nil? || list.empty?
      list.each do |sub|
        sub.handler.call(event)
      rescue ex
        ::Log.for("cql.events").error(exception: ex) { "Subscriber for #{name} raised" }
      end
    end

    def self.next_transaction_id : Int64
      @@tx_ids.add(1_i64) + 1_i64
    end
  end
end
