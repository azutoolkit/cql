require "digest/crc32"

module CQL
  # The advisory lock that makes migrators of one records table take turns (PostgreSQL; nothing on dialects without
  # one). `Migrator.new` and a run with migrations to apply or roll back take it inside their DDL transaction, which
  # holds it until it ends. A wait longer than `MigratorConfig#lock_timeout` raises `Migrator::Error`.
  private struct MigrationLock
    BATCH_SALT = 0x43514C4D_i64 # "CQLM"
    ALONE_SALT = 0x43514C41_i64 # "CQLA"

    private getter schema : Schema
    private getter config : MigratorConfig

    def initialize(@schema : Schema, @config : MigratorConfig)
    end

    # Keyed by the records table, so migrators of other tables do not wait.
    def acquire : Nil
      return unless sql = schema.dialect.migration_lock_sql
      require_read_committed!
      schema.with_connection do |connection|
        within_lock_timeout(connection) { connection.exec(sql, key) }
      end
    end

    # Migrators take turns on a `disable_ddl_transaction!` migration: a session lock of its own on one pooled connection
    # (the migration's statements use another), outside any transaction, polled until free or `lock_timeout`.
    def hold_alone(&) : Nil
      try_lock, unlock = schema.dialect.migration_try_session_lock_sql, schema.dialect.migration_session_unlock_sql
      return yield unless try_lock && unlock
      require_read_committed!
      schema.with_connection do |connection|
        deadline = config.lock_timeout.try { |timeout| Time.instant + timeout }
        until connection.query_one(try_lock, key(ALONE_SALT), as: Bool)
          raise timed_out(config.lock_timeout.not_nil!) if deadline && Time.instant >= deadline
          sleep 50.milliseconds
        end
        begin
          yield
        ensure
          connection.exec(unlock, key(ALONE_SALT))
        end
      end
    end

    # Bounds the lock wait alone: the migrations then run under the lock_timeout the connection had.
    private def within_lock_timeout(connection : DB::Connection, &) : Nil
      dialect, timeout = schema.dialect, config.lock_timeout
      read, set = dialect.lock_timeout_sql, dialect.set_lock_timeout_sql
      return yield unless timeout && read && set
      previous = connection.query_one(read, as: String)
      connection.exec(set, lock_timeout_milliseconds(timeout))
      begin
        yield
      rescue error
        raise error unless dialect.lock_timed_out?(error)
        raise timed_out(timeout, error)
      end
      connection.exec(set, previous)
    end

    private def timed_out(timeout : Time::Span, cause : Exception? = nil) : Migrator::Error
      Migrator::Error.new("Another migrator holds the migration lock on #{config.migration_table_name}; gave up after " \
                          "#{timeout.total_seconds} s (MigratorConfig#lock_timeout) waiting for it. Raise lock_timeout, " \
                          "or set it to nil to wait until that run ends", cause: cause)
    end

    # At least 1 ms (0 means no bound) and at most Int32::MAX ms, the largest lock_timeout PostgreSQL takes.
    private def lock_timeout_milliseconds(timeout : Time::Span) : String
      timeout.total_milliseconds.clamp(1.0, Int32::MAX.to_f).ceil.to_i.to_s
    end

    # A snapshot taken before the lock wait (REPEATABLE READ, SERIALIZABLE) misses the run it waited for.
    private def require_read_committed! : Nil
      return unless sql = schema.dialect.transaction_isolation_sql
      level = schema.with_connection(&.query_one(sql, as: String))
      return if schema.dialect.migration_lock_isolation_safe?(level)
      raise Migrator::Error.new("Migrations take an advisory lock and must run at READ COMMITTED, not " \
                                "#{level.upcase}: run them outside a REPEATABLE READ or SERIALIZABLE transaction and " \
                                "with default_transaction_isolation at READ COMMITTED")
    end

    # A CQL salt ("CQLM") in the high 32 bits keeps the key clear of the small integers apps use for their locks.
    private def key(salt = BATCH_SALT) : Int64
      table = config.migration_table_name.to_s.downcase.rpartition('.').last
      (salt << 32) | Digest::CRC32.checksum(table).to_i64
    end
  end
end
