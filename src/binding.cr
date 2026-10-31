require "./connection_source"

module CQL
  class UnboundSource < ConnectionSource
    def using_connection(& : DB::Connection -> _)
      raise CQL::Error.new("Schema is unbound; use Schema#bind or Model.on with a database, connection or transaction")
    end

    def pool_stats : PoolStats
      PoolStats.new(0, 0, 0, 0)
    end

    def close : Nil
    end
  end

  class BorrowedDatabaseSource < DatabaseSource
    def close : Nil
    end
  end

  class BorrowedConnectionSource < UnboundSource
    def initialize(@connection : DB::Connection)
    end

    def validate! : Nil
      raise CQL::Error.new("Bound connection is closed") if @connection.closed?
    end

    def using_connection(& : DB::Connection -> _)
      validate!
      yield @connection
    end
  end

  class BorrowedTransactionSource < BorrowedConnectionSource
    def initialize(@transaction : DB::Transaction)
      super(@transaction.connection)
    end

    def validate! : Nil
      raise CQL::Error.new("Bound transaction is closed") if @transaction.closed?
      super
    end

    def transaction(& : DB::Transaction -> _)
      using_connection { @transaction.transaction { |tx| yield tx } }
    end

    def transaction(before_begin : String, & : DB::Transaction -> _)
      raise ArgumentError.new("Cannot change transaction modes inside a borrowed transaction")
    end
  end

  class ReadOnlyExecutorSource < UnboundSource
    def using_connection(& : DB::Connection -> _)
      raise CQL::Error.new("Executor-only bindings do not support writes or transactions")
    end
  end

  # Reusable explicit execution context. It never owns the supplied resource.
  class Binding
    getter source : ConnectionSource
    getter read_executor : Executor?
    getter transaction_state = Schema::TransactionState.new
    @schemas = {} of Schema => Schema
    @adapter : Adapter? = nil
    @mutex = CQL::Compat::Mutex.new

    def initialize(db : DB::Database)
      @source = BorrowedDatabaseSource.new(db)
    end

    def initialize(connection : DB::Connection)
      @source = BorrowedConnectionSource.new(connection)
    end

    def initialize(transaction : DB::Transaction)
      @source = BorrowedTransactionSource.new(transaction)
    end

    def initialize(executor : Executor)
      @read_executor = executor
      @source = ReadOnlyExecutorSource.new
    end

    # :nodoc: Resolve declaration columns used by typed model queries to their
    # bound table, without accepting a table from a different mapping or tenant.
    def rebound_table(table : Table) : Table?
      @mutex.synchronize { @schemas[table.schema]?.try(&.tables[table.table_name]?) }
    end

    def schema(mapping : Schema) : Schema
      return mapping if mapping.binding == self
      if executor = @read_executor
        raise CQL::Error.new("Binding adapter does not match the mapping") unless executor.adapter == mapping.adapter
      end
      @mutex.synchronize do
        if declared = @adapter
          raise CQL::Error.new("Cannot combine different adapters in one binding") unless declared == mapping.adapter
        end
        @adapter = mapping.adapter
        @schemas[mapping] ||= mapping.copy_for_binding(self)
      end
    end
  end
end
