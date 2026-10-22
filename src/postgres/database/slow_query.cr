module CQL::Postgres
  module Database
    # Logs queries slower than `Configuration#slow_query_ms` through the configured logger.
    #
    # It is an ordinary `CQL::Events` subscriber installed once when the pool opens, so it
    # coexists with any other consumer of query events.
    module SlowQuery
      @@subscription : ::CQL::Events::Subscription? = nil
      @@mutex = Mutex.new

      def self.install : Nil
        @@mutex.synchronize do
          return if @@subscription
          @@subscription = ::CQL::Events.on_query { |event| check(event) }
        end
      end

      def self.uninstall : Nil
        @@mutex.synchronize do
          if subscription = @@subscription
            ::CQL::Events.unsubscribe(subscription)
            @@subscription = nil
          end
        end
      end

      def self.installed? : Bool
        !@@subscription.nil?
      end

      def self.check(event : ::CQL::Events::QueryEvent) : Nil
        threshold = ::CQL::Postgres.config.slow_query_ms
        return unless threshold > 0 && event.duration_ms >= threshold
        ::CQL::Postgres.config.log.warn { "Slow query (#{event.duration_ms.round(1)}ms): #{event.sql}" }
      end
    end
  end
end
