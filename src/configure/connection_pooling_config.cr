module CQL::Configure
  # Connection pool configuration
  class ConnectionPoolConfig
    property size : Int32 = 10
    property initial_size : Int32 = 1
    property max_idle_size : Int32 = 1
    property checkout_timeout : Time::Span = 10.seconds
    # The native PostgreSQL driver's default statement deadline (its `query_timeout` URL key); nil means none.
    property query_timeout : Time::Span? = nil
    property max_retry_attempts : Int32 = 3
    property retry_delay : Time::Span = 1.second
    property? use_prepared_statements : Bool = true

    # Adds the pool keys to the URL; `query_timeout` only for PostgreSQL and CockroachDB, whose driver reads it.
    def apply_to_params(params : HTTP::Params, adapter : Adapter = Adapter::Postgres) : Nil
      params.add("initial_pool_size", initial_size.to_s)
      params.add("max_pool_size", size.to_s)
      params.add("max_idle_pool_size", max_idle_size.to_s)
      params.add("checkout_timeout", checkout_timeout.total_seconds.to_s)
      query_timeout.try { |timeout| params.add("query_timeout", timeout.total_seconds.to_s) } if adapter.postgres_compatible?
      params.add("retry_attempts", max_retry_attempts.to_s)
      params.add("retry_delay", retry_delay.total_seconds.to_s)
      params.add("prepared_statements", use_prepared_statements?.to_s)
    end

    # Raises `ArgumentError` for an invalid setting, or a `query_timeout` that *adapter*'s driver would not honour.
    def validate!(adapter : Adapter = Adapter::Postgres) : Nil
      raise ArgumentError.new("pool_size must be positive") if size <= 0
      raise ArgumentError.new("initial_pool_size must be positive") if initial_size <= 0
      raise ArgumentError.new("max_idle_pool_size must be positive") if max_idle_size <= 0
      raise ArgumentError.new("max_retry_attempts must be positive") if max_retry_attempts <= 0
      raise ArgumentError.new("query_timeout must be positive") if query_timeout.try { |timeout| !timeout.positive? }
      raise ArgumentError.new("query_timeout needs PostgreSQL or CockroachDB (only CQL's native PostgreSQL driver reads it), not #{adapter}") if query_timeout && !adapter.postgres_compatible?
    end
  end
end
