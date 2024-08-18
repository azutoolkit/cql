module Cql
  # The `Schema` class represents a database schema.
  #
  # This class provides methods to build and manage a database schema, including
  # creating tables, executing SQL statements, and generating queries.
  #
  # **Example** Creating a new schema
  # ```
  # schema = Cql::Schema.define(:northwind, "sqlite3://db.sqlite3") do
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
  # The `Schema` class represents a database schema.
  class Schema
    Log = ::Log.for(self)

    # - **@return** [Symbol] the name of the schema
    getter name : Symbol

    # - **@return** [String] the URI of the database
    getter uri : String

    # - **@return** [DB::Connection] the database connection
    getter db : DB::Connection

    # - **@return** [String] the version of the schema
    getter version : String

    # - **@return** [Adapter] the database adapter (default: `Adapter::Sqlite`)
    getter adapter : Adapter = Adapter::Sqlite

    # - **@return** [Hash(Symbol, Table)] the tables in the schema
    getter tables : Hash(Symbol, Table) = {} of Symbol => Table

    # - **@return** [Expression::Generator] the expression generator
    getter gen : Expression::Generator

    # Builds a new schema.
    #
    # - **@param** name [Symbol] the name of the schema
    # - **@param** uri [String] the URI of the database
    # - **@param** adapter [Adapter] the database adapter (default: `Adapter::Sqlite`)
    # - **@param** version [String] the version of the schema (default: "1.0")
    # - **@yield** [Schema] the schema being built
    # - **@return** [Schema] the built schema
    #
    # **Example**
    # ```
    # schema = Cql::Schema.define(:northwind, "sqlite3://db.sqlite3") do |s|
    #   s.create_table :users do
    #     primary :id, Int64, auto_increment: true
    #     column :name, String
    #     column :email, String
    #   end
    # end
    # ```
    def self.define(name : Symbol, uri : String, adapter : Adapter = Adapter::Sqlite, version : String = "1.0", &)
      schema = new(name, uri, adapter, version)
      with schema yield
      schema
    end

    # Initializes a new schema.
    #
    # - **@param** name [Symbol] the name of the schema
    # - **@param** uri [String] the URI of the database
    # - **@param** adapter [Adapter] the database adapter (default: `Adapter::Sqlite`)
    # - **@param** version [String] the version of the schema (default: "1.0")
    #
    # **Example** Initializing a new schema
    # ```
    # schema = Cql::Schema.new(:northwind, "sqlite3://db.sqlite3")
    # ```
    def initialize(@name : Symbol, @uri : String, @adapter : Adapter = Adapter::Sqlite, @version : String = "1.0")
      @db = DB.connect(@uri)
      @gen = Expression::Generator.new(@adapter)
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
      @db.transaction do |tx|
        cnn = tx.connection
        cnn.exec(sql)
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

    # Creates a new migrator for the schema.
    # - **@return** [Migrator] the new migrator
    # **Example**
    # ```
    # migrator = schema.migrator
    # ```
    def migrator
      Migrator.new(self)
    end

    # Creates a new table in the schema.
    # - **@param** name [Symbol] the name of the table
    # - **@param** as_name [Symbol] the alias of the table
    # - **@yield** [Table] the table being created
    # - **@return** [Table] the created table
    # **Example**
    # ```
    # schema.create_table :users do
    #   primary :id, Int64, auto_increment: true
    #   column :name, String
    #   column :email, String
    # end
    # ```
    #
    def table(name : Symbol, as as_name = nil, &)
      table = Table.new(name, self, as_name)
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
      alter_table = AlterTable.new(tables[table_name], self)
      with alter_table yield
      sql_statements = alter_table.to_sql(@gen)
      Log.debug { sql_statements }

      db.transaction do |tx|
        cnn = tx.connection
        sql_statements.split(";\n").each do |sql|
          cnn.exec(sql) unless sql.empty?
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
