require "./executor"
require "./operation_kind"
# Standard Lib
require "db"
require "uri"
require "log"
require "file_utils" # For Dir.mkdir_p
require "json"

# Internal CQL Entry Point
require "./exceptions"
require "./cql"
require "./pool_stats"
require "./connection_source"
require "./rollback_hooks"

module CQL
  # The `Schema` class represents a database schema.
  #
  # This class provides methods to build and manage a database schema, including
  # creating tables, executing SQL statements, and generating queries.
  #
  # **Example** Creating a new schema
  # ```
  # AcmeDB = CQL::Schema.define(:acme_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://./db/acme.db") do
  #   table :users do
  #     primary :id, Int64, auto_increment: true
  #     column :name, String
  #     column :email, String
  #   end
  # end
  # ```
  #
  # **Example** Executing a SQL statement
  # ```
  # schema.exec("CREATE TABLE products (id INTEGER PRIMARY KEY, name TEXT)")
  # ```
  #
  # **Example** Creating a new query
  # ```
  # query = schema.query
  # ```
  class Schema
    include Executor

    Log = CQL.config.logger

    class Error < CQL::Error; end

    class InvalidURIError < Error; end

    class VersionConflictError < Error; end

    class ConnectionError < Error; end

    # - **@return** [Symbol] the name of the schema
    getter name : Symbol

    # - **@return** [String] the URI of the database: the string given, or for a schema with a `source:` the crystal-db-safe
    #   form of it (`ConnectionSource#database_uri`, e.g. without the engine's pool options)
    getter uri : String

    # - **@return** [String] the version of the schema
    getter version : String

    # - **@return** [Adapter] the database adapter (default: `Adapter::SQLite`)
    getter adapter : Adapter = Adapter::SQLite

    # - **@return** [Bool] whether generated SQL quotes table, column and alias
    #   names (opt-in; needed for reserved words such as `order` or `group`).
    #   Applies to queries and DML (SELECT/INSERT/UPDATE/DELETE); DDL emitted by
    #   `build`, migrations and `alter` is not quoted yet, so create such tables
    #   with raw SQL or a quoted migration.
    getter quote_identifiers : Bool = false

    # - **@return** [Hash(Symbol, Table)] the tables in the schema
    getter tables : Hash(Symbol, Table) = {} of Symbol => Table

    # - **@return** [ConnectionSource] where connections and transactions come from:
    #   crystal-db's pool by default, or any other source (e.g. `Postgres::EngineSource`)
    getter source : ConnectionSource

    # Connection pool occupancy, read without checking out a connection.
    # All zeros before the first query when the pool was opened with `initial_pool_size=0`.
    def pool_stats : PoolStats
      @source.pool_stats
    rescue # a stats read must never take the caller down (dashboards poll it)
      PoolStats.new(0, 0, 0, 0)
    end

    # Closes the connection source (the pool); later statements fail.
    def close : Nil
      @source.close
    end

    # :nodoc:
    # One entry of a fiber's transaction stack: the transaction and the rollback hooks of the work done in it.
    record TransactionFrame, transaction : DB::Transaction, rollback_hooks : RollbackHooks

    # Fiber-local transaction stacks: each fiber's entered transactions (and savepoints), innermost last.
    # A frame's rollback hooks are only touched by the fiber that owns the stack.
    @fiber_transactions = {} of Fiber => Array(TransactionFrame)
    @fiber_mutex = CQL::Compat::Mutex.new
    # Mirrors `@fiber_transactions.size`: queries skip the mutex only while no fiber has a transaction open
    @fibers_in_transaction = Atomic(Int32).new(0)

    # Creates a new expression generator for thread-safe SQL generation.
    # Each call returns a fresh Generator instance to avoid state corruption
    # when multiple fibers generate SQL concurrently.
    #
    # - **@return** [Expression::Generator] a new generator instance
    #
    # **Example**
    # ```
    # gen = schema.new_generator
    # sql, params = schema.query.from(:users).to_sql(gen)
    # ```
    def new_generator : Expression::Generator
      Expression::Generator.new(@adapter, @quote_identifiers)
    end

    # Returns a generator for SQL expression building.
    # **DEPRECATED**: Use `new_generator` instead for thread-safe SQL generation.
    # This method creates a new generator each time to prevent concurrent access issues.
    @[Deprecated("Use new_generator for thread-safe SQL generation")]
    def gen : Expression::Generator
      new_generator
    end

    # Gets the active connection for the current fiber, if any.
    # Used internally for transaction support.
    private def active_connection : DB::Connection?
      active_transaction.try(&.connection)
    end

    private def active_transaction : DB::Transaction?
      active_frame.try(&.transaction)
    end

    # The frame of the fiber's innermost transaction still open; any closed by hand (`tx.commit`/`tx.rollback`)
    # are skipped, so work falls back to the enclosing transaction rather than leaving it.
    private def active_frame : TransactionFrame?
      return if @fibers_in_transaction.get.zero? # this fiber's own push is already visible, so 0 means it has none
      @fiber_mutex.synchronize do
        @fiber_transactions[Fiber.current]?.try { |stack| stack.reverse_each.find { |frame| !frame.transaction.closed? } }
      end
    end

    # Pushes *tx*, with the *rollback_hooks* of the work done in it, onto the fiber's transaction stack for the
    # block and pops it afterwards.
    private def with_active_transaction(tx : DB::Transaction, rollback_hooks : RollbackHooks, &)
      fiber = Fiber.current
      @fiber_mutex.synchronize do
        (@fiber_transactions[fiber] ||= [] of TransactionFrame).push(TransactionFrame.new(tx, rollback_hooks))
        @fibers_in_transaction.set(@fiber_transactions.size)
      end
      begin
        yield
      ensure
        @fiber_mutex.synchronize do
          stack = @fiber_transactions[fiber]
          stack.pop
          @fiber_transactions.delete(fiber) if stack.empty?
          @fibers_in_transaction.set(@fiber_transactions.size)
        end
      end
    end

    # Builds a new schema.
    #
    # - **@param** name [Symbol] the name of the schema
    # - **@param** uri [String] the URI of the database
    # - **@param** adapter [Adapter] the database adapter
    # - **@param** version [String] the version of the schema (default: "1.0")
    # - **@param** quote_identifiers [Bool] whether generated SQL quotes identifiers (default: false)
    # - **@param** source [ConnectionSource] where connections come from (default: crystal-db's pool opened from the URI)
    # - **@yield** the block runs with the schema as its receiver, so `table` declares a table
    # - **@return** [Schema] the built schema
    #
    # **Example**
    # ```
    # AcmeDB = CQL::Schema.define(:acme_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://./db/acme.db") do
    #   table :users do
    #     primary :id, Int64, auto_increment: true
    #     column :name, String
    #     column :email, String
    #   end
    # end
    # ```
    def self.define(name : Symbol, uri : String, adapter : Adapter, version : String = "1.0", quote_identifiers : Bool = false, source : ConnectionSource? = nil, &)
      schema = new(name, uri, adapter, version, quote_identifiers, source)
      with schema yield
      schema
    end

    # Initializes a new schema.
    #
    # - **@param** name [Symbol] the name of the schema
    # - **@param** uri [String] the URI of the database
    # - **@param** adapter [Adapter] the database adapter
    # - **@param** version [String] the version of the schema (default: "1.0")
    #
    # **Example** Initializing a new schema
    # ```
    # schema = CQL::Schema.new(:acme_db, "sqlite3://./db/acme.db", CQL::Adapter::SQLite)
    # ```
    #
    # **Example** Running on the native PostgreSQL engine's pool
    # ```
    # engine = CQL::Postgres::AsyncEngine.connect("postgres://app@db/app?pool_size=10")
    # schema = CQL::Schema.new(:app, "postgres://app@db/app", CQL::Adapter::Postgres,
    #   source: CQL::Postgres::EngineSource.new(engine))
    # ```
    def initialize(@name : Symbol, @uri : String, @adapter : Adapter, @version : String = "1.0", @quote_identifiers : Bool = false, source : ConnectionSource? = nil)
      validate_uri!
      if source && (declared = source.adapter) && declared != @adapter
        raise ArgumentError.new("the connection source speaks #{declared}, the schema uses #{@adapter} (build the engine with adapter: to match)")
      end
      @source = source || DatabaseSource.new(open_database)
      @uri = source.database_uri(@uri) if source # `uri` names the same server; the source's own options stay out of it
    end

    private def open_database : DB::Database
      url = URI.parse(@adapter.driver_uri(@uri))
      if @adapter.postgres_compatible? && url.query_params.has_key?("query_timeout") &&
         (reason = CQL::Postgres::Driver.unread_query_timeout(url.scheme.to_s))
        CQL.config.effective_logger.warn { reason }
      end
      DB.open(url)
    end

    def dialect
      @adapter.dialect
    end

    # Validates the database URI format
    private def validate_uri!
      uri = URI.parse(@uri)
      raise InvalidURIError.new("Invalid database URI format") unless uri.scheme && uri.path

      case uri.scheme
      when "sqlite3"
        # Valid SQLite URI
      when "postgres", "postgresql"
        raise InvalidURIError.new("Missing host in PostgreSQL URI") unless postgres_host?(uri)
      when "mysql"
        raise InvalidURIError.new("Missing host in MySQL URI") unless uri.host.presence
      when "cockroachdb"
        raise InvalidURIError.new("Missing host in CockroachDB URI") unless postgres_host?(uri)
      else
        raise InvalidURIError.new("Unsupported database type: #{uri.scheme}")
      end
    rescue URI::Error
      raise InvalidURIError.new("Invalid URI format")
    end

    # The PostgreSQL driver's fallbacks for an empty host: a Unix-socket directory in `?host=`, then PGHOST.
    private def postgres_host?(uri : URI) : Bool
      !!(uri.host.presence || uri.query_params["host"]?.presence || ENV["PGHOST"]?.presence)
    end

    # Builds the schema. This method creates the tables in the schema.
    #
    # **Example**
    #
    # ```
    # schema.build
    # ```
    def build
      ddl_transaction { @tables.each_value(&.create!) }
    end

    # Executes a SQL statement.
    #
    # - **@param** sql [String] the SQL statement to execute
    #
    # **Example**
    # ```
    # schema.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
    # ```
    def exec(sql : String)
      Execution.run(self, sql, [] of DB::Any, OperationKind.of(sql), track: false) { |connection| connection.exec(sql) }
    end

    # Yields the fiber's transaction connection, or else one pooled connection, to pin statements to it with `using(connection)`
    # (e.g. inside a transaction started on that connection).
    def with_connection(&)
      if connection = active_connection
        yield connection
      else
        @source.using_connection { |pooled| yield pooled }
      end
    end

    def exec_query(& : DB::Connection -> _)
      # Performance monitoring will be handled by individual query methods
      # that call this method, as we don't have access to SQL/params here
      if conn = active_connection
        yield conn
      else
        @source.using_connection do |db_conn|
          yield db_conn
        end
      end
    end

    # Creates a new query for the schema.
    #
    # - **@return** [Query] the new query
    #
    # **Example**
    # ```
    # query = schema.query
    # ```
    def query
      Query.new(self)
    end

    # Creates a new insert query for the schema.
    # - **@return** [Insert] the new insert query
    # **Example**
    # ```
    # insert = schema.insert
    # ```
    def insert
      Insert.new(self)
    end

    # Creates a new update query for the schema.
    # - **@return** [Update] the new update query
    # **Example**
    # ```
    # update = schema.update
    # ```
    def update
      Update.new(self)
    end

    # Creates a new delete query for the schema.
    # - **@return** [Delete] the new delete query
    # **Example**
    # ```
    # delete = schema.delete
    # ```
    def delete
      Delete.new(self)
    end

    # Executes a block within a database transaction.
    # - **@yield** [DB::Transaction] the transaction object
    # - **@return** [Nil] the result of the block
    # **Example**
    # ```
    # schema.transaction do |tx|
    #   cnn = tx.connection
    #   cnn.exec("INSERT INTO users (name) VALUES (?)", "John")
    #   cnn.exec("UPDATE accounts SET balance = balance - 100 WHERE user_id = ?", 1)
    # end
    # ```
    #
    # Called inside another transaction on the same fiber, it runs as a SAVEPOINT
    # on that transaction's connection.
    #
    # Publishes `Telemetry::TransactionEvent`s to `Telemetry.subscribe_transactions`
    # subscribers. A manual `tx.rollback` followed by a normal return still
    # reports Commit, since CQL cannot see it.
    #
    # When the transaction rolls back (the block raises, including `DB::Rollback`,
    # or the commit fails), table declarations changed by `alter` inside it are
    # restored. A savepoint that commits leaves them to the enclosing transaction.
    # A manual `tx.rollback` restores nothing, for the same reason as above.
    #
    # *isolation* runs the transaction at that level (`transaction(isolation: :serializable) { }`). A dialect
    # that cannot honour it raises `DialectError`, and a nested call raises `ArgumentError`, before anything begins.
    def transaction(*, isolation : IsolationLevel? = nil, &)
      parent = active_frame
      set_isolation = isolation_statement(isolation, nested: !parent.nil?)
      observer = Telemetry.begin_transaction(@adapter, !parent.nil?)
      rollback_hooks = RollbackHooks.new
      # Nested calls open a SAVEPOINT on the outer transaction's connection.
      (parent.try(&.transaction) || @source).transaction do |tx|
        set_isolation.try { |sql| tx.connection.unprepared.exec(sql) } # bypasses Execution, so telemetry sees no user statement
        with_active_transaction(tx, rollback_hooks) do
          yield tx # Yield the transaction object itself, block can get connection via tx.connection if needed
        rescue ex
          rollback_hooks.run
          observer.try &.failed(ex)
          raise ex
        end
      end
    rescue ex : DB::Rollback
      # DB::Rollback should be caught silently by the outer source transaction
      # and perform the rollback without propagating the exception further.
      # We log it for debugging, but don't convert to ConnectionError.
      rollback_hooks.try &.run
      Log.warn { "Transaction rolled back via DB::Rollback: #{ex.message}" }
    rescue ex
      rollback_hooks.try &.run
      observer.try &.failed(ex)
      raise ex
    ensure
      # Hooks still pending belong to work that was kept (committed, or left by a `return` from the block).
      rollback_hooks.try &.hand_to(parent.try(&.rollback_hooks))
      observer.try &.finish
    end

    # Crystal consults `method_missing` before it casts a symbol to an enum, so `isolation: :serializable` lands here.
    def transaction(*, isolation : Symbol, &)
      level = IsolationLevel.parse?(isolation.to_s) || raise ArgumentError.new(
        "unknown isolation level #{isolation.inspect}; use :read_uncommitted, :read_committed, :repeatable_read or :serializable")
      transaction(isolation: level) { |tx| yield tx }
    end

    def transaction(tx : DB::Transaction, &)
      # Not this schema's transaction to commit or roll back: rollback hooks go to the enclosing one, if any.
      rollback_hooks = active_frame.try(&.rollback_hooks) || RollbackHooks.new
      with_active_transaction(tx, rollback_hooks) do
        yield tx # Yield the transaction object itself, block can get connection via tx.connection if needed
      end
    end

    # A savepoint runs at the level of the transaction it is in.
    private def isolation_statement(isolation : IsolationLevel?, nested : Bool) : String?
      return unless isolation
      raise ArgumentError.new("isolation: cannot change the level inside a transaction; set it on the outermost one") if nested
      dialect.isolation_level_sql(isolation)
    end

    # Creates a new migrator for the schema.
    # - **@return** [Migrator] the new migrator
    # **Example**
    # ```
    # migrator = schema.migrator
    # ```
    def migrator
      Migrator.new(self)
    end

    # Creates a new migrator with custom configuration for schema synchronization.
    # - **@param** config [MigratorConfig] the configuration for the migrator
    # - **@return** [Migrator] the new migrator with custom config
    # **Example**
    # ```
    # config = CQL::MigratorConfig.new(
    #   schema_file_path: "src/schemas/my_app_schema.cr",
    #   schema_name: :MyAppSchema,
    #   schema_symbol: :my_app_schema
    # )
    # migrator = schema.migrator(config)
    # ```
    def migrator(config : MigratorConfig)
      Migrator.new(self, config)
    end

    # Creates a schema dumper for this schema.
    # - **@return** [SchemaDump] the new schema dumper
    # **Example**
    # ```
    # dumper = schema.schema_dumper
    # ```
    def schema_dumper
      SchemaDump.from_schema(self)
    end

    # Declares a table in the schema; `Table#create!` or `Schema#build` creates it in the database.
    # - **@param** name [Symbol] the name of the table
    # - **@param** as [Symbol, String, nil] the alias of the table
    # - **@yield** the block runs with the table as its receiver
    # - **@return** [Table] the declared table
    # **Example**
    # ```
    # schema.table :tags do
    #   primary :id, Int64, auto_increment: true
    #   column :name, String
    # end
    # ```
    #
    def table(name : Symbol, as as_name : Symbol? = nil, &)
      table = Table.new(name, self, as_name.try(&.to_s))
      with table yield
      @tables[name] = table
      table
    end

    def table(name : Symbol, as as_name : String? = nil, &)
      table = Table.new(name, self, as_name || "")
      with table yield
      @tables[name] = table
      table
    end

    # Alter a table in the schema.
    # - **@param** table_name [Symbol] the name of the table
    # - **@yield** the block runs with an `AlterTable` as its receiver
    # **Example**
    # ```
    # schema.alter :users do
    #   add_column :phone, String
    # end
    # ```
    # **Example**
    # ```
    # schema.alter :users do
    #   drop_column :age
    # end
    # ```
    #
    # Where DDL is transactional, a rollback of the surrounding transaction also restores the table's declaration.
    # The restore puts back the whole declaration as it was before this `alter`, so it also undoes another fiber's
    # uncommitted `alter` of the same table.
    def alter(table_name : Symbol, &)
      table = tables[table_name]? || raise Error.new("Table '#{table_name}' not found")

      ddl_transaction do
        on_rollback(&table.declaration_snapshot)
        alter_table = AlterTable.new(table, self)
        with alter_table yield
        statements = alter_table.statements(new_generator)

        with_connection do |connection|
          statements.each { |sql| connection.exec(sql) }
        end
      end
    end

    # Runs schema changes atomically where DDL is transactional (a SAVEPOINT inside an open
    # transaction); where DDL commits implicitly, runs them bare and refuses inside an open transaction.
    def ddl_transaction(&)
      require_transactional_ddl!
      return yield unless dialect.supports_transactional_ddl?
      transaction { yield }
    end

    # Runs *hook* if the fiber's innermost open transaction rolls back, even after the savepoint it was registered in
    # committed. Outside a transaction there is nothing to roll back, so it is dropped.
    private def on_rollback(&hook : ->) : Nil
      active_frame.try { |frame| frame.rollback_hooks << hook }
    end

    # Raises where DDL commits implicitly, because running it inside an open transaction would
    # silently commit the caller's pending work.
    private def require_transactional_ddl! : Nil
      return if active_transaction.nil? || dialect.supports_transactional_ddl?
      raise DialectError.new(dialect.display_name, "schema changes inside a transaction", "Run it outside the transaction.")
    end

    macro method_missing(call)
      def {{call.id}}
        tables[:{{call.id}}]
      end
    end
  end
end
