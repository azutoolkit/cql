require "./table"  # Assuming table.cr defines Table
require "./schema" # Assuming schema.cr defines Schema

module CQL
  # An insert statement builder class
  # This class provides methods for building an insert statement
  # It also provides methods for executing the statement
  #
  # **Example** Inserting a record
  #
  # ```
  # insert
  #   .into(:users)
  #   .values(name: "John", age: 30)
  #   .last_insert_id
  # ```
  #
  # **Example** Inserting multiple records
  #
  # ```
  # insert
  #   .into(:users)
  #   .values(
  #     [
  #       {name: "John", age: 30},
  #       {name: "Jane", age: 25},
  #     ]
  #   ).commit
  # ```
  #
  # **Example** Inserting a record with a query
  #
  # ```
  # insert
  #   .into(:users)
  #   .query(
  #     select.from(:users).where(id: 1)
  #   ).commit
  # ```
  class Insert
    Log = CQL.config.logger

    @table : Table? = nil
    @columns : Set(Expression::Column) = Set(Expression::Column).new
    @values : Array(Array(DB::Any)) = Array(Array(DB::Any)).new
    @back : Array(Expression::Column) = Array(Expression::Column).new
    @query : Query? = nil

    def initialize(@schema : Schema)
    end

    # Inserts and gets the last inserted ID from the database
    # Works with SQLite, PostgreSQL and MySQL.
    #
    # **Important Requirements:**
    # - The table must have an auto-generated primary key:
    #   - SQLite: `INTEGER PRIMARY KEY` (with or without `AUTOINCREMENT`)
    #   - MySQL: Column with `AUTO_INCREMENT` attribute
    #   - PostgreSQL: `SERIAL`, `BIGSERIAL`, or `GENERATED AS IDENTITY`
    # - This method must be called immediately after the insert
    # - Uses the same database connection for both operations
    # - Will return 0 or raise an error if no auto-generated key exists
    #
    # **Database-specific behavior:**
    # - PostgreSQL: Uses `RETURNING id` clause in the INSERT statement
    # - MySQL: Executes insert, then queries `LAST_INSERT_ID()`
    # - SQLite: Executes insert, then queries `last_insert_rowid()`
    #
    # - **@param** type [PrimaryKeyType] The type to cast the ID to (default: Int64)
    # - **@return** [Int64 | Int32 | UUID | ULID] The last inserted ID
    #
    # **Example** Getting the last inserted ID
    #
    # ```
    # # Ensure your table has an auto-increment primary key:
    # # primary :id, Int64, auto_increment: true
    #
    # user_id = insert
    #   .into(:users)
    #   .values(name: "John", age: 30)
    #   .last_insert_id
    #
    # puts user_id # => 1 (or next available ID)
    # ```
    def last_insert_id(as type : PrimaryKeyType = Int64)
      case adapter
      when .postgres?
        # PostgreSQL: Use RETURNING clause to get the inserted ID
        @back = Array(Expression::Column).new
        query, params = back(:id).to_sql
        @schema.exec_query do |conn|
          conn.query_one(query, args: params, as: type)
        end
      when .my_sql?, .sqlite?
        # MySQL and SQLite: Execute insert first, then query for last ID
        self.commit
        if sql = @schema.gen.dialect.last_insert_id_query
          @schema.exec_query do |conn|
            conn.query_one(sql, as: type)
          end
        else
          raise "Dialect does not support last_insert_id_query"
        end
      else
        raise "Unsupported adapter for last_insert_id: #{adapter}"
      end
    end

    private def adapter
      @schema.adapter
    end

    # Executes the insert statement and returns the result
    # - **@return** [Int64] The last inserted ID
    #
    # **Example** Inserting a record
    #
    # ```
    # insert
    #   .into(:users)
    #   .values(name: "John", age: 30)
    #   .commit
    #
    # => 1
    # ```
    def commit
      query, params = to_sql
      @schema.exec_query do |conn|
        conn.exec(query, args: params)
      end
    rescue ex
      Log.error { "Insert failed: #{ex.message}" }
      raise ex
    end

    # Set the table to insert into
    # - **@param** table [Symbol] The table to insert into
    # - **@return** [Insert] The insert object
    #
    # **Example** Inserting a record
    #
    # ```
    # insert
    #   .into(:users)
    #   .values(name: "John", age: 30)
    #   .commit
    # ```
    def into(table : Symbol)
      @table = find_table(table)
      self
    end

    # Set the columns to insert
    # - **@param** columns [Array(Symbol)] The columns to insert
    # - **@return** [Insert] The insert object
    #
    # **Example** Inserting a record
    #
    # ```
    # insert
    #   .into(:users)
    #   .columns(:name, :age)
    #   .values("John", 30)
    #   .commit
    # ```
    def values(values : Array(Hash(Symbol, DB::Any)))
      values.map { |hash| build_values(hash) }
      self
    end

    # Set the values to insert
    # - **@param** hash [Hash(Symbol, DB::Any)] The values to insert
    # - **@return** [Insert] The insert object
    #
    # **Example** Inserting a record
    #
    # ```
    # insert.into(:users).values(name: "John", age: 30).commit
    # ```
    def values(hash : Hash(Symbol, DB::Any))
      build_values(hash)
      self
    end

    # Set the values to insert
    # - **@param** fields [Hash(Symbol, DB::Any)] The values to insert
    # - **@return** [Insert] The insert object
    #
    # **Example** Inserting a record
    #
    # ```
    # insert.into(:users).values(name: "John", age: 30).commit
    # ```
    def values(**fields)
      build_values(fields)
      self
    end

    # Set the query to use for the insert
    # - **@param** query [Query] The query to use
    # - **@return** [Insert] The insert object
    #
    # **Example** Inserting a record with a query
    #
    # ```
    # insert.into(:users).query(select.from(:users).where(id: 1)).commit
    # ```
    def query(query : Query)
      @query = query
      self
    end

    # Set the columns to return
    # - **@param** columns [Symbol*] The columns to return
    # - **@return** [Insert] The insert object
    # - **@raise** [Exception] If the column does not exist
    #
    # **Example** Inserting a record
    #
    # ```
    # insert.into(:users).values(name: "John", age: 30).back(:id).commit
    # ```
    def back(*columns : Symbol)
      @back = columns.to_a.map { |column| Expression::Column.new(find_column(column)) }
      self
    end

    def back(columns : Array(Symbol))
      @back = columns.to_a.map { |column| Expression::Column.new(find_column(column)) }
      self
    end

    # Build the insert statement object
    # **@return** [Expression::Insert] The insert statement
    #
    # **Example** Building the insert statement
    #
    # ```
    # insert.into(:users).values(name: "John", age: 30).commit
    # ```
    def build
      Expression::Insert.new(
        Expression::Table.new(@table.not_nil!),
        @columns, @values, @back, build_query
      )
    end

    # Convert the insert object to a SQL query
    # - **@param** gen [Generator] The generator to use
    # - **@return** [{String, Array(DB::Any)}] The query and parameters
    # - **@raise** [Exception] If the table does not exist
    #
    # **Example** Generating a SQL query
    #
    # ```
    # insert.into(:users).values(name: "John", age: 30).to_sql
    # ```
    def to_sql(gen = @schema.gen)
      gen.reset
      build.accept(gen)
      {gen.query, gen.params}
    end

    private def build_query
      if query = @query
        query.build
      end
    end

    private def build_values(fields)
      keys = Set(Expression::Column).new

      fields.each do |field, _|
        column = find_column(field)
        keys << Expression::Column.new(column)
      end

      @columns = keys if @columns.empty?

      vals = fields.values.map do |v|
        if v.is_a?(JSON::Any)
          v.to_json.as(DB::Any)
        else
          v.as(DB::Any)
        end
      end
      @values << vals.to_a
    end

    private def find_table(table : Symbol) : Table
      @schema.tables[table] || raise "Table #{table} not found"
    end

    private def find_column(column : Symbol) : BaseColumn
      @table.not_nil!.columns[column] || raise "Column #{column} not found"
    end
  end
end
