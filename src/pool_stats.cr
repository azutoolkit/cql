require "db"

module CQL
  # Snapshot of a schema's connection pool. `max` 0 means unlimited;
  # `in_flight` counts connections currently checked out.
  struct PoolStats
    getter open : Int32
    getter idle : Int32
    getter in_flight : Int32
    getter max : Int32

    def initialize(@open, @idle, @in_flight, @max)
    end

    def self.from(stats : DB::Pool::Stats) : PoolStats
      busy = (stats.open_connections - stats.idle_connections).clamp(0, stats.open_connections)
      new(stats.open_connections, stats.idle_connections, busy, stats.max_connections)
    end
  end
end
