module Cql
  # A delete query
  # This class represents a delete query
  # It provides methods for building a delete query
  # It also provides methods for executing the query
  #
  # **Example** Deleting a record
  #
  # ```
  # delete.from(:users).where(id: 1).commit
  # ```
  class Delete
    @table : Expression::Table? = nil
    @where : Expression::Where? = nil
    @back : Set(Expression::Column) = Set(Expression::Column).new
    @using : Expression::Table? = nil

    # Initialize the delete query
    # - **@param** schema [Schema] The schema to use
    # - **@return** [Delete] The delete query object
    #
    # **Example** Deleting a record
    #
    # ```
    # delete = Cql::Delete.new(schema)
    #   .from(:users)
    #   .where(id: 1)
    #   .commit
    # ```
    def initialize(@schema : Schema)
    end

    # Executes the delete query and returns the result
    # - **@return** [DB::Result] The result of the query
    #
    # **Example** Deleting a record
    #
    # ```
    # delete = Cql::Delete.new(schema)
    #   .from(:users)
    #   .where(id: 1)
    #   .commit
    # ```
    def commit
      query, params = to_sql
      @schema.db.exec query, args: params
    end

    # Generates the SQL query and parameters
    # - **@param** gen [Expression::Generator] The generator to use
    # - **@return** [{String, Array(DB::Any)}] The query and parameters
    #
    # **Example** Generating a delete query
    #
    # ```
    # delete = Cql::Delete.new(schema)
    #   .from(:users)
    #   .where(id: 1)
    #   .to_sql
    # ```
    def to_sql(gen = @schema.gen)
      gen.reset
      build.accept(gen)
      {gen.query, gen.params}
    end

    # Sets the table to delete from
    # - **@param** table [Symbol] The name of the table
    # - **@return** [self] The current instance
    # - **@raise** [Exception] If the table does not exist
    #
    # **Example** Setting the table
    #
    # ```
    # delete = Cql::Delete.new(schema)
    #   .from(:users)
    # ```
    def from(table : Symbol)
      @table = Expression::Table.new(find_table(table))
      self
    end

    # Sets the table to use in the using clause
    # - **@param** table [Symbol] The name of the table
    # - **@return** [self] The current instance
    # - **@raise** [Exception] If the table does not exist
    #
    # **Example** Setting the using table
    # ```
    # delete = Cql::Delete.new(schema)
    #   .from(:users)
    #   .using(:posts)
    # ```
    #
    def using(table : Symbol)
      @using = Expression::Table.new(find_table(table))
      self
    end

    # Sets the columns to return
    # - **@param** columns [Symbol*] The columns to return
    # - **@return** [self] The current instance
    # - **@raise** [Exception] If the column does not exist
    #
    # **Example** Setting the columns to return
    #
    # ```
    # delete = Cql::Delete.new(schema)
    #   .from(:users)
    #   .back(:name, :age)
    # ```
    def where(&)
      builder = with Expression::FilterBuilder.new(where_hash) yield
      @where = Expression::Where.new(builder.condition)
      self
    end

    # Sets the columns to return
    # - **@param** columns [Symbol*] The columns to return
    # - **@return** [self] The current instance
    # - **@raise** [Exception] If the column does not exist
    #
    # **Example** Setting the columns to return
    #
    # ```
    # delete = Cql::Delete.new(schema)
    #   .from(:users)
    #   .back(:name, :age)
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

    # Sets the columns to return after the delete
    # - **@param** columns [Symbol*] The columns to return
    # - **@return** [self] The current instance
    # - **@raise** [Exception] If the column does not exist
    #
    # **Example** Setting the columns to return
    # ```
    # delete = Cql::Delete.new(schema)
    #   .from(:users)
    #   .back(:name, :age)
    # ```
    def back(*columns : Symbol)
      @back = columns.to_a.map { |column| Expression::Column.new(find_column(column)) }.to_set
      self
    end

    # Builds the delete expression
    # - **@return** [Expression::Delete] The delete expression
    # - **@raise** [Exception] If the table is not set
    # - **@raise** [Exception] If the where clause is not set
    #
    # **Example** Building the delete expression
    # ```
    # delete = Cql::Delete.new(schema)
    #   .from(:users)
    #   .where(id: 1)
    #   .commit
    # ```
    def build
      Expression::Delete.new(@table.not_nil!, @where, @back, @using)
    end

    private def where_hash
      where_hash = Hash(Symbol, Table).new
      tbl = @table.not_nil!.table
      where_hash[tbl.table_name] = tbl

      if using = @using
        using_tbl = using.table
        where_hash[using_tbl.table_name] = using_tbl
      end

      where_hash
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
