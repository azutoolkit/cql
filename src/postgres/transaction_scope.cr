require "../executor"
require "../isolation_level"
require "./connection"
require "./query_streaming"

module CQL::Postgres
  alias IsolationLevel = CQL::IsolationLevel

  # An open transaction on one pooled connection. Statements run `using(scope)`
  # join it, and `savepoint` nests inside it. The scope is only good for the
  # block it was given to: afterwards the connection is back in the pool, so
  # using it again raises `TransactionClosed`.
  class TransactionScope
    include CQL::Executor
    include QueryStreaming

    getter adapter : CQL::Adapter

    def initialize(@adapter : CQL::Adapter, @connection : Connection, @transaction : ::DB::Transaction)
      @owner = Fiber.current
      @finished = false
    end

    def exec_query(& : ::DB::Connection -> _)
      ensure_open
      yield @connection
    end

    protected def finish : Nil
      @finished = true
    end

    # Runs the block inside a SAVEPOINT: if it raises, only its own work is
    # rolled back to the savepoint and the exception propagates (raise
    # `DB::Rollback` to undo it quietly, which makes this return nil). The
    # yielded scope can open savepoints of its own.
    def savepoint(& : TransactionScope -> T) : T? forall T
      ensure_open
      @transaction.transaction do |nested|
        scope = TransactionScope.new(@adapter, @connection, nested)
        begin
          yield scope
        ensure
          scope.finish
        end
      end
    end

    private def ensure_open : Nil
      raise WrongFiber.new("a transaction scope must be used by the fiber that opened it; open a separate transaction in this fiber") unless Fiber.current == @owner
      raise TransactionClosed.new("the transaction has ended; this scope can no longer run statements") if @finished || @transaction.closed?
    end
  end
end
