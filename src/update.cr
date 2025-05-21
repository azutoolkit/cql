module CQL
  #
  # The `CQL::Update` class represents an SQL UPDATE statement.
  #
  # **Example**
  #
  # ```
  # update = CQL::Update.new(schema)
  #   .table(:users)
  #   .set(name: "John", age: 30)
  #   .where { |w| w.id == 1 }
  #   .commit
  # ```
  #
  # ## Usage
  #
  # - `initialize(schema : Schema)` - Initializes a new instance of `CQL::Update` with the given schema.
  # - `commit : DB::Result` - Executes the update query and returns the result.
  # - `to_sql(gen = @schema.gen) : {String, Array(DB::Any)}` - Generates the SQL query and parameters.
  # - `table(table : Symbol) : self` - Sets the table to update.
  # - `set(setters : Hash(Symbol, DB::Any)) : self` - Sets the column values to update using a hash.
  # - `set(**fields) : self` - Sets the column values to update using keyword arguments.
  # - `where(&block) : self` - Sets the WHERE clause using a block.
  # - `where(**fields) : self` - Sets the WHERE clause using keyword arguments.
  # - `back(*columns : Symbol) : self` - Sets the columns to return after the update.
  # - `build : Expression::Update` - Builds the `Expression::Update` object.
  class Update
    @table : Expression::Table? = nil
    @setters : Array(Expression::Setter) = [] of Expression::Setter
    @where : Expression::Where? = nil
    @back : Set(Expression::Column) = Set(Expression::Column).new
    @with_optimistic_locking : Bool = false
    @version_value : Int32? = nil
    @version_column : Symbol? = nil

    def initialize(@schema : Schema)
    end

    # Enables optimistic locking for this update.
    # - **@param** version_value [Int32] the current version value to check against
    # - **@param** version_column [Symbol] the name of the version column (default: inferred from table)
    # - **@return** [self] the current instance
    #
    # **Example** Using optimistic locking
    # ```
    # update = CQL::Update.new(schema)
    #   .table(:users)
    #   .set(name: "John", age: 30)
    #   .where(id: 1)
    #   .with_optimistic_lock(version: 5)
    #   .commit
    # ```
    def with_optimistic_lock(version : Int32, column : Symbol? = nil)
      @with_optimistic_locking = true
      @version_value = version
      @version_column = column
      self
    end

    # Executes the update query and returns the result.
    # - **@return** [DB::Result] the result of the query
    #
    # **Example**
    # ```
    # update = CQL::Update.new(schema)
    #   .table(:users)
    #   .set(name: "John", age: 30)
    #   .where { |w| w.id == 1 }
    #   .commit
    #
    # => {"UPDATE users SET name = $1, age = $2 WHERE id = $3", ["John", 30, 1]}
    # ```
    def commit
      if @with_optimistic_locking
        handle_optimistic_locking
      end

      query, params = to_sql
      result = @schema.exec_query do |conn|
        conn.exec(query, args: params)
      end

      if @with_optimistic_locking && result.rows_affected == 0
        raise CQL::OptimisticLockError.new("Record has been modified by another process")
      end

      result
    end

    # Generates the SQL query and parameters.
    # - **@param** gen [Expression::Generator] the generator to use
    # - **@return** [{String, Array(DB::Any)}] the query and parameters
    #
    # **Example**
    # ```
    # update = CQL::Update.new(schema)
    #   .table(:users)
    #   .set(name: "John", age: 30)
    #   .where { |w| w.id == 1 }
    #   .to_sql
    #
    # => {"UPDATE users SET name = $1, age = $2 WHERE id = $3", ["John", 30, 1]}
    # ```
    def to_sql(gen = @schema.gen)
      gen.reset
      build.accept(gen)
      {gen.query, gen.params}
    end

    # Sets the table to update.
    # - **@param** table [Symbol] the name of the table
    # - **@return** [self] the current instance
    # - **@raise** [Exception] if the table does not exist
    #
    # **Example**
    # ```
    # update = CQL::Update.new(schema)
    #   .table(:users)
    #   .set(name: "John", age: 30)
    #   .where { |w| w.id == 1 }
    #   .commit
    #
    # => {"UPDATE users SET name = $1, age = $2 WHERE id = $3", ["John", 30, 1]}
    # ```
    def table(table : Symbol)
      @table = Expression::Table.new(find_table(table))
      self
    end

    # Sets the column values to update using a hash.
    # - **@param** setters [Hash(Symbol, DB::Any)] the column values to update
    # - **@return** [self] the current instance
    #
    # **Example**
    # ```
    # update = CQL::Update.new(schema)
    #   .table(:users)
    #   .set(name: "John", age: 30)
    #   .where { |w| w.id == 1 }
    #   .commit
    #
    # => {"UPDATE users SET name = $1, age = $2 WHERE id = $3", ["John", 30, 1]}
    # ```
    def set(setters : Hash(Symbol, DB::Any))
      build_setters(setters)

      self
    end

    # Sets the column values to update using keyword arguments.
    # - **@param** fields [Hash(Symbol, DB::Any)] the column values to update
    # - **@return** [self] the current instance
    #
    # **Example**
    # ```
    # update = CQL::Update.new(schema)
    #   .table(:users)
    #   .set(name: "John", age: 30)
    #   .where { |w| w.id == 1 }
    #   .commit
    #
    # => {"UPDATE users SET name = $1, age = $2 WHERE id = $3", ["John", 30, 1]}
    # ```
    def set(**fields)
      build_setters(fields)

      self
    end

    # Sets the WHERE clause using a block.
    # - **@block**  w [Expression::FilterBuilder] the filter builder
    # - **@return** [self] the current instance
    # - **@raise** [Exception] if the block is not provided
    # - **@raise** [Exception] if the block does not return an expression
    #
    # **Example**
    # ```
    # update = CQL::Update.new(schema)
    #   .table(:users)
    #   .set(name: "John", age: 30)
    #   .where { |w| w.id == 1 }
    #   .commit
    #
    # => {"UPDATE users SET name = $1, age = $2 WHERE id = $3", ["John", 30, 1]}
    # ```
    def where(&)
      tbl_expr = @table.not_nil!
      tbl = tbl_expr.table
      # FilterBuilder expects Hash(String, QueryTableInfo)
      # QueryTableInfo = NamedTuple(table: Table, alias: String)
      table_name_str = tbl.table_name.to_s
      # Use table name as alias for Update context
      query_table_info = {table: tbl, alias: table_name_str}
      query_tables_hash = {table_name_str => query_table_info}

      # Pass the correctly structured hash to FilterBuilder
      builder = with Expression::FilterBuilder.new(query_tables_hash) yield
      @where = Expression::Where.new(builder.condition)
      self
    end

    # Sets the WHERE clause using keyword arguments.
    # - **@param** fields [Hash(Symbol, DB::Any)] the conditions
    # - **@return** [self] the current instance
    # - **@raise** [Exception] if the column does not exist
    # - **@raise** [Exception] if the value is invalid
    #
    # **Example**
    # ```
    # update = CQL::Update.new(schema)
    #   .table(:users)
    #   .set(name: "John", age: 30)
    #   .where(id: 1)
    #   .commit
    #
    # => {"UPDATE users SET name = $1, age = $2 WHERE id = $3", ["John", 30, 1]}
    # ```
    def where(**fields)
      condition = nil
      fields.to_h.each_with_index do |(k, v), index|
        expr = get_expression(k, v)
        condition = index == 0 ? expr : Expression::And.new(condition.not_nil!, expr)
      end

      @where = Expression::Where.new(condition.not_nil!)

      self
    end

    # Sets the columns to return after the update.
    # - **@param** columns [Array(Symbol)] the columns to return
    # - **@return** [self] the current instance
    # - **@raise** [Exception] if the column does not exist
    # - **@raise** [Exception] if the column is not part of the table
    #
    # **Example**
    #
    # ```
    # update = CQL::Update.new(schema)
    #   .table(:users)
    #   .set(name: "John", age: 30)
    #   .where { |w| w.id == 1 }
    #   .back(:name, :age)
    #   .commit
    # ```
    def where(attr : Hash(Symbol, DB::Any))
      condition = nil
      attr.each do |k, v|
        expr = get_expression(k, v)
        condition = condition ? Expression::And.new(condition.not_nil!, expr) : expr
      end

      @where = Expression::Where.new(condition.not_nil!)

      self
    end

    # Sets the columns to return after the update.
    # - **@param** columns [Array(Symbol)] the columns to return
    # - **@return** [self] the current instance
    #
    # **Example**
    # ```
    # update = CQL::Update.new(schema)
    #   .table(:users)
    #   .set(name: "John", age: 30)
    #   .where { |w| w.id == 1 }
    #   .back(:name, :age)
    #   .commit
    #
    # => {"UPDATE users SET name = $1, age = $2 WHERE id = $3 RETURNING name, age", ["John", 30, 1]}
    # ```
    #
    def back(*columns : Symbol)
      @back = columns.to_a.map { |column| Expression::Column.new(find_column(column)) }.to_set
      self
    end

    # Builds the `Expression::Update` object.
    # - **@return** [Expression::Update] the update expression
    # - **@raise** [Exception] if the table is not set
    #
    # **Example**
    # ```
    # update = CQL::Update.new(schema)
    #   .table(:users)
    #   .set(name: "John", age: 30)
    #   .where { |w| w.id == 1 }
    #   .commit
    #
    # => {"UPDATE users SET name = $1, age = $2 WHERE id = $3", ["John", 30, 1]}
    # ```
    #
    def build
      Expression::Update.new(@table.not_nil!, @setters, @where, @back)
    end

    private def build_setters(setters)
      setters.each do |k, v|
        column = find_column(k)
        val = if v.is_a?(JSON::Any)
                v.to_json.as(DB::Any)
              else
                v.as(DB::Any)
              end
        @setters << Expression::Setter.new(Expression::Column.new(column), val)
      end
    end

    private def get_expression(field, value)
      column = find_column(field)
      Expression::Compare.new(Expression::Column.new(column), "=", value)
    end

    private def find_table(name : Symbol) : Table
      @schema.tables[name] || raise "Table #{name} not found"
    end

    private def find_column(name : Symbol) : BaseColumn
      @table.not_nil!.table.columns[name] || raise "Column #{name} not found"
    end

    private def handle_optimistic_locking
      return unless @with_optimistic_locking
      return unless table = @table

      # Get the table object
      tbl = table.table

      # Determine the version column
      version_col = if col = @version_column
                      if column = tbl.columns[col]?
                        column.version_number = true unless column.version_number?
                        column
                      else
                        raise CQL::Error.new("Specified version column '#{col}' not found in table '#{tbl.table_name}'")
                      end
                    else
                      # Find the first version column or default to :version
                      version_columns = tbl.version_columns
                      if version_columns.empty?
                        if column = tbl.columns[:version]?
                          column.version_number = true
                          column
                        else
                          raise CQL::Error.new("No version column found in table '#{tbl.table_name}', specify one with with_optimistic_lock(version, column)")
                        end
                      else
                        version_columns.first
                      end
                    end

      # Make sure we have the current version value
      unless current_version = @version_value
        raise CQL::Error.new("Current version value is required for optimistic locking")
      end

      # Add version check to WHERE clause
      if @where.nil?
        @where = Expression::Where.new(
          Expression::Compare.new(Expression::Column.new(version_col), "=", current_version.as(DB::Any))
        )
      else
        existing_condition = @where.not_nil!.condition
        @where = Expression::Where.new(
          Expression::And.new(
            existing_condition,
            Expression::Compare.new(Expression::Column.new(version_col), "=", current_version.as(DB::Any))
          )
        )
      end

      # Increment the version in the setters
      @setters << Expression::Setter.new(Expression::Column.new(version_col), (current_version + 1).as(DB::Any))
    end
  end
end
