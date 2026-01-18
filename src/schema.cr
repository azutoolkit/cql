# Standard Lib
require "db"
require "uri"
require "log"
require "file_utils" # For Dir.mkdir_p
require "json"

# Internal CQL Entry Point
require "./cql"

module CQL
  # The `Schema` class represents a database schema.
  #
  # This class provides methods to build and manage a database schema, including
  # creating tables, executing SQL statements, and generating queries.
  #
  # **Example** Creating a new schema
  # ```
  # schema = CQL::Schema.define(:northwind, "sqlite3://db.sqlite3") do
  #   table :users do
  #     primary :id, Int32, auto_increment: true
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
  # The `Schema` class represents a database schema.
  class Schema
    Log = CQL.config.logger

    class Error < Exception; end

    class InvalidURIError < Error; end

    class VersionConflictError < Error; end

    class ConnectionError < Error; end

    # - **@return** [Symbol] the name of the schema
    getter name : Symbol

    # - **@return** [String] the URI of the database
    getter uri : String

    # - **@return** [String] the version of the schema
    getter version : String

    # - **@return** [Adapter] the database adapter (default: `Adapter::SQLite`)
    getter adapter : Adapter = Adapter::SQLite

    # - **@return** [Hash(Symbol, Table)] the tables in the schema
    getter tables : Hash(Symbol, Table) = {} of Symbol => Table

    # - **@return** [DB::Database] the database connection pool
    private getter db : DB::Database

    # Fiber-local connection storage for thread-safe transaction handling
    @fiber_connections = {} of Fiber => DB::Connection
    @fiber_mutex = Mutex.new

    # Creates a new expression generator for thread-safe SQL generation.
    # Each call returns a fresh Generator instance to avoid state corruption
    # when multiple fibers generate SQL concurrently.
    #
    # - **@return** [Expression::Generator] a new generator instance
    #
    # **Example**
    # ```
    # gen = schema.new_generator
    # sql, params = query.to_sql(gen)
    # ```
    def new_generator : Expression::Generator
      Expression::Generator.new(@adapter)
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
      @fiber_mutex.synchronize do
        @fiber_connections[Fiber.current]?
      end
    end

    # Sets the active connection for the current fiber.
    # Used internally for transaction support.
    private def active_connection=(conn : DB::Connection?)
      @fiber_mutex.synchronize do
        if conn
          @fiber_connections[Fiber.current] = conn
        else
          @fiber_connections.delete(Fiber.current)
        end
      end
    end

    # Builds a new schema.
    #
    # - **@param** name [Symbol] the name of the schema
    # - **@param** uri [String] the URI of the database
    # - **@param** adapter [Adapter] the database adapter (default: `Adapter::SQLite`)
    # - **@param** version [String] the version of the schema (default: "1.0")
    # - **@yield** [Schema] the schema being built
    # - **@return** [Schema] the built schema
    #
    # **Example**
    # ```
    # schema = CQL::Schema.define(:northwind, "sqlite3://db.sqlite3") do |s|
    #   s.create_table :users do
    #     primary :id, Int32, auto_increment: true
    #     column :name, String
    #     column :email, String
    #   end
    # end
    # ```
    def self.define(name : Symbol, uri : String, adapter : Adapter, version : String = "1.0", &)
      schema = new(name, uri, adapter, version)
      with schema yield
      schema
    end

    # Initializes a new schema.
    #
    # - **@param** name [Symbol] the name of the schema
    # - **@param** uri [String] the URI of the database
    # - **@param** adapter [Adapter] the database adapter (default: `Adapter::SQLite`)
    # - **@param** version [String] the version of the schema (default: "1.0")
    #
    # **Example** Initializing a new schema
    # ```
    # schema = CQL::Schema.new(:northwind, "sqlite3://db.sqlite3")
    # ```
    def initialize(@name : Symbol, @uri : String, @adapter : Adapter, @version : String = "1.0")
      validate_uri!
      @db = DB.open(@uri)
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
        raise InvalidURIError.new("Missing host in PostgreSQL URI") unless uri.host
      else
        raise InvalidURIError.new("Unsupported database type: #{uri.scheme}")
      end
    rescue URI::Error
      raise InvalidURIError.new("Invalid URI format")
    end

    # Builds the schema. This method creates the tables in the schema.
    #
    # **Example**
    #
    # ```
    # schema.build
    # ```
    def build
      @tables.each do |_tbl_name, table|
        sql = table.create_sql
        exec(sql)
      end
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
      if conn = active_connection
        conn.exec(sql)
      else
        @db.using_connection do |db_conn|
          db_conn.exec(sql)
        end
      end
    end

    def exec_query(&)
      # Performance monitoring will be handled by individual query methods
      # that call this method, as we don't have access to SQL/params here
      if conn = active_connection
        yield conn
      else
        @db.using_connection do |db_conn|
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
    def transaction(&)
      previous_connection = active_connection
      @db.transaction do |tx|
        self.active_connection = tx.connection
        begin
          yield tx # Yield the transaction object itself, block can get connection via tx.connection if needed
        ensure
          self.active_connection = previous_connection
        end
      end
    rescue ex : DB::Rollback
      # DB::Rollback should be caught silently by the outer @db.transaction
      # and perform the rollback without propagating the exception further.
      # We log it for debugging, but don't convert to ConnectionError.
      Log.warn { "Transaction rolled back via DB::Rollback: #{ex.message}" }
    end

    def transaction(tx : DB::Transaction, &)
      previous_connection = active_connection
      self.active_connection = tx.connection
      begin
        yield tx # Yield the transaction object itself, block can get connection via tx.connection if needed
      ensure
        self.active_connection = previous_connection
      end
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

    # Creates a new table in the schema.
    # - **@param** name [Symbol] the name of the table
    # - **@param** as_name [Symbol] the alias of the table
    # - **@yield** [Table] the table being created
    # - **@return** [Table] the created table
    # **Example**
    # ```
    # schema.create_table :users do
    #   primary :id, Int32, auto_increment: true
    #   column :name, String
    #   column :email, String
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
    # - **@yield** [AlterTable] the table being altered
    # **Example**
    # ```
    # schema.alter(:users) do |t|
    #   t.add_column :age, Int32
    # end
    # ```
    # **Example**
    # ```
    # schema.alter(:users) do |t|
    #   t.drop_column :age
    # end
    # ```
    def alter(table_name : Symbol, &)
      raise Error.new("Table '#{table_name}' not found") unless tables[table_name]?

      alter_table = AlterTable.new(tables[table_name], self)
      with alter_table yield
      sql_statements = alter_table.to_sql(new_generator)

      exec_query do |conn|
        conn.transaction do |tx|
          cnn = tx.connection
          sql_statements.split(";\n").each do |sql|
            next if sql.empty?
            cnn.exec(sql)
          end
        end
      end
    end

    macro method_missing(call)
      def {{call.id}}
        tables[:{{call.id}}]
      end
    end
  end
end
