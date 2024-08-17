module Cql
  #
  # The `Cql::Update` class represents an SQL UPDATE statement.
  #
  # **Example**
  #
  # ```
  # update = Cql::Update.new(schema)
  #   .table(:users)
  #   .set(name: "John", age: 30)
  #   .where { |w| w.id == 1 }
  #   .commit
  # ```
  #
  # ## Usage
  #
  # - `initialize(schema : Schema)` - Initializes a new instance of `Cql::Update` with the given schema.
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

    def initialize(@schema : Schema)
    end

    # Executes the update query and returns the result.
    # - **@return** [DB::Result] the result of the query
    #
    # **Example**
    # ```
    # update = Cql::Update.new(schema)
    #   .table(:users)
    #   .set(name: "John", age: 30)
    #   .where { |w| w.id == 1 }
    #   .commit
    #
    # => {"UPDATE users SET name = $1, age = $2 WHERE id = $3", ["John", 30, 1]}
    # ```
    def commit
      query, params = to_sql
      @schema.db.exec query, args: params
    end

    # Generates the SQL query and parameters.
    # - **@param** gen [Expression::Generator] the generator to use
    # - **@return** [{String, Array(DB::Any)}] the query and parameters
    #
    # **Example**
    # ```
    # update = Cql::Update.new(schema)
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
    # update = Cql::Update.new(schema)
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
    # update = Cql::Update.new(schema)
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
    # update = Cql::Update.new(schema)
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
    # update = Cql::Update.new(schema)
    #   .table(:users)
    #   .set(name: "John", age: 30)
    #   .where { |w| w.id == 1 }
    #   .commit
    #
    # => {"UPDATE users SET name = $1, age = $2 WHERE id = $3", ["John", 30, 1]}
    # ```
    def where(&)
      tbl = @table.not_nil!.table
      where_hash = {tbl.table_name => tbl}
      builder = with Expression::FilterBuilder.new(where_hash) yield
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
    # update = Cql::Update.new(schema)
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
    # update = Cql::Update.new(schema)
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
    # update = Cql::Update.new(schema)
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
    # update = Cql::Update.new(schema)
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
        column.validate!(v)
        @setters << Expression::Setter.new(Expression::Column.new(column), v)
      end
    end

    private def get_expression(field, value)
      column = find_column(field)
      column.validate!(value)
      Expression::Compare.new(Expression::Column.new(column), "=", value)
    end

    private def find_table(name : Symbol) : Table
      @schema.tables[name] || raise "Table #{name} not found"
    end

    private def find_column(name : Symbol) : BaseColumn
      @table.not_nil!.table.columns[name] || raise "Column #{name} not found"
    end
  end
end
