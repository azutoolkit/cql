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
  # AcmeDB.insert
  #   .into(:users)
  #   .values(name: "John", email: "john@example.com", age: 30)
  #   .last_insert_id
  # ```
  #
  # **Example** Inserting multiple records
  #
  # ```
  # AcmeDB.insert
  #   .into(:users)
  #   .values(name: "John", email: "john@example.com")
  #   .values(name: "Jane", email: "jane@example.com")
  #   .commit
  # ```
  #
  # **Example** Inserting the rows a query selects
  #
  # ```
  # active = AcmeDB.query.from(:users).select(:name, :email).where(active: true)
  # AcmeDB.insert.into(:users).query(active).commit
  # ```
  class Insert
    include Pinnable

    @table : Table? = nil
    @columns : Set(Expression::Column) = Set(Expression::Column).new
    @values : Array(Array(DB::Any)) = Array(Array(DB::Any)).new
    # Column names (in order) established by the first row; later rows are
    # aligned to this order and must provide exactly the same columns.
    @column_index : Hash(Symbol, Int32) = {} of Symbol => Int32
    @column_names : Array(Symbol) = [] of Symbol
    @back : Array(Expression::Column) = Array(Expression::Column).new
    @query : Query? = nil
    # Upsert: the conflict target, then what to do about it (nil = not chosen yet).
    @conflict_target : Array(Expression::Column) = [] of Expression::Column
    @refreshed : Array(Expression::Column)? = nil
    @refresh_all = false
    @overrides : Array(Expression::Setter) = [] of Expression::Setter

    getter schema : Schema

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
    # AcmeDB.insert.into(:users).values(name: "John", email: "john@example.com").last_insert_id
    # ```
    def last_insert_id(as type : PrimaryKeyType = Int64)
      return commit.last_insert_id unless adapter.dialect.supports_returning?
      back(primary_key.name).get!(type)
    end

    # Inserts and reads the row returned by the RETURNING clause (`back`) as *kind*, nil when
    # nothing was inserted (`on_conflict(...).do_nothing`). PostgreSQL and CockroachDB only.
    # - **@raise** [CQL::DialectError] Before inserting, when the dialect does not `supports_returning?`
    # - **@raise** [ArgumentError] Before inserting, when no `back` columns are set
    #
    # ```
    # AcmeDB.insert.into(:users).values(name: "John", email: "john@example.com").back(:id, :name).get({Int64, String})
    # ```
    def get(as kind)
      require_returning!
      query, params = to_sql
      CQL::Execution.run(executor, query, params, :insert) { |connection| connection.query_one?(query, args: params, as: kind) }
    end

    def get!(as kind)
      result = get(kind)
      raise DB::NoResultsError.new("The insert returned no row") if result.nil?
      result
    end

    private def require_returning! : Nil
      raise ArgumentError.new("Insert#get needs the columns to return; call `back` first") if @back.empty?
      return if adapter.dialect.supports_returning?
      raise CQL::DialectError.new(adapter.to_s, "INSERT ... RETURNING", "Insert with `commit` and read the row back with a SELECT.")
    end

    # The insert with `RETURNING` the table's declared primary key (`id` when none is declared),
    # as `{sql, params}`. PostgreSQL and CockroachDB fetch the new key this way.
    def returning_primary_key_sql
      own_back = @back
      @back = [Expression::Column.new(primary_key)]
      begin
        to_sql
      ensure
        @back = own_back
      end
    end

    private def primary_key : BaseColumn
      @table.try(&.primary_key) || find_column(:id)
    end

    private def adapter
      @schema.adapter
    end

    # Executes the insert statement and returns the result
    # The query execution is automatically tracked by CQL::Performance when enabled.
    # - **@return** [DB::ExecResult] The rows affected and the last inserted ID
    #
    # **Example** Inserting a record
    #
    # ```
    # result = AcmeDB.insert
    #   .into(:users)
    #   .values(name: "John", email: "john@example.com")
    #   .commit
    # result.rows_affected
    # ```
    def commit
      query, params = to_sql

      CQL::Execution.run(executor, query, params, :insert) { |connection| connection.exec(query, args: params) }
    end

    # Set the table to insert into
    # - **@param** table [Symbol] The table to insert into
    # - **@return** [Insert] The insert object
    # - **@raise** [ArgumentError] If the table does not exist
    #
    # **Example** Inserting a record
    #
    # ```
    # AcmeDB.insert.into(:users)
    # ```
    def into(table : Symbol)
      @table = find_table(table)
      self
    end

    # Set the rows to insert, one hash per row; every row must name the same columns
    # - **@param** values [Array(Hash(Symbol, DB::Any))] The rows to insert
    # - **@return** [Insert] The insert object
    #
    # **Example** Inserting several records
    #
    # ```
    # rows = [
    #   {:name => "John", :email => "john@example.com"} of Symbol => DB::Any,
    #   {:name => "Jane", :email => "jane@example.com"} of Symbol => DB::Any,
    # ]
    # AcmeDB.insert.into(:users).values(rows).commit
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
    # row = {:name => "John", :email => "john@example.com"} of Symbol => DB::Any
    # AcmeDB.insert.into(:users).values(row).commit
    # ```
    def values(hash : Hash(Symbol, DB::Any))
      build_values(hash)
      self
    end

    # Set the values to insert
    # - **@param** fields [NamedTuple] The values to insert, keyed by column
    # - **@return** [Insert] The insert object
    #
    # **Example** Inserting a record
    #
    # ```
    # AcmeDB.insert.into(:users).values(name: "John", email: "john@example.com").commit
    # ```
    def values(**fields)
      build_values(fields)
      self
    end

    # Set the query whose rows are inserted (`INSERT INTO ... SELECT ...`); its selected
    # columns name the inserted columns
    # - **@param** query [Query] The query to use
    # - **@return** [Insert] The insert object
    #
    # **Example** Inserting the rows a query selects
    #
    # ```
    # source = AcmeDB.query.from(:users).select(:name, :email).where { users.id == 1 }
    # AcmeDB.insert.into(:users).query(source).to_sql
    # # => {"INSERT INTO users (name, email) SELECT users.name, users.email FROM users WHERE users.id = ?", [1]}
    # ```
    def query(query : Query)
      @query = query
      self
    end

    # Set the columns to return (`RETURNING`), read with `get`; for dialects that `supports_returning?`
    # - **@param** columns [Symbol*] The columns to return
    # - **@return** [Insert] The insert object
    # - **@raise** [Exception] If the column does not exist
    #
    # **Example** Inserting a record
    #
    # ```
    # AcmeDB.insert.into(:users).values(name: "John", email: "john@example.com").back(:id)
    #   .to_sql(Expression::Generator.new(CQL::Adapter::Postgres))
    # # => {"INSERT INTO users (name, email) VALUES ($1, $2) RETURNING users.id", ["John", "john@example.com"]}
    # ```
    def back(*columns : Symbol)
      @back = columns.to_a.map { |column| Expression::Column.new(find_column(column)) }
      self
    end

    def back(columns : Array(Symbol))
      @back = columns.to_a.map { |column| Expression::Column.new(find_column(column)) }
      self
    end

    # Starts an upsert: what to do when a row with the same *columns* already
    # exists. Follow with `do_nothing` or `do_update`.
    #
    # ```
    # AcmeDB.insert.into(:users).values(email: "john@example.com", name: "John").on_conflict(:email).do_update(:name)
    # ```
    def on_conflict(*columns : Symbol) : self
      conflict_target(columns)
    end

    def do_nothing : self
      require_conflict_target!("do_nothing")
      @refreshed = [] of Expression::Column
      @refresh_all = false
      @overrides.clear
      self
    end

    # Updates the existing row: *refresh* columns take the incoming value (all
    # non-target columns when none are given), *set* columns take explicit values.
    def do_update(*refresh, **set) : self
      update_columns(refresh, set)
    end

    # Inserts many rows, updating *update* columns (default: every other column; an
    # empty list means do nothing) of rows that already exist for *conflict*.
    # `Model.upsert_all` passes its own default, which also keeps `id` and `created_at`.
    def upsert(rows : Array(Hash(Symbol, DB::Any)), conflict : Array(Symbol), update : Array(Symbol)? = nil) : self
      values(rows)
      conflict_target(conflict)
      return do_nothing if update && update.empty?
      update_columns(update || [] of Symbol, NamedTuple.new)
    end

    # Build the insert statement object
    # **@return** [Expression::Insert] The insert statement
    #
    # **Example** Building the insert statement
    #
    # ```
    # AcmeDB.insert.into(:users).values(name: "John", email: "john@example.com").build
    # ```
    def build
      Expression::Insert.new(
        Expression::Table.new(@table.not_nil!),
        @columns, @values, @back, build_query, build_conflict
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
    # AcmeDB.insert.into(:users).values(name: "John", email: "john@example.com").to_sql
    # # => {"INSERT INTO users (name, email) VALUES (?, ?)", ["John", "john@example.com"]}
    # ```
    def to_sql(gen : Expression::Generator? = nil)
      generator = gen || @schema.new_generator
      generator.reset
      build.accept(generator)
      {generator.query, generator.params}
    end

    private def conflict_target(columns) : self
      raise ArgumentError.new("on_conflict needs at least one column") if columns.empty?
      @conflict_target = column_expressions(columns)
      @refreshed = nil
      @refresh_all = false
      @overrides.clear
      self
    end

    private def update_columns(refresh, set) : self
      require_conflict_target!("do_update")
      @refreshed = column_expressions(refresh)
      @refresh_all = refresh.empty? && set.empty?
      @overrides.clear
      set.each { |column, value| @overrides << Expression::Setter.new(Expression::Column.new(find_column(column)), value.as(DB::Any)) }
      self
    end

    private def column_expressions(names) : Array(Expression::Column)
      columns = [] of Expression::Column
      names.each { |name| columns << Expression::Column.new(find_column(name)) }
      columns
    end

    private def require_conflict_target!(action : String) : Nil
      raise ArgumentError.new("Call on_conflict(...) before #{action}") if @conflict_target.empty?
    end

    private def build_conflict : Expression::OnConflict?
      return if @conflict_target.empty?
      refreshed = @refreshed || raise ArgumentError.new("on_conflict needs do_nothing or do_update")
      if @refresh_all
        refreshed = refresh_all_columns
        raise ArgumentError.new("do_update has no columns to update") if refreshed.empty?
      end

      Expression::OnConflict.new(@conflict_target.map(&.as(Expression::BaseColumn)), refreshed.map(&.as(Expression::BaseColumn)), @overrides.dup)
    end

    # Every inserted column that is not part of the conflict target.
    private def refresh_all_columns : Array(Expression::Column)
      target_names = @conflict_target.map(&.column.name)
      @columns.reject { |column| target_names.includes?(column.column.name) }.to_a
    end

    private def build_query
      if query = @query
        query.build
      end
    end

    private def build_values(fields)
      @column_index.empty? ? add_first_row(fields) : add_row(fields)
    end

    # The first row fixes the columns. Every column is resolved before touching state, so a bad
    # column leaves the insert unchanged.
    private def add_first_row(fields)
      columns = [] of Expression::Column
      row = [] of DB::Any
      fields.each do |field, value|
        columns << Expression::Column.new(find_column(field))
        row << db_value(value)
      end
      columns.each_with_index do |column, index|
        @columns << column
        @column_index[column.column.name] = index
        @column_names << column.column.name
      end
      @values << row
    end

    # Later rows must name the same columns, in any order; values are placed by column position
    # (a row that lists them in the first row's order needs no index lookup).
    private def add_row(fields)
      row = Array(DB::Any).new(@column_index.size, nil)
      count = 0
      fields.each do |field, value|
        row[column_position(field, count, fields)] = db_value(value)
        count += 1
      end
      raise_column_mismatch(fields) unless count == @column_index.size
      @values << row
    end

    private def column_position(field : Symbol, count : Int32, fields) : Int32
      return count if @column_names[count]? == field
      @column_index[field]? || raise_column_mismatch(fields)
    end

    private def db_value(value) : DB::Any
      value.is_a?(JSON::Any) ? value.to_json.as(DB::Any) : value.as(DB::Any)
    end

    private def raise_column_mismatch(fields) : NoReturn
      raise ArgumentError.new(
        "All rows in a bulk insert must have the same columns: expected #{@column_index.keys.join(", ")}, got #{fields.keys.join(", ")}")
    end

    private def find_table(table : Symbol) : Table
      @schema.tables[table]? || raise ArgumentError.new("Table #{table} not found")
    end

    private def find_column(column : Symbol) : BaseColumn
      table = @table.not_nil!
      table.columns[column]? || raise ArgumentError.new("Column #{column} not found in #{table.table_name}")
    end
  end
end
