module Cql
  # The `Query` class is responsible for building SQL queries in a structured manner.
  # It holds various components like selected columns, tables, conditions, and more.
  # It provides methods to execute the query and return results.
  #
  # **Example** Creating a new query
  #
  # ```
  # schema = Cql::Schema.new
  #
  # Cql::Query.new(schema)
  # query.select(:name, :age).from(:users).where(name: "John").all(User)
  # => [{"name" => "John", "age" => 30}]
  # ```
  #
  # **Example** Executing a query and iterating over results
  #
  # ```
  # schema = Cql::Schema.new
  # query = Cql::Query.new(schema)
  # query.select(:name, :age).from(:users).where(name: "John").each(User) do |user|
  #   puts user.name
  # end
  #
  # => John
  # ```
  class Query
    getter columns : Array(BaseColumn) = [] of BaseColumn
    getter tables : Hash(Symbol, Table) = {} of Symbol => Table
    getter where : Expression::Where? = nil
    getter group_by : Array(BaseColumn) = [] of BaseColumn
    getter having : Expression::Having? = nil
    getter order_by : Hash(Expression::Column, Expression::OrderDirection) = {} of Expression::Column => Expression::OrderDirection
    getter joins : Array(Expression::Join) = [] of Expression::Join
    getter limit : Int32? = nil
    getter offset : Int32? = nil
    getter? distinct : Bool = false
    getter aggr_columns : Array(Expression::Aggregate) = [] of Expression::Aggregate

    # Initializes the `Query` object with the provided schema.
    # - **@param** schema [Schema] The schema object to use for the query
    # - **@return** [Query] The query object
    #
    # **Example** Creating a new query
    # ```
    # schema = Cql::Schema.new
    # query = Cql::Query.new(schema)
    #
    # => #<Cql::Query:0x00007f8b1b0b3b00>
    # ```
    def initialize(@schema : Schema)
    end

    # Executes the query and returns all records.
    # - **@param** as [Type] The type to cast the results to
    # - **@return** [Array(Type)] The results of the query
    #
    # **Example**
    #
    # ```
    # schema = Cql::Schema.new
    # query = Cql::Query.new(schema)
    # query.select(:name, :age).from(:users).all(User)
    #
    # => [<User:0x00007f8b1b0b3b00 @name="John", @age=30>, <User:0x00007f8b1b0b3b00 @name="Jane", @age=25>]
    # ```
    def all(as as_kind)
      query, params = to_sql
      as_kind.from_rs @schema.db.query(query, args: params)
    end

    # - **@param** as [Type] The type to cast the results to
    # - **@return** [Array(Type)] The results of the query
    #
    # **Example**
    #
    # ```
    # schema = Cql::Schema.new
    # query = Cql::Query.new(schema)
    # query.select(:name, :age).from(:users).all!(User)
    #
    # => [<User:0x00007f8b1b0b3b00 @name="John", @age=30>, <User:0x00007f8b1b0b3b00 @name="Jane", @age=25>]
    # ```
    def all!(as as_kind)
      all(as_kind).not_nil!
    end

    # Executes the query and returns the first record.
    # - **@param** as [Type] The type to cast the result to
    # - **@return** [Type] The first result of the query
    #
    # **Example**
    #
    # ```
    # schema = Cql::Schema.new
    # query = Cql::Query.new(schema)
    # query.select(:name, :age).from(:users).first(User)
    #
    # => <User:0x00007f8b1b0b3b00 @name="John", @age=30>
    # ```
    def first(as as_kind)
      query, params = to_sql
      Log.debug { "Query: #{query}, Params: #{params}" }
      @schema.db.query_one(query, args: params, as: as_kind)
    end

    # - **@param** as [Type] The type to cast the result to
    # - **@return** [Type] The first result of the query
    #
    # **Example**
    #
    # ```
    # schema = Cql::Schema.new
    # query = Cql::Query.new(schema)
    # query.select(:name, :age).from(:users).first!(User)
    #
    # => <User:0x00007f8b1b0b3b00 @name="John", @age=30>
    # ```
    def first!(as as_kind)
      first(as_kind).not_nil!
    end

    # Executes the query and returns a scalar value.
    # - **@param** as [Type] The type to cast the result to
    # - **@return** [Type] The scalar result of the query
    # Example: `query.get(Int64)`
    # ```
    # schema = Cql::Schema.new
    # query = Cql::Query.new(schema)
    # query.select(:count).from(:users).get(Int64)
    #
    # => 10
    # ```
    def get(as as_kind)
      query, params = to_sql
      @schema.db.scalar(query, args: params, as: as_kind)
    end

    # Iterates over each result and yields it to the provided block.
    # Example:
    # ```
    # query.each(User) do |user|
    #   puts user.name
    # end
    #
    # => John
    # ```
    def each(as as_kind, &)
      query, params = to_sql
      @schema.db.query_each(query, args: params) do |result|
        yield as_kind.from_rs(result)
      end
    end

    # Adds a COUNT aggregate function to the query.
    # - **@param** column [Symbol] The column to count
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # query.count(:id)
    # => "SELECT COUNT(id) FROM users"
    # ```
    def count(column : Symbol = :*)
      @aggr_columns << if column == :*
        col = Column(Int64).new(column, type: Int64)
        col.table = tables.first.last.not_nil!
        Expression::Count.new(Expression::Column.new(col))
      else
        Expression::Count.new(Expression::Column.new(find_column(column)))
      end
      self
    end

    # Adds a MAX aggregate function to the query.
    # - **@param** column [Symbol] The column to find the maximum value of
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # query.from(:users).max(:price)
    # => "SELECT MAX(price) FROM users"
    # ```
    def max(column : Symbol)
      @aggr_columns << Expression::Max.new(Expression::Column.new(find_column(column)))
      self
    end

    # Adds a MIN aggregate function to the query.
    # - **@param** column [Symbol] The column to find the minimum value of
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # query.min(:price)
    # => "SELECT MIN(price) FROM users"
    # ```
    def min(column : Symbol)
      @aggr_columns << Expression::Min.new(Expression::Column.new(find_column(column)))
      self
    end

    # Adds a SUM aggregate function to the query.
    # - **@param** column [Symbol] The column to sum
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # query.sum(:total_amount)
    # => "SELECT SUM(total_amount) FROM users"
    # ```
    def sum(column : Symbol)
      @aggr_columns << Expression::Sum.new(Expression::Column.new(find_column(column)))
      self
    end

    # Adds an AVG aggregate function to the query.
    # - **@param** column [Symbol] The column to average
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # query.avg(:rating)
    # => "SELECT AVG(rating) FROM users"
    # ```
    def avg(column : Symbol)
      @aggr_columns << Expression::Avg.new(Expression::Column.new(find_column(column)))
      self
    end

    # Converts the query into an SQL string and its corresponding parameters.
    # - **@param** gen [Generator] The generator to use for converting the query
    # - **@return** [Tuple(String, Array(DB::Any))] The SQL query and its parameters
    #
    # **Example**
    #
    # ```
    # query.to_sql
    # => {"SELECT * FROM users WHERE name = ? AND age = ?", ["John", 30]}
    # ```
    def to_sql(gen = @schema.gen)
      gen.reset
      build.accept(gen)
      {gen.query, gen.params}
    end

    # Specifies the columns to select.
    # - **@param** columns [Array(Symbol)] The columns to select
    # - **@return** [Query] The query object
    #
    #
    # **Example**
    # ```
    # query.from(:users, :address).select(users: [:name, :age], address: [:city, :state])
    # => "SELECT users.name, users.age, address.city, address.state FROM users, address"
    # ```
    def select(**fields)
      fields.each do |key, value|
        if [:count, :sum, :avg, :min, :max].includes?(key) && value.is_a?(Symbol)
          @aggr_columns << build_aggr_expression(key, value)
        else
          if value.is_a?(Array(Symbol))
            value.map { |name| @columns << find_column(name, key) }
          else
            @columns << find_column(value)
          end
        end
      end
      self
    end

    def select(*cols, **columns)
      self.select(*cols)
      self.select(**columns)
      self
    end

    # Specifies the columns to select.
    # - **@param** columns [Symbol*] The columns to select
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # query.select(:name, :age)
    # => "SELECT name, age FROM users"
    # ```
    def select(*columns : Symbol)
      @columns = columns.map { |column| find_column(column) }.to_a
      self
    end

    # Specifies the tables to select from.
    # - **@param** tbls [Symbol*] The tables to select from
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # query.from(:users, :orders)
    # => "SELECT * FROM users, orders"
    # ```
    def from(*tbls : Symbol)
      tbls.each { |tbl| @tables[tbl] = find_table(tbl) }
      self
    end

    # Adds a WHERE condition with a hash of column-value pairs.
    # - **@param** hash [Hash(Symbol, DB::Any)] The hash of column-value pairs
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # query.from(:users).where(name: "John", age: 30)
    # => "SELECT * FROM users WHERE name = 'John' AND age = 30"
    # ```
    def where(hash : Hash(Symbol, DB::Any))
      condition = nil
      hash.each_with_index do |(k, v), index|
        expr = get_expression(k, v)
        condition = index == 0 ? expr : Expression::And.new(condition.not_nil!, expr)
      end
      @where = Expression::Where.new(condition.not_nil!)

      self
    end

    # Adds a WHERE condition with a block.
    # - **@fields** [FilterBuilder] The block to build the conditions
    # - **@return** [Query] The query object
    # - **@raise** [Exception] if the column does not exist
    # - **@raise** [Exception] if the value is invalid
    # - **@raise** [Exception] if the value is not of the correct type
    #
    # **Example**
    #
    # ```
    # query.from(:users).where(name: "John")
    # => "SELECT * FROM users WHERE name = 'John'"
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

    # Adds WHERE conditions using a block.
    # - **@yield** [FilterBuilder] The block to build the conditions
    # - **@return** [Query] The query object
    # - **@raise** [Exception] if the block is not provided
    # - **@raise** [Exception] if the block does not return an expression
    # - **@raise** [Exception] if the column does not exist
    #
    # **Example**
    #
    # ```
    # query.from(:users).where { |w| w.name == "John" }
    # => "SELECT * FROM users WHERE name = 'John'"
    # ```
    def where(&)
      all_tables = @tables.dup

      @joins.each do |j|
        all_tables[j.table.table.table_name] = j.table.table
      end

      builder = with Expression::FilterBuilder.new(all_tables) yield
      @where = Expression::Where.new(builder.as(Expression::ConditionBuilder).condition)
      self
    end

    # Adds an INNER JOIN to the query.
    # - **@param** table [Symbol] The table to join
    # - **@param** on [Hash(Cql::BaseColumn, Cql::BaseColumn | DB::Any)] The join condition
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # query.inner(:orders, on: { users.id => orders.user_id })
    # => "SELECT * FROM users INNER JOIN orders ON users.id = orders.user_id"
    # ```
    def inner(table : Symbol, on : Hash(Cql::BaseColumn, Cql::BaseColumn | DB::Any))
      join(Expression::JoinType::INNER, find_table(table), on)
      self
    end

    # Adds an INNER JOIN to the query.
    # - **@param** table [Symbol] The table to join
    # - **@yield** [FilterBuilder] The block to build the conditions
    # - **@return** [Query] The query object
    # - **@raise** [Exception] if the block is not provided
    # - **@raise** [Exception] if the block does not return an expression
    # - **@raise** [Exception] if the column does not exist
    #
    # **Example**
    #
    # ```
    # query.inner(:orders) { |w| w.users.id == orders.user_id }
    # => "SELECT * FROM users INNER JOIN orders ON users.id = orders.user_id"
    # ```
    def inner(table : Symbol, &)
      tbl = find_table(table)
      join_table = Expression::Table.new(tbl)
      tables = @tables.dup
      tables[table] = tbl
      builder = with Expression::FilterBuilder.new(tables) yield
      @joins << Expression::Join.new(Expression::JoinType::INNER, join_table, builder.condition)
      self
    end

    # Adds a LEFT JOIN to the query.
    # - **@param** table [Symbol] The table to join
    # - **@param** on [Hash(Cql::BaseColumn, Cql::BaseColumn | DB::Any)] The join condition
    #
    # **Example**
    #
    # ```
    # query.left(:orders, on: { users.id => orders.user_id })
    # => "SELECT * FROM users LEFT JOIN orders ON users.id = orders.user_id"
    # ```
    def left(table : Symbol, on : Hash(Cql::BaseColumn, Cql::BaseColumn | DB::Any))
      join(Expression::JoinType::LEFT, find_table(table), on)
      self
    end

    # Adds a LEFT JOIN to the query using a block.
    # - **@param** table [Symbol] The table to join
    # - **@yield** [FilterBuilder] The block to build the conditions
    # - **@return** [Query] The query object
    # - **@raise** [Exception] if the block is not provided
    # - **@raise** [Exception] if the block does not return an expression
    # - **@raise** [Exception] if the column does not exist
    #
    # **Example**
    #
    # ```
    # query.left(:orders) { |w| w.users.id == orders.user_id }
    # => "SELECT * FROM users LEFT JOIN orders ON users.id = orders.user_id"
    # ```
    def left(table : Symbol, &)
      table = find_table(table)
      join_table = Expression::Table.new(@tables[table])
      tables = @tables.dup
      tables[table] = table
      builder = with Expression::FilterBuilder.new(tables) yield
      @joins << Expression::Join.new(Expression::JoinType::LEFT, join_table, builder.condition)
      self
    end

    # Adds a RIGHT JOIN to the query.
    # - **@param** table [Symbol] The table to join
    # - **@param** on [Hash(Cql::BaseColumn, Cql::BaseColumn | DB::Any)] The join condition
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # query.right(:orders, on: { users.id => orders.user_id })
    # => "SELECT * FROM users RIGHT JOIN orders ON users.id = orders.user_id"
    # ```
    def right(table : Symbol, on : Hash(Cql::BaseColumn, Cql::BaseColumn | DB::Any))
      join(Expression::JoinType::RIGHT, find_table(table), on)
      self
    end

    # Adds a RIGHT JOIN to the query using a block.
    # - **@param** table [Symbol] The table to join
    # - **@yield** [FilterBuilder] The block to build the conditions
    # - **@return** [Query] The query object
    # - **@raise** [Exception] if the block is not provided
    # - **@raise** [Exception] if the block does not return an expression
    # - **@raise** [Exception] if the column does not exist
    # - **@raise** [Exception] if the value is invalid
    #
    # **Example**
    #
    # ```
    # query.right(:orders) { |w| w.users.id == orders.user_id }
    # => "SELECT * FROM users RIGHT JOIN orders ON users.id = orders.user_id"
    # ```
    def right(table : Symbol, &)
      table = find_table(table)
      join_table = Expression::Table.new(@tables[table])
      tables = @tables.dup
      tables[table] = table
      builder = with Expression::FilterBuilder.new(tables) yield
      @joins << Expression::Join.new(Expression::JoinType::RIGHT, join_table, builder.condition)
      self
    end

    # Specifies the columns to order by.
    # - **@param** fields [Symbol*] The columns to order by
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # query.order(:name, :age)
    # => "SELECT * FROM users ORDER BY name, age"
    # ```
    def order(*fields)
      fields.each do |k|
        column = Expression::Column.new(find_column(k))
        @order_by[column] = Expression::OrderDirection::ASC
      end

      self
    end

    # Specifies the columns to order by.
    # - **@param** fields [Hash(Symbol, Symbol)] The columns to order by and their direction
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # query.order(name: :asc, age: :desc)
    # => "SELECT * FROM users ORDER BY name ASC, age DESC"
    # ```
    def order(**fields)
      fields.each do |k, v|
        column = Expression::Column.new(find_column(k))
        @order_by[column] = Expression::OrderDirection.parse(v.to_s)
      end

      self
    end

    # Specifies the columns to group by.
    # - **@param** columns [Symbol*] The columns to group by
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # query.from(:products).group(:category)
    # => "SELECT * FROM products GROUP BY category"
    # ```
    def group(*columns)
      @group_by = columns.map { |column| find_column(column) }.to_a
      self
    end

    # Adds a HAVING condition to the grouped results.
    # - **@param** block [Block] The block to evaluate the having condition
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # query.from(:products).group(:category).having { avg(:price) > 100 }
    # => "SELECT * FROM products GROUP BY category HAVING AVG(price) > 100"
    # ```
    def having(&)
      builder = with Expression::HavingBuilder.new(@group_by) yield
      @having = Expression::Having.new(builder.condition)
      self
    end

    # Sets the limit for the number of records to return.
    # - **@param** value [Int32] The limit value
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # query.from(:users).limit(10)
    # => "SELECT * FROM users LIMIT 10"
    # ```
    def limit(value : Int32)
      @limit = value
      self
    end

    # Sets the offset for the query.
    # - **@param** value [Int32] The offset value
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # query.from(:users).limit(10).offset(20)
    # => "SELECT * FROM users LIMIT 10 OFFSET 20"
    # ```
    def offset(value : Int32)
      @offset = value
      self
    end

    # Sets the distinct flag to true.
    # - **@return** [Query] The query object
    #
    # **Example**
    # ```
    # query.from(:users).distinct
    # => "SELECT DISTINCT * FROM users"
    # ```
    def distinct
      @distinct = true
      self
    end

    # Builds the final query expression.
    # - **@return** [Expression::Query] The query expression
    #
    # **Example**
    #
    # ```
    # query.build
    # => #<Expression::Query:0x00007f8b1b0b3b00>
    # ```
    def build
      Expression::Query.new(
        build_select,
        build_from,
        @where,
        build_group_by,
        @having,
        build_order_by,
        @joins,
        build_limit,
        distinct?,
        @aggr_columns
      )
    end

    private def build_from
      Expression::From.new(@tables.values)
    end

    private def join(type : Expression::JoinType, table : Table, on : Hash(Cql::BaseColumn, Cql::BaseColumn | DB::Any))
      condition = on.map do |left, right|
        right_col = if right.is_a?(DB::Any)
                      left.validate!(right)
                      right
                    else
                      Expression::Column.new(right)
                    end
        Expression::CompareCondition.new(Expression::Column.new(left), "=", right_col)
      end.reduce { |acc, cond| Expression::And.new(acc, cond) }

      @joins << Expression::Join.new(type, Expression::Table.new(table), condition)
      self
    end

    private def get_expression(field, value)
      column = find_column(field)
      column.validate!(value)
      Expression::Compare.new(Expression::Column.new(column), "=", value)
    end

    private def build_group_by
      Expression::GroupBy.new(@group_by.map { |column| Expression::Column.new(column) })
    end

    private def build_order_by
      Expression::OrderBy.new(order_by)
    end

    private def build_limit
      Expression::Limit.new(@limit, @offset) if @limit
    ensure
      @limit = nil
      @offset = nil
    end

    private def build_select
      if @columns.empty? && @aggr_columns.empty?
        @tables.each do |_tbl_name, table|
          @columns.concat(table.columns.values)
        end
      end

      @columns.map do |column|
        Expression::Column.new(column)
      end
    end

    private def find_table(name : Symbol) : Cql::Table
      table = @schema.tables[name]
      raise "Table #{name} not found" unless table
      table
    end

    private def build_aggr_expression(aggr : Symbol, column : Symbol)
      col = Expression::Column.new(find_column(column))
      case aggr
      when :count then Expression::Count.new(col)
      when :sum   then Expression::Sum.new(col)
      when :avg   then Expression::Avg.new(col)
      when :min   then Expression::Min.new(col)
      when :max   then Expression::Max.new(col)
      else
        raise "Invalid aggregate function #{aggr}"
      end
    end

    private def find_column(name : Symbol, table_name : Symbol? = nil) : Cql::BaseColumn
      if table_name
        table = @schema.tables[table_name]
        column = table.columns[name]
        return column if column
        raise "Column #{name} not found in table #{table_name}"
      else
        @tables.each do |_tbl_name, tbl|
          column = tbl.columns[name]?
          return column if column
        end
        raise "Column #{name} not found in any of #{@tables.keys} tables"
      end
    end

    private def validate_fields!(**fields)
      fields.map do |name, value|
        column = find_column(name)
        raise "Column #{name} not found" unless column
        raise "Column #{name} is not nullable" if !column.null? && value.nil?
        raise "Column #{name} is not of type #{value.class}" unless column.type.new(value)
        column
      end
    end

    macro method_missing(call)
      def {{call.id}}
        @schema.tables[:{{call.id}}]
      end
    end
  end
end
