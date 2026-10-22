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

    # Runs the block inside a SAVEPOINT: if it raises, only its own work is
    # rolled back to the savepoint and the exception propagates (raise
    # `DB::Rollback` to undo it quietly, which makes this return nil). The
    # yielded scope can open savepoints of its own.
    def savepoint(& : TransactionScope -> T) : T? forall T
      @transaction.transaction { |nested| yield TransactionScope.new(@adapter, @connection, nested) }
    end
  end
end
