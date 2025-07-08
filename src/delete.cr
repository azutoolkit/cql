require "./expression/expressions"
require "./performance"

module CQL
  # A delete query
  # This class represents a delete query
  # It provides methods for building a delete query
  # It also provides methods for executing the query
  #
  # All delete operations are automatically tracked by CQL::Performance when enabled.
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
    # delete = CQL::Delete.new(schema)
    #   .from(:users)
    #   .where(id: 1)
    #   .commit
    # ```
    def initialize(@schema : Schema)
    end

    # Executes the delete query and returns the result
    # The query execution is automatically tracked by CQL::Performance when enabled.
    # - **@return** [DB::Result] The result of the query
    #
    # **Example** Deleting a record
    #
    # ```
    # delete = CQL::Delete.new(schema)
    #   .from(:users)
    #   .where(id: 1)
    #   .commit
    # ```
    def commit
      query, params = to_sql
      CQL::Performance.track(query, params) do
        @schema.exec_query do |conn|
          conn.exec(query, args: params)
        end
      end
    end

    # Generates the SQL query and parameters
    # - **@param** gen [Expression::Generator] The generator to use
    # - **@return** [{String, Array(DB::Any)}] The query and parameters
    #
    # **Example** Generating a delete query
    #
    # ```
    # delete = CQL::Delete.new(schema)
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
    # delete = CQL::Delete.new(schema)
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
    # delete = CQL::Delete.new(schema)
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
    # delete = CQL::Delete.new(schema)
    #   .from(:users)
    #   .where { users.name == 'John' }
    #   .back(:name, :age)
    # ```
    def where(&)
      # Construct the QueryTableInfo hash expected by FilterBuilder
      query_tables_hash = Hash(String, Query::QueryTableInfo).new

      # Add the main table
      main_tbl_expr = @table.not_nil!
      main_tbl = main_tbl_expr.table
      main_tbl_name_str = main_tbl.table_name.to_s
      query_tables_hash[main_tbl_name_str] = {table: main_tbl, alias: main_tbl_name_str}

      # Add the USING table if present
      if using_expr = @using
        using_tbl = using_expr.table
        using_tbl_name_str = using_tbl.table_name.to_s
        # Avoid overwriting if alias is same as main table name (unlikely but possible)
        if query_tables_hash.has_key?(using_tbl_name_str)
          # Handle potential alias clash if necessary, though default naming prevents this.
          # For now, assume distinct table names or raise error.
          raise "Alias conflict: USING table name '#{using_tbl_name_str}' is the same as the FROM table name." if using_tbl_name_str == main_tbl_name_str
          # If alias is different, it's fine.
        else
          query_tables_hash[using_tbl_name_str] = {table: using_tbl, alias: using_tbl_name_str}
        end
      end

      builder = with Expression::FilterBuilder.new(query_tables_hash) yield
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
    # delete = CQL::Delete.new(schema)
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

    # Where clause using a hash of conditions to match against
    # - **@param** attr [Hash(Symbol, DB::Any)] The conditions to match against
    # - **@return** [self] The current instance
    #
    # **Example** Setting the where clause
    #
    # ```
    # delete = CQL::Delete.new(schema)
    #   .from(:users)
    #   .where(id: 1)
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

    # Sets the columns to return after the delete
    # - **@param** columns [Symbol*] The columns to return
    # - **@return** [self] The current instance
    # - **@raise** [Exception] If the column does not exist
    #
    # **Example** Setting the columns to return
    # ```
    # delete = CQL::Delete.new(schema)
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
    # delete = CQL::Delete.new(schema)
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
      # Handle array values for IN conditions
      if value.is_a?(Array)
        Expression::InCondition.new(Expression::Column.new(column), value)
      else
        Expression::Compare.new(Expression::Column.new(column), "=", value)
      end
    end

    private def find_table(name : Symbol) : Table
      @schema.tables[name] || raise "Table #{name} not found"
    end

    private def find_column(name : Symbol) : BaseColumn
      @table.not_nil!.table.columns[name] || raise "Column #{name} not found"
    end
  end
end
