require "../executor"
require "./connection"

module CQL::Postgres
  enum IsolationLevel
    ReadUncommitted
    ReadCommitted
    RepeatableRead
    Serializable

    def to_sql : String
      to_s.underscore.tr("_", " ").upcase
    end
  end

  # An open transaction on one pooled connection. Statements run `using(scope)`
  # join it, and `savepoint` nests inside it.
  class TransactionScope < CQL::ConnectionExecutor
    def initialize(adapter : CQL::Adapter, connection : ::DB::Connection, @transaction : ::DB::Transaction)
      super(adapter, connection)
    end

    # Streams a query's rows on the transaction's connection. See `AsyncEngine#stream`.
    def stream(query : String, args : Array(::DB::Any) = [] of ::DB::Any, fetch_size : Int32 = 1000, timeout : Time::Span? = nil, & : ::DB::ResultSet -> T) : T forall T
      CQL::Execution.run(self, query, args, :select) do |connection|
        connection.as(Connection).stream(query, args, fetch_size, timeout) { |rows| yield rows }
      end
    end

    def stream(query, fetch_size : Int32 = 1000, timeout : Time::Span? = nil, & : ::DB::ResultSet -> T) : T forall T
      sql, params = query.to_sql
      stream(sql, params, fetch_size, timeout) { |rows| yield rows }
    end

    # Runs the block inside a SAVEPOINT: if it raises, only its own work is
    # rolled back to the savepoint and the exception propagates (raise
    # `DB::Rollback` to undo it quietly, which makes this return nil). The
    # yielded scope can open savepoints of its own.
    def savepoint(& : TransactionScope -> T) : T? forall T
      @transaction.transaction { |nested| yield TransactionScope.new(@adapter, @connection, nested) }
    end
  end
end
