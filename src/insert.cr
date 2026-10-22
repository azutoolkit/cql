require "./table"  # Assuming table.cr defines Table
require "./schema" # Assuming schema.cr defines Schema
require "./performance"

module CQL
  # An insert statement builder class
  # This class provides methods for building an insert statement
  # It also provides methods for executing the statement
  #
  # All insert operations are automatically tracked by CQL::Performance when enabled.
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
    # Column names (in order) established by the first row; later rows are
    # aligned to this order and must provide exactly the same columns.
    @column_order : Array(Symbol) = [] of Symbol
    @back : Array(Expression::Column) = Array(Expression::Column).new
    @query : Query? = nil

    def initialize(@schema : Schema)
    end

    # Inserts and gets the last inserted ID from the database
    # Works with SQLite, PostgreSQL and MySQL.
    # The query execution is automatically tracked by CQL::Performance when enabled.
    # - **@return** [Int64] The last inserted ID
    #
    # **Example** Getting the last inserted ID
    #
    # ```
    # insert.into(:users).values(name: "John", age: 30).last_insert_id
    # ```
    def last_insert_id(as type : PrimaryKeyType = Int64)
      if adapter.postgres?
        # Reset to ensure nothing else but the :id is returned
        @back = Array(Expression::Column).new
        query, params = back(:id).to_sql
        CQL::Performance.track(query, params) do
          @schema.exec_query do |conn|
            conn.query_one(query, args: params, as: type)
          end
        end
      else
        self.commit.last_insert_id
      end
    end

    private def adapter
      @schema.adapter
    end

    # Executes the insert statement and returns the result
    # The query execution is automatically tracked by CQL::Performance when enabled.
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

      CQL::Performance.track(query, params) do
        @schema.exec_query do |conn|
          conn.exec(query, args: params)
        end
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
    def to_sql(gen : Expression::Generator? = nil)
      generator = gen || @schema.new_generator
      generator.reset
      build.accept(generator)
      {generator.query, generator.params}
    end

    private def build_query
      if query = @query
        query.build
      end
    end

    private def build_values(fields)
      pairs = [] of {Symbol, DB::Any}
      fields.each do |field, value|
        pairs << {field, value.is_a?(JSON::Any) ? value.to_json.as(DB::Any) : value.as(DB::Any)}
      end

      if @column_order.empty?
        pairs.each { |(field, _)| @columns << Expression::Column.new(find_column(field)) }
        @column_order = pairs.map(&.[0])
      else
        names = pairs.map(&.[0])
        unless names.size == @column_order.size && (names - @column_order).empty?
          raise ArgumentError.new(
            "All rows in a bulk insert must have the same columns: expected #{@column_order.join(", ")}, got #{names.join(", ")}")
        end
        pairs = @column_order.map { |name| pairs.find! { |(field, _)| field == name } }
      end

      @values << pairs.map(&.[1])
    end

    private def find_table(table : Symbol) : Table
      @schema.tables[table] || raise "Table #{table} not found"
    end

    private def find_column(column : Symbol) : BaseColumn
      @table.not_nil!.columns[column] || raise "Column #{column} not found"
    end
  end
end
