require "./connection"

module CQL::Postgres
  # Puts a connection back in a clean state before the pool lends it again:
  # rolls back a transaction the borrower left open, then runs the optional
  # reset statement (`DISCARD ALL`, `RESET ALL`, ...) followed by the pool's
  # setup hook, which a reset would otherwise undo. The result says whether the
  # connection may be reused; any failure means it must be dropped.
  struct ConnectionReset
    def initialize(@sql : String?, @setup : Proc(Connection, Nil)?, @timeout : Time::Span)
    end

    def call(connection : Connection) : Bool
      rollback(connection) if connection.in_transaction?
      @sql.try { |sql| reset(connection, sql) }
      !connection.in_transaction?
    rescue
      false
    end

    private def rollback(connection : Connection) : Nil
      run(connection, "ROLLBACK")
      connection.release_from_transaction
    end

    private def reset(connection : Connection, sql : String) : Nil
      run(connection, sql)
      connection.session.forget_prepared_statements
      @setup.try(&.call(connection))
    end

    private def run(connection : Connection, sql : String) : Nil
      connection.session.simple_query(sql, timeout: @timeout)
    end
  end
end
