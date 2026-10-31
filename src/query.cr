require "./executable"
require "./prepared_select"
require "./compound_query"
require "./derived_table"
require "./window_builder"
require "./base_column"
require "./table"
require "./schema"
require "./expression"
require "./insert"
require "./update"
require "./delete"
require "./merge_query"
require "./cache/request_query_cache"
require "./performance" # Performance monitoring integration

module CQL
  # The `Query` class is responsible for building SQL queries in a structured manner.
  # It holds various components like selected columns, tables, conditions, and more.
  # It provides methods to execute the query and return results.
  #
  # ## Performance Monitoring
  #
  # All query execution methods (`all`, `first`, `get`, `each`) are tracked by the
  # CQL Performance module once monitoring is enabled. This provides:
  # - Query execution time tracking
  # - Slow query detection
  # - N+1 query pattern detection
  # - Performance report generation
  #
  # Monitoring is opt-in. To enable it:
  # ```
  # CQL::Performance.enable_monitoring
  # ```
  #
  # To track queries with context:
  # ```
  # CQL::Performance.with_context("UserController#index") do
  #   AcmeDB.query.from(:users).all(User)
  # end
  # ```
  #
  # **Example** Creating a new query
  #
  # ```
  # query = CQL::Query.new(AcmeDB) # same as AcmeDB.query
  # users = query.from(:users).where(name: "John").all(User)
  # ```
  #
  # **Example** Executing a query and iterating over results
  #
  # ```
  # AcmeDB.query.from(:users).where(name: "John").each(User) do |user|
  #   puts user.name
  # end
  # ```
  class Query
    include Executable
    include SetOperations

    # A clause collection most queries never use: allocated on first access through its getter,
    # so `new` and `clone` pay nothing for it. `name?` tells whether it holds anything without
    # allocating.
    macro lazy_collection(name, type)
      @{{name.id}} : {{type}}? = nil

      def {{name.id}} : {{type}}
        @{{name.id}} ||= {{type}}.new
      end

      def {{name.id}}? : Bool
        !!@{{name.id}}.try { |collection| !collection.empty? }
      end

      # A copy for building an AST node, which needs a collection even when empty.
      private def {{name.id}}_snapshot : {{type}}
        @{{name.id}}.try(&.dup) || {{type}}.new
      end
    end

    getter columns : Array(CQL::BaseColumn) = [] of CQL::BaseColumn
    getter schema : Schema
    # Ensure alias is String
    alias QueryTableInfo = {table: CQL::Table, alias: String}
    getter query_tables : Hash(String, QueryTableInfo) = {} of String => QueryTableInfo # Key is alias (String)
    property where : Expression::Where? = nil
    lazy_collection group_by, Array(CQL::BaseColumn)
    property having : Expression::Having? = nil
    lazy_collection order_by, Hash(CQL::BaseColumn, Expression::OrderDirection)
    lazy_collection joins, Array(Expression::Join)
    property limit : Int32? = nil
    property offset : Int32? = nil
    property? distinct : Bool = false
    lazy_collection select_expressions, Array(Expression::SelectExpression)
    # Store column aliases: column => alias
    lazy_collection column_aliases, Hash(CQL::BaseColumn, String)
    # CTEs declared on this query, and the tables they expose by name.
    lazy_collection ctes, Array(Expression::Cte)
    lazy_collection derived_tables, Hash(Symbol, CQL::Table)
    property? recursive : Bool = false
    lazy_collection distinct_on, Array(Expression::BaseColumn)
    property row_lock : Expression::RowLock? = nil

    # Initializes the `Query` object with the provided schema.
    # - **@param** schema [Schema] The schema object to use for the query
    # - **@return** [Query] The query object
    #
    # **Example** Creating a new query
    # ```
    # query = CQL::Query.new(AcmeDB)
    # ```
    def initialize(@schema : Schema)
    end

    # :nodoc: Keep the query AST, replacing its explicit execution context.
    def rebind(schema : Schema) : Query
      if binding = @schema.binding
        raise CQL::Error.new("Cannot rebind a query to a different binding") unless binding == schema.binding
      end
      copy = clone
      copy.replace_schema(schema)
      copy
    end

    protected def replace_schema(@schema : Schema) : Nil
      @executor = nil
      @query_tables.transform_values! do |entry|
        next entry if entry[:table].is_a?(CQL::DerivedTable)
        {table: @schema.tables[entry[:table].table_name]? || entry[:table], alias: entry[:alias]}
      end
    end

    # Clone the query object
    def clone
      new_query = Query.new(@schema)
      # Copy all properties manually
      @columns.each { |col| new_query.columns << col }
      @query_tables.each { |key, value| new_query.query_tables[key] = value }
      new_query.where = @where
      new_query.having = @having
      new_query.limit = @limit
      new_query.offset = @offset
      new_query.distinct = @distinct
      new_query.recursive = recursive?
      new_query.row_lock = @row_lock
      new_query.executor = @executor
      new_query.copy_lazy_collections(self)
    end

    protected def copy_lazy_collections(other : Query) : self
      @group_by = copied(other.@group_by)
      @order_by = copied(other.@order_by)
      @joins = copied(other.@joins)
      @select_expressions = copied(other.@select_expressions)
      @column_aliases = copied(other.@column_aliases)
      @ctes = copied(other.@ctes)
      @derived_tables = copied(other.@derived_tables)
      @distinct_on = copied(other.@distinct_on)
      self
    end

    private def copied(collection : T?) : T? forall T
      collection.dup unless collection.nil? || collection.empty?
    end

    # The first row mapped to *kind*, rendered with `LIMIT 1` instead of on a clone.
    def first(as kind)
      sql, params = render(build(limit: 1))
      contextualize(PreparedSelect.new(@schema, sql, params).using(executor).get(kind))
    end

    def first!(as kind)
      first(kind) || raise DB::NoResultsError.new("No records found")
    end

    # Specifies the columns to select, grouped by table name or alias.
    # - **@param** fields [Hash(Symbol, Array(Symbol) | Symbol)] The columns to select
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # AcmeDB.query.from(:users, :posts).select(users: [:name, :age], posts: [:title]).to_sql
    # # => {"SELECT users.name, users.age, posts.title FROM users, posts", []}
    # ```
    #
    # **Example with aggregates**
    #
    # ```
    # AcmeDB.query.from(:users).select(count: :id).to_sql
    # # => {"SELECT COUNT(users.id) FROM users", []}
    # ```
    def select(**fields : Hash(String | Symbol, Array(Symbol) | Symbol))
      fields.each do |key, value|
        # Convert Symbol key to String for consistency
        alias_or_aggr_str = key.is_a?(Symbol) ? key.to_s : key

        if [:count, :sum, :avg, :min, :max].includes?(key) && value.is_a?(Symbol)
          # Aggregates handle alias lookup internally now via build_aggr_expression
          # Use original Symbol key here for aggregate type
          select_expressions << build_aggr_expression(key, value) # Pass Symbol for aggr type
        else
          # key is the alias (String or Symbol -> converted to String)
          table_alias_str = alias_or_aggr_str
          table_info = @query_tables[table_alias_str]?
          unless table_info
            raise ArgumentError.new "Unknown table or alias '#{table_alias_str}' in select"
          end
          columns_to_add = case value
                           when Array(Symbol)
                             # Pass String alias hint to find_column
                             value.map { |name| find_column(name, table_alias_str) }
                           when Symbol
                             # Pass String alias hint to find_column
                             [find_column(value, table_alias_str)]
                           else
                             raise ArgumentError.new "Invalid select value type: #{value.class}"
                           end
          @columns.concat(columns_to_add)
        end
      end
      # Prevent duplicate columns
      @columns.uniq!(&.object_id)
      self
    end

    # Allow mixing String/Symbol args and Hash
    def select(*cols : Symbol | String, **fields : Hash(String | Symbol, Array(Symbol) | Symbol))
      self.select(*cols)
      self.select(**fields)
      self
    end

    def select(**fields)
      fields.each do |key, value|
        if [:count, :sum, :avg, :min, :max].includes?(key) && value.is_a?(Symbol)
          select_expressions << build_aggr_expression(key, value)
        else
          if value.is_a?(Array(Symbol))
            value.each do |name|
              column = find_column(name, key.to_s)
              @columns << column
              column_aliases[column] = key.to_s
            end
          else
            column = find_column(key)
            @columns << column
            column_aliases[column] = value.to_s
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
    # AcmeDB.query.from(:users).select(:name, :age).to_sql
    # # => {"SELECT users.name, users.age FROM users", []}
    # ```
    def select(*columns : Symbol | String)
      added_cols = columns.map do |col_name_or_qualified|
        # find_column handles String/Symbol, ambiguity check, returns BaseColumn
        find_column(col_name_or_qualified)
      end
      @columns.concat(added_cols)
      @columns.uniq!(&.object_id)
      self
    end

    # Specifies the tables to select from.
    # - **@param** tbls_or_aliases [Symbol* | Hash(Symbol, Symbol)*] The tables to select from
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # AcmeDB.query.from(:users, :posts) # selects every column of both tables
    # ```
    def from(*tbls_or_aliases : Symbol | Hash(Symbol, Symbol))
      @query_tables.clear # FROM clause resets tables
      @columns.clear      # Also clear selected columns when FROM changes
      @joins = nil
      tbls_or_aliases.each do |item|
        # parse_table_or_alias handles Symbol/Hash, returns {Symbol, Symbol?}
        table_name_sym, table_alias_sym = parse_table_or_alias(item)
        table = find_schema_table(table_name_sym)
        # determine_alias returns String alias, using .to_s for symbols
        table_alias_str = determine_alias(table_name_sym, table_alias_sym)
        # ensure_alias_available expects String
        ensure_alias_available(table_alias_str)
        # Store with String alias
        @query_tables[table_alias_str] = {table: table, alias: table_alias_str}
      end
      self
    end

    # Uses a subquery as the FROM source: `FROM (SELECT ...) AS alias`. Its selected
    # columns can be referenced through *alias*.
    def from(source : Executable, as alias_name : Symbol) : self
      CQL::Identifier.validate!(alias_name.to_s, "alias")
      statement = source.build
      @query_tables.clear
      @columns.clear
      @joins = nil
      table = CQL::DerivedTable.new(@schema, alias_name, statement, inline: true)
      @query_tables[alias_name.to_s] = {table: table, alias: alias_name.to_s}
      self
    end

    # Adds `FUNCTION(...) OVER (PARTITION BY ... ORDER BY ... frame) AS name` to the select list.
    #
    # ```
    # query = AcmeDB.query.from(:users)
    # query.window(:row_number, as: :age_rank, partition_by: :active, order_by: {age: :desc})
    # query.window(:sum, :age, as: :running_age, order_by: :id, rows: {:unbounded_preceding, 0})
    # query.window(:lag, :age, offset: 1, as: :previous_age, order_by: :id)
    # query.window(:ntile, buckets: 4, as: :quartile, order_by: :age)
    # ```
    #
    # Functions: row_number, rank, dense_rank, percent_rank, cume_dist, ntile,
    # lag, lead, first_value, last_value, count, sum, avg, min, max. Frame
    # bounds are offsets (negative = preceding) or `:unbounded_preceding` /
    # `:unbounded_following`. Without a preceding `select(...)` only the window column
    # is selected; windows read plain table columns (not aggregates).
    def window(function : Symbol, column : Symbol? = nil, *, as name : Symbol, offset : Int32? = nil, buckets : Int32? = nil,
               partition_by : (Symbol | Array(Symbol))? = nil,
               order_by : (Symbol | Array(Symbol) | Hash(Symbol, Symbol) | NamedTuple)? = nil,
               rows : Tuple(Int32 | Symbol, Int32 | Symbol)? = nil, range : Tuple(Int32 | Symbol, Int32 | Symbol)? = nil) : self
      select_expressions << CQL::WindowBuilder.new(self).build(function, column, name, offset, buckets, partition_by, order_by, rows, range)
      self
    end

    # The column as an expression qualified by the alias of its table in this query.
    def column_expression(name : Symbol | String) : Expression::Column
      column = find_column(name)
      Expression::Column.new(column, alias_name: find_alias_for_table(column.table.not_nil!))
    end

    # Declares `WITH name AS (source)`; *name* can then be used in `from`/`join`
    # like a table, with the columns *source* selects.
    #
    # ```
    # adults = AcmeDB.query.from(:users).select(:name).where_gt(:age, 17)
    # AcmeDB.query.with(:adults, adults).from(:adults).to_sql
    # # => {"WITH adults AS (SELECT users.name FROM users WHERE users.age > ?) SELECT adults.name FROM adults", [17]}
    # ```
    def with(name : Symbol, source : Executable) : self
      declare(name, source.build)
      self
    end

    # Like `with`, building the source from a query that can already see the CTEs
    # declared so far, so one CTE can read another.
    def with(name : Symbol, &block : Query -> Executable) : self
      self.with(name, block.call(nested))
    end

    # A fresh query that can reference this query's CTEs, for subqueries and CTE bodies.
    def nested : Query
      Query.new(@schema).tap { |query| @derived_tables.try &.each { |name, table| query.derived_tables[name] = table } }
    end

    # Declares `WITH RECURSIVE name AS (anchor UNION [ALL] step)`. The block receives
    # an empty query that already knows *name*, and returns the recursive step
    # (which cannot have ORDER BY / LIMIT; put those on the outer query).
    def with_recursive(name : Symbol, anchor : Query, all : Bool = true, &block : Query -> Query) : self
      anchor_statement = anchor.build
      table = CQL::DerivedTable.new(@schema, name, anchor_statement)
      step = block.call(nested.tap(&.derived_tables[name] = table)).build
      raise ArgumentError.new("A recursive step cannot have ORDER BY, LIMIT or its own CTEs; apply them to the outer query") if step.needs_grouping_as_operand?
      operator = all ? Expression::SetOperator::UnionAll : Expression::SetOperator::Union
      declare(name, Expression::SetOperation.new(anchor_statement, operator, step), table)
      self.recursive = true
      self
    end

    # Accept keyword arguments for table/alias pairs
    def from(**tables_with_aliases)
      @query_tables.clear # FROM clause resets tables
      @columns.clear      # Also clear selected columns when FROM changes
      @joins = nil

      # Iterate over the NamedTuple {table_name: alias_name}
      tables_with_aliases.each do |table_name_sym, table_alias_sym|
        # Ensure alias is a Symbol (as expected from **)
        unless table_alias_sym.is_a?(Symbol)
          raise ArgumentError.new("Invalid alias type for table '#{table_name_sym}'. Expected Symbol, got #{table_alias_sym.class}")
        end

        table = find_schema_table(table_name_sym)
        # determine_alias expects Symbol? for alias, returns String
        final_alias_str = determine_alias(table_name_sym, table_alias_sym)
        ensure_alias_available(final_alias_str) # Expects String
        # Store with String alias key
        @query_tables[final_alias_str] = {table: table, alias: final_alias_str}
      end
      self
    end

    # Accept Hash(Symbol, DB::Any) for backward compatibility
    def where(hash : Hash(String | Symbol, DB::Any | Array(DB::Any)))
      # Convert Symbol keys to String
      new_condition = build_condition_from_hash(hash)
      merge_where_condition(new_condition)
      self
    end

    # Correct implementation for where(&)
    def where(&)
      # Pass the String-keyed query_tables hash to FilterBuilder
      builder = Expression::FilterBuilder.new(@query_tables)
      # Capture the ConditionBuilder returned by the block
      condition_builder = with builder yield
      # Get the actual condition from the builder
      new_condition = condition_builder.as(Expression::ConditionBuilder).condition
      merge_where_condition(new_condition)
      self
    end

    # A raw SQL fragment with bound `?` or `:name` values (not both in one fragment),
    # ANDed with other conditions.
    #
    # ```
    # AcmeDB.query.from(:users).where("lower(name) = ? AND age > ?", "ada", 18)
    # AcmeDB.query.from(:users).where("age > :age", age: 18)
    # ```
    def where(__sql sql : String, *positional, **named)
      merge_where_condition(Expression::Raw.build(sql, positional, named))
      self
    end

    # ANDs an already built condition (typed DSL, `CQL.raw`) with the existing WHERE.
    def where(condition : Expression::ConditionBuilder) : self
      merge_where_condition(condition.condition)
      self
    end

    # Joins *table* with the given join type and an explicit ON condition built by the block.
    def join_on(table : Symbol, type : Expression::JoinType, &block : Expression::FilterBuilder -> _) : self
      join_table_block(table, type, &block)
    end

    def where(**fields)
      new_condition = build_condition_from_hash(fields)
      merge_where_condition(new_condition)
      self
    end

    # Support for LIKE conditions
    def where_like(field : Symbol | String, pattern : String)
      column = find_column(field)
      col_alias_str = find_alias_for_table(column.table.not_nil!)
      col_expr = Expression::Column.new(column, alias_name: col_alias_str)
      like_condition = Expression::Like.new(col_expr, pattern)
      merge_where_condition(like_condition)
      self
    end

    # Adds an IS NULL condition for the specified field.
    # Provides explicit null checking for better code clarity.
    # - **@param** field [Symbol | String] The column to check for null
    # - **@return** [Query] The query object
    #
    # **Example**
    # ```
    # # Find posts without a body
    # AcmeDB.query.from(:posts).where_null(:body).all(Post)
    # ```
    def where_null(field : Symbol | String)
      column = find_column(field)
      col_alias_str = find_alias_for_table(column.table.not_nil!)
      col_expr = Expression::Column.new(column, alias_name: col_alias_str)
      null_condition = Expression::IsNull.new(col_expr)
      merge_where_condition(null_condition)
      self
    end

    # Adds an IS NOT NULL condition for the specified field.
    # Provides explicit non-null checking for better code clarity.
    # - **@param** field [Symbol | String] The column to check for not null
    # - **@return** [Query] The query object
    #
    # **Example**
    # ```
    # # Find posts with a body
    # AcmeDB.query.from(:posts).where_not_null(:body).all(Post)
    # ```
    def where_not_null(field : Symbol | String)
      column = find_column(field)
      col_alias_str = find_alias_for_table(column.table.not_nil!)
      col_expr = Expression::Column.new(column, alias_name: col_alias_str)
      not_null_condition = Expression::IsNotNull.new(col_expr)
      merge_where_condition(not_null_condition)
      self
    end

    # Adds a greater-than condition for the specified field.
    # Useful for cursor-based pagination and range queries.
    # - **@param** field [Symbol | String] The column to compare
    # - **@param** value [DB::Any] The value to compare against
    # - **@return** [Query] The query object
    #
    # **Example**
    # ```
    # # Find records with id greater than 100
    # AcmeDB.query.from(:users).where_gt(:id, 100).all(User)
    # ```
    def where_gt(field : Symbol | String, value : DB::Any)
      column = find_column(field)
      col_alias_str = find_alias_for_table(column.table.not_nil!)
      col_expr = Expression::Column.new(column, alias_name: col_alias_str)
      gt_condition = Expression::Compare.new(col_expr, ">", value)
      merge_where_condition(gt_condition)
      self
    end

    # Adds a less-than condition for the specified field.
    # Useful for cursor-based pagination and range queries.
    # - **@param** field [Symbol | String] The column to compare
    # - **@param** value [DB::Any] The value to compare against
    # - **@return** [Query] The query object
    #
    # **Example**
    # ```
    # # Find records with id less than 100
    # AcmeDB.query.from(:users).where_lt(:id, 100).all(User)
    # ```
    def where_lt(field : Symbol | String, value : DB::Any)
      column = find_column(field)
      col_alias_str = find_alias_for_table(column.table.not_nil!)
      col_expr = Expression::Column.new(column, alias_name: col_alias_str)
      lt_condition = Expression::Compare.new(col_expr, "<", value)
      merge_where_condition(lt_condition)
      self
    end

    # Adds a JOIN to the query with automatic relationship detection.
    # - **@param** table_or_alias [Symbol] The table to join
    # - **@return** [Query] The query object
    def join(table_or_alias : Symbol)
      join_table(table_or_alias, Expression::JoinType::INNER)
    end

    # Adds a JOIN to the query using a block for the condition.
    # - **@param** table_or_alias [Symbol] The table to join
    # - **@yield** [FilterBuilder] The block to build the ON condition
    # - **@return** [Query] The query object
    def join(table_or_alias : Symbol, &block : Expression::FilterBuilder -> _)
      join_table_block(table_or_alias, Expression::JoinType::INNER, &block)
    end

    # Adds a LEFT JOIN to the query with automatic relationship detection.
    # - **@param** table_or_alias [Symbol] The table to join
    # - **@return** [Query] The query object
    def left(table_or_alias : Symbol)
      join_table(table_or_alias, Expression::JoinType::LEFT)
    end

    # Adds a LEFT JOIN to the query using a block for the condition.
    # - **@param** table_or_alias [Symbol] The table to join
    # - **@yield** [FilterBuilder] The block to build the ON condition
    # - **@return** [Query] The query object
    def left(table_or_alias : Symbol, &block : Expression::FilterBuilder -> _)
      join_table_block(table_or_alias, Expression::JoinType::LEFT, &block)
    end

    # Adds a RIGHT JOIN to the query with automatic relationship detection.
    # - **@param** table_or_alias [Symbol] The table to join
    # - **@return** [Query] The query object
    def right(table_or_alias : Symbol)
      join_table(table_or_alias, Expression::JoinType::RIGHT)
    end

    # Adds a RIGHT JOIN to the query using a block for the condition.
    # - **@param** table_or_alias [Symbol] The table to join
    # - **@yield** [FilterBuilder] The block to build the ON condition
    # - **@return** [Query] The query object
    def right(table_or_alias : Symbol, &block : Expression::FilterBuilder -> _)
      join_table_block(table_or_alias, Expression::JoinType::RIGHT, &block)
    end

    # Adds a FULL OUTER JOIN using a block for the condition (not supported by MySQL).
    def full(table_or_alias : Symbol, &block : Expression::FilterBuilder -> _)
      join_table_block(table_or_alias, Expression::JoinType::FULL, &block)
    end

    # Adds a CROSS JOIN (every row paired with every row of *table*).
    def cross(table_or_alias : Symbol) : self
      table_name, table_alias = parse_table_or_alias(table_or_alias)
      table = find_schema_table(table_name)
      final_alias = determine_alias(table_name, table_alias)
      ensure_alias_available(final_alias)
      add_join_expression(table, final_alias, Expression::JoinType::CROSS, Expression::EmptyNode.new)
      self
    end

    # Adds JOINs to the query using named arguments for table aliasing.
    # - **@param** tables_with_aliases [NamedTuple] Table name => alias
    # - **@return** [Query] The query object
    def join(**tables_with_aliases)
      # Convert NamedTuple to {Symbol, Symbol} pairs
      pairs = tables_with_aliases.map { |table_name, alias_name| {table_name, alias_name} }
      join_inferred(pairs, Expression::JoinType::INNER)
    end

    # Adds LEFT JOINs to the query using named arguments for table aliasing.
    # - **@param** tables_with_aliases [NamedTuple] Table name => alias
    # - **@return** [Query] The query object
    def left(**tables_with_aliases)
      pairs = tables_with_aliases.map { |table_name, alias_name| {table_name, alias_name} }
      join_inferred(pairs, Expression::JoinType::LEFT)
    end

    # Adds RIGHT JOINs to the query using named arguments for table aliasing.
    # - **@param** tables_with_aliases [NamedTuple] Table name => alias
    # - **@return** [Query] The query object
    def right(**tables_with_aliases)
      pairs = tables_with_aliases.map { |table_name, alias_name| {table_name, alias_name} }
      join_inferred(pairs, Expression::JoinType::RIGHT)
    end

    # Specifies the columns to order by.
    # Handles qualified columns like `order("users.name")` or aliases `order("u.name")`.
    # - **@param** fields [Symbol* | String*] The columns to order by (Symbol or "alias.column")
    # - **@return** [Query] The query object
    def order(*fields : Symbol | String)
      fields.each do |k|
        column = find_column(k) # Handles String like "alias.column" or Symbol
        order_by[column] = Expression::OrderDirection::ASC
      end
      self
    end

    # Specifies the columns to order by with direction.
    # Handles qualified columns or aliases in keys.
    # - **@param** fields [Hash(Symbol | String, Symbol)] Column => :asc/:desc
    # - **@return** [Query] The query object
    def order(**fields)
      fields.each do |k, v|
        column = find_column(k) # Handles String like "alias.column" or Symbol
        direction = v.is_a?(Symbol) ? Expression::OrderDirection.parse(v.to_s) : Expression::OrderDirection::ASC
        order_by[column] = direction
      end
      self
    end

    # Specifies the columns to group by.
    # Handles qualified columns or aliases.
    # - **@param** columns [Symbol* | String*] The columns to group by
    # - **@return** [Query] The query object
    def group(*columns : Symbol | String)
      # find_column handles String/Symbol
      @group_by = columns.map { |column| find_column(column) }.to_a
      self
    end

    # Adds a HAVING condition to the grouped results.
    # The block uses a HavingBuilder which needs alias awareness.
    # - **@yield** [HavingBuilder] Block to build the condition.
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # AcmeDB.query.from(:users).select(:age).group(:age).having { count(:id) > 5 }.to_sql
    # # => {"SELECT users.age FROM users GROUP BY users.age HAVING COUNT(users.id) > ?", [5]}
    # ```
    def having(&)
      # Pass String-keyed query_tables to HavingBuilder
      builder = Expression::HavingBuilder.new(@query_tables)
      having_builder = with builder yield
      @having = Expression::Having.new(having_builder.condition)
      self
    end

    # Sets the limit for the number of records to return.
    # - **@param** value [Int32] The limit value
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # AcmeDB.query.from(:users).select(:name).limit(10).to_sql
    # # => {"SELECT users.name FROM users LIMIT ?", [10]}
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
    # AcmeDB.query.from(:users).select(:name).limit(10).offset(20).to_sql
    # # => {"SELECT users.name FROM users LIMIT ? OFFSET ?", [10, 20]}
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
    # AcmeDB.query.from(:users).select(:name).distinct.to_sql
    # # => {"SELECT DISTINCT users.name FROM users", []}
    # ```
    def distinct
      @distinct = true
      self
    end

    # PostgreSQL / CockroachDB: keep the first row of each group of equal *columns*
    # (the order is decided by `order`). Other dialects raise when SQL is generated.
    def distinct_on(*columns : Symbol) : self
      @distinct_on = columns.map { |name| column_expression(name).as(Expression::BaseColumn) }.to_a
      self
    end

    # Appends `FOR UPDATE` (or `FOR SHARE`), optionally `SKIP LOCKED` / `NOWAIT`.
    # SQLite has no row locks and raises when SQL is generated.
    def lock(mode : Symbol = :update, skip_locked : Bool = false, nowait : Bool = false) : self
      raise ArgumentError.new("Use skip_locked or nowait, not both") if skip_locked && nowait
      lock_mode = Expression::LockMode.parse?(mode.to_s) || raise ArgumentError.new("Unknown lock mode #{mode.inspect} (use :update or :share)")
      wait = skip_locked ? Expression::LockWait::SkipLocked : (nowait ? Expression::LockWait::NoWait : Expression::LockWait::Wait)
      @row_lock = Expression::RowLock.new(lock_mode, wait)
      self
    end

    # Replaces the existing order clause with new ordering.
    # - **@param** fields [Symbol*] The fields to order by
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # AcmeDB.query.from(:users).select(:name).order(:name).reorder(:age).to_sql
    # # => {"SELECT users.name FROM users ORDER BY users.age ASC", []}
    # ```
    def reorder(*fields : Symbol | String)
      @order_by = nil
      order(*fields)
    end

    # Replaces the existing order clause with new ordering using hash syntax.
    # - **@param** fields [Hash] The fields and directions to order by
    # - **@return** [Query] The query object
    def reorder(**fields)
      @order_by = nil
      order(**fields)
    end

    # Reverses the order of the query.
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # AcmeDB.query.from(:users).select(:name).order(:name).reverse_order.to_sql
    # # => {"SELECT users.name FROM users ORDER BY users.name DESC", []}
    # ```
    def reverse_order
      @order_by.try do |order|
        order.each do |column, direction|
          order[column] = direction == Expression::OrderDirection::ASC ? Expression::OrderDirection::DESC : Expression::OrderDirection::ASC
        end
      end
      self
    end

    # Executes the query within a performance monitoring context.
    # This is useful for grouping related queries together in performance reports.
    # - **@param** context [String] The context name (e.g., "UserController#index")
    # - **@yield** Block that executes the query
    # - **@return** The result of the block
    #
    # **Example**
    #
    # ```
    # query = AcmeDB.query.from(:users).where(active: true)
    # users = query.with_performance_context("UserController#index") do
    #   query.all(User)
    # end
    # ```
    def with_performance_context(context : String, &)
      CQL::Performance.with_context(context) { yield }
    end

    # Removes specific scopes from the query.
    # - **@param** scopes [Symbol*] The scopes to remove
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # AcmeDB.query.from(:users).select(:name).where(active: true).unscope(:where).to_sql
    # # => {"SELECT users.name FROM users", []}
    # ```
    def unscope(*scopes : Symbol)
      scopes.each do |scope|
        case scope
        when :where
          @where = nil
        when :order
          @order_by = nil
        when :limit
          @limit = nil
        when :offset
          @offset = nil
        when :select
          @columns.clear
        when :group
          @group_by = nil
        when :having
          @having = nil
        when :joins
          @joins = nil
        when :distinct
          @distinct = false
        end
      end
      self
    end

    # Merges the properties of another Query object into this one.
    # The current query is modified in place.
    #
    # - **@param** other_query [Query] The query object to merge from.
    # - **@return** [Query] The current query object, modified.
    #
    # **Behavior:**
    # - **Schema:** Must be the same for both queries.
    # - **Distinct:** Becomes `true` if either query is distinct.
    # - **Select Columns (`@columns`):** Concatenated and uniqued by object identity.
    # - **Aggregate Columns (`@select_expressions`):** Concatenated and uniqued by object identity.
    # - **Query Tables (`@query_tables`):** Merged. Conflicts on alias pointing to different tables raise an error.
    # - **Joins (`@joins`):** Concatenated and uniqued by object identity.
    # - **Where (`@where`):** Conditions are combined using `AND`.
    # - **Group By (`@group_by`):** Concatenated and uniqued by object identity.
    # - **Having (`@having`):** Conditions are combined using `AND`.
    # - **Order By (`@order_by`):** Entries from `other_query` take precedence.
    # - **Limit (`@limit`):** The minimum of the two limits is taken if both are set; otherwise, the set limit is used.
    # - **Offset (`@offset`):** The `other_query`'s offset takes precedence if set.
    #
    # ameba/disable Metrics/CyclomaticComplexity
    def merge(other_query : Query) : Query
      unless @schema.binding == other_query.schema.binding
        raise CQL::Error.new("Cannot merge queries from different bindings")
      end
      MergeQuery.new(self, other_query).execute
    end

    # ameba/enable Metrics/CyclomaticComplexity

    # Builds the final query expression.
    # - **@param** limit [Int32?] Overrides the query's limit for this build (the query is unchanged)
    # - **@return** [Expression::Query] The query expression
    #
    # **Example**
    #
    # ```
    # AcmeDB.query.from(:users).build # an Expression::Query, ready for a generator
    # ```
    def build(limit : Int32? = @limit) : Expression::Query
      select_cols, aggr_exprs = build_select

      Expression::Query.new(
        select_cols,
        build_from,
        @where,
        build_group_by,
        @having,
        build_order_by,
        joins_snapshot,
        build_limit(limit),
        distinct?,
        aggr_exprs,
        ctes_snapshot,
        recursive?,
        distinct_on_snapshot,
        @row_lock
      ).tap { |statement| statement.binding = @schema.binding }
    end

    # Adds a COUNT aggregate function to the query.
    # - **@param** column [Symbol] The column to count
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # AcmeDB.query.from(:users).count(:id).to_sql
    # # => {"SELECT COUNT(users.id) FROM users", []}
    # ```
    def count(column : Symbol = :*, as as_name : Symbol? = nil, distinct : Bool = false)
      CQL::Identifier.validate!(as_name.to_s, "alias") if as_name
      raise ArgumentError.new("COUNT(DISTINCT *) is not valid; name a column") if distinct && column == :*
      select_expressions << if column == :*
        first_table_alias = @query_tables.first_key? # Use String key
        raise "Cannot COUNT(*) without a FROM clause" unless first_table_alias
        table_info = @query_tables[first_table_alias]
        # Use positional arguments for BaseColumn.new
        star_col = Column(Int64).new(:*)
        # Pass String alias
        Expression::Count.new(Expression::Column.new(star_col, alias_name: table_info[:alias]), as_name)
      else
        base_col = find_column(column)                            # find_column now handles aliases correctly
        col_alias = find_alias_for_table(base_col.table.not_nil!) # Returns String
        # Pass String alias
        Expression::Count.new(Expression::Column.new(base_col, alias_name: col_alias), as_name, distinct)
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
    # AcmeDB.query.from(:users).max(:age).to_sql
    # # => {"SELECT MAX(users.age) FROM users", []}
    # ```
    def max(column : Symbol, as as_name : Symbol? = nil)
      CQL::Identifier.validate!(as_name.to_s, "alias") if as_name
      base_col = find_column(column)
      col_alias = find_alias_for_table(base_col.table.not_nil!) # Returns String
      # Pass String alias
      select_expressions << Expression::Max.new(Expression::Column.new(base_col, alias_name: col_alias), as_name)
      self
    end

    # Adds a MIN aggregate function to the query.
    # - **@param** column [Symbol] The column to find the minimum value of
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # AcmeDB.query.from(:users).min(:age).to_sql
    # # => {"SELECT MIN(users.age) FROM users", []}
    # ```
    def min(column : Symbol, as as_name : Symbol? = nil)
      CQL::Identifier.validate!(as_name.to_s, "alias") if as_name
      base_col = find_column(column)
      col_alias = find_alias_for_table(base_col.table.not_nil!) # Returns String
      # Pass String alias
      select_expressions << Expression::Min.new(Expression::Column.new(base_col, alias_name: col_alias), as_name)
      self
    end

    # Adds a SUM aggregate function to the query.
    # - **@param** column [Symbol] The column to sum
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # AcmeDB.query.from(:users).sum(:age).to_sql
    # # => {"SELECT SUM(users.age) FROM users", []}
    # ```
    def sum(column : Symbol, as as_name : Symbol? = nil)
      CQL::Identifier.validate!(as_name.to_s, "alias") if as_name
      base_col = find_column(column)
      col_alias = find_alias_for_table(base_col.table.not_nil!) # Returns String
      # Pass String alias
      select_expressions << Expression::Sum.new(Expression::Column.new(base_col, alias_name: col_alias), as_name)
      self
    end

    # Adds an AVG aggregate function to the query.
    # - **@param** column [Symbol] The column to average
    # - **@return** [Query] The query object
    #
    # **Example**
    #
    # ```
    # AcmeDB.query.from(:users).avg(:age).to_sql
    # # => {"SELECT AVG(users.age) FROM users", []}
    # ```
    def avg(column : Symbol, as as_name : Symbol? = nil)
      CQL::Identifier.validate!(as_name.to_s, "alias") if as_name
      base_col = find_column(column)
      col_alias = find_alias_for_table(base_col.table.not_nil!) # Returns String
      # Pass String alias
      select_expressions << Expression::Avg.new(Expression::Column.new(base_col, alias_name: col_alias), as_name)
      self
    end

    # --- Private Methods --- #

    private def build_from
      # FROM clause uses String aliases from @query_tables
      from_table_aliases = @query_tables.keys.reject do |table_alias_str|
        @joins.try &.any? { |j| j.table.alias_name == table_alias_str }
      end
      from_tables_info = from_table_aliases.map { |alias_str| @query_tables[alias_str] }
      # Create Expression::Table with String alias
      from_table_expressions = from_tables_info.map { |info| from_source(info[:table], info[:alias]) }
      Expression::From.new(from_table_expressions)
    end

    # --- Simplified Join Methods --- #

    # Handles automatic join using foreign key relationships
    private def join_table(table_or_alias : Symbol | Hash(Symbol, Symbol), type : Expression::JoinType)
      target_table_name_sym, target_alias_sym = parse_table_or_alias(table_or_alias)
      target_table = find_schema_table(target_table_name_sym)
      final_alias_str = determine_alias(target_table_name_sym, target_alias_sym)
      ensure_alias_available(final_alias_str)

      # Add table to query_tables for relationship inference
      @query_tables[final_alias_str] = {table: target_table, alias: final_alias_str}

      # Find foreign key relationship
      found_fk = find_foreign_key_link(target_table)
      left_alias_str, left_columns_sym, right_alias_str, right_columns_sym = determine_join_sides(found_fk, final_alias_str)
      on_condition = build_join_condition(left_alias_str, left_columns_sym, right_alias_str, right_columns_sym)

      add_join_expression(target_table, final_alias_str, type, on_condition)
      self
    end

    # Handles join with block conditions
    private def join_table_block(table_or_alias : Symbol | Hash(Symbol, Symbol), type : Expression::JoinType, & : Expression::FilterBuilder -> _)
      target_table_name_sym, target_alias_sym = parse_table_or_alias(table_or_alias)
      join_table_obj = find_schema_table(target_table_name_sym)
      final_alias_str = determine_alias(target_table_name_sym, target_alias_sym)
      ensure_alias_available(final_alias_str)

      # Add table to query_tables for block access
      @query_tables[final_alias_str] = {table: join_table_obj, alias: final_alias_str}

      # FilterBuilder expects String-keyed hash
      builder = Expression::FilterBuilder.new(@query_tables)

      # Call the block with the builder as parameter
      condition_builder = yield(builder)

      # Get the condition from the returned builder
      condition = condition_builder.as(Expression::ConditionBuilder).condition

      add_join_expression(join_table_obj, final_alias_str, type, condition)
      self
    end

    # Expects hash with String keys now
    private def build_condition_from_hash(hash : Hash(Symbol | String, T | Array(T))) forall T
      condition = nil
      hash.each_with_index do |(k, v), index|
        # k is String (qualified or unqualified column name)
        expr = get_expression(k, v.as(T)) # Handles String key
        condition = index == 0 ? expr : Expression::And.new(condition.not_nil!, expr)
      end
      condition.not_nil!
    end

    private def build_condition_from_hash(fields)
      condition = nil
      index = 0
      fields.each do |k, v|
        # k is String (qualified or unqualified column name)
        expr = get_expression(k, v) # Handles String key
        condition = index == 0 ? expr : Expression::And.new(condition.not_nil!, expr)
        index += 1
      end
      condition.not_nil!
    end

    private def merge_where_condition(new_condition)
      if @where.nil?
        @where = Expression::Where.new(new_condition)
      else
        merged_condition = Expression::And.new(@where.not_nil!.condition, new_condition)
        @where = Expression::Where.new(merged_condition)
      end
    end

    # Handles String field (qualified or unqualified)
    private def get_expression(field : Symbol | String, value : T | Array(T)) forall T
      # find_column handles String field, finds BaseColumn
      column = find_column(field)
      # find_alias_for_table returns String alias
      col_alias_str = find_alias_for_table(column.table.not_nil!)
      # Create Expression::Column with String alias
      col_expr = Expression::Column.new(column, alias_name: col_alias_str)
      return Expression::IsNull.new(col_expr) if value.nil?

      # Explicitly handle Range types for BETWEEN
      case value
      when Range(Int32, Int32)
        return Expression::Between.new(col_expr, value.begin.as(DB::Any), value.end.as(DB::Any))
      when Range(Int64, Int64)
        return Expression::Between.new(col_expr, value.begin.as(DB::Any), value.end.as(DB::Any))
      when Range(Float32, Float32)
        return Expression::Between.new(col_expr, value.begin.as(DB::Any), value.end.as(DB::Any))
      when Range(Float64, Float64)
        return Expression::Between.new(col_expr, value.begin.as(DB::Any), value.end.as(DB::Any))
      when Range(Time, Time)
        return Expression::Between.new(col_expr, value.begin.as(DB::Any), value.end.as(DB::Any))
      end

      # Handle array values for IN conditions
      if value.is_a?(Array)
        Expression::InCondition.new(col_expr, value)
      else
        Expression::Compare.new(col_expr, "=", value.as(DB::Any))
      end
    end

    # Handles Array(DB::Any) for IN conditions
    private def get_expression(field : Symbol | String, value : Array(DB::Any))
      column = find_column(field)
      col_alias_str = find_alias_for_table(column.table.not_nil!)
      col_expr = Expression::Column.new(column, alias_name: col_alias_str)
      Expression::InCondition.new(col_expr, value)
    end

    # Handles Array(String) for IN conditions
    private def get_expression(field : Symbol | String, value : Array(String))
      column = find_column(field)
      col_alias_str = find_alias_for_table(column.table.not_nil!)
      col_expr = Expression::Column.new(column, alias_name: col_alias_str)
      Expression::InCondition.new(col_expr, value)
    end

    # Fallback for Array(T) for IN conditions
    private def get_expression(field : Symbol | String, value : Array)
      column = find_column(field)
      col_alias_str = find_alias_for_table(column.table.not_nil!)
      col_expr = Expression::Column.new(column, alias_name: col_alias_str)
      # Convert all elements to DB::Any
      db_any_values = value.map(&.as(DB::Any))
      Expression::InCondition.new(col_expr, db_any_values)
    end

    # Explicit overloads for scalar types
    private def get_expression(field : Symbol | String, value : String)
      column = find_column(field)
      col_alias_str = find_alias_for_table(column.table.not_nil!)
      col_expr = Expression::Column.new(column, alias_name: col_alias_str)
      Expression::Compare.new(col_expr, "=", value)
    end

    private def get_expression(field : Symbol | String, value : Int32)
      column = find_column(field)
      col_alias_str = find_alias_for_table(column.table.not_nil!)
      col_expr = Expression::Column.new(column, alias_name: col_alias_str)
      Expression::Compare.new(col_expr, "=", value)
    end

    private def get_expression(field : Symbol | String, value : Int64)
      column = find_column(field)
      col_alias_str = find_alias_for_table(column.table.not_nil!)
      col_expr = Expression::Column.new(column, alias_name: col_alias_str)
      Expression::Compare.new(col_expr, "=", value)
    end

    private def get_expression(field : Symbol | String, value : Float32)
      column = find_column(field)
      col_alias_str = find_alias_for_table(column.table.not_nil!)
      col_expr = Expression::Column.new(column, alias_name: col_alias_str)
      Expression::Compare.new(col_expr, "=", value)
    end

    private def get_expression(field : Symbol | String, value : Float64)
      column = find_column(field)
      col_alias_str = find_alias_for_table(column.table.not_nil!)
      col_expr = Expression::Column.new(column, alias_name: col_alias_str)
      Expression::Compare.new(col_expr, "=", value)
    end

    private def get_expression(field : Symbol | String, value : Bool)
      column = find_column(field)
      col_alias_str = find_alias_for_table(column.table.not_nil!)
      col_expr = Expression::Column.new(column, alias_name: col_alias_str)
      Expression::Compare.new(col_expr, "=", value)
    end

    private def get_expression(field : Symbol | String, value : Time)
      column = find_column(field)
      col_alias_str = find_alias_for_table(column.table.not_nil!)
      col_expr = Expression::Column.new(column, alias_name: col_alias_str)
      Expression::Compare.new(col_expr, "=", value)
    end

    private def build_group_by
      group_by = @group_by
      return if group_by.nil? || group_by.empty?
      Expression::GroupBy.new(group_by.map { |column| aliased(column) })
    end

    private def build_order_by
      order = @order_by
      return if order.nil? || order.empty?
      orders = Hash(Expression::BaseColumn, Expression::OrderDirection).new(initial_capacity: order.size)
      order.each { |column, direction| orders[aliased(column)] = direction }
      Expression::OrderBy.new(orders)
    end

    # The column as it appears in this query: qualified by *alias_name*, or its table's alias.
    private def aliased(column : BaseColumn, alias_name : String? = nil) : Expression::BaseColumn
      Expression::Column.new(column, alias_name: alias_name || find_alias_for_table(column.table.not_nil!)).as(Expression::BaseColumn)
    end

    private def build_limit(limit : Int32?)
      Expression::Limit.new(limit, @offset) if limit || @offset
    end

    private def build_select
      aggregate_expressions = select_expressions_snapshot
      select_everything = @columns.empty? && aggregate_expressions.empty?
      {select_everything ? implicit_select_columns : explicit_select_columns, aggregate_expressions}
    end

    # Every column of every table in the query, each table's primary key first.
    private def implicit_select_columns : Array(Expression::BaseColumn)
      selected = [] of Expression::BaseColumn
      @query_tables.each do |table_alias, info|
        table = info[:table]
        pk = table.primary_key
        selected << Expression::Column.new(pk, alias_name: table_alias) if pk
        table.columns.each_value do |column|
          selected << Expression::Column.new(column, alias_name: table_alias) unless pk && column.name == pk.name
        end
      end
      selected
    end

    # The selected columns under their custom or table alias, each once.
    private def explicit_select_columns : Array(Expression::BaseColumn)
      selected = @columns.map { |column| aliased(column, @column_aliases.try(&.[column]?)) }
      repeats?(selected) ? selected.uniq! { |column| selection_key(column) } : selected
    end

    # A column is selected once per alias.
    private def selection_key(column : Expression::BaseColumn) : {String?, Symbol}
      {column.alias_name, column.column.name}
    end

    # Whether a key repeats. A select names few columns, so comparing pairs is cheaper than the
    # hash `uniq!` builds, which is then only paid when there is something to remove.
    private def repeats?(columns : Array(Expression::BaseColumn)) : Bool
      return true if columns.size > 16
      index = 0
      while index < columns.size
        key = selection_key(columns.unsafe_fetch(index))
        other = index + 1
        while other < columns.size
          return true if selection_key(columns.unsafe_fetch(other)) == key
          other += 1
        end
        index += 1
      end
      false
    end

    private def from_source(table : CQL::Table, alias_name : String) : Expression::Table
      if table.is_a?(CQL::DerivedTable) && (statement = table.subquery)
        Expression::Subquery.new(statement, table, alias_name)
      else
        Expression::Table.new(table, alias_name)
      end
    end

    private def declare(name : Symbol, statement : Expression::Statement, table : CQL::Table? = nil) : Nil
      CQL::Identifier.validate!(name.to_s, "CTE name")
      raise ArgumentError.new("CTE #{name} is already declared") if @derived_tables.try &.has_key?(name)
      derived_tables[name] = table || CQL::DerivedTable.new(@schema, name, statement)
      ctes << Expression::Cte.new(name.to_s, statement)
    end

    private def find_schema_table(name : Symbol) : CQL::Table
      table = @derived_tables.try(&.[name]?) || @schema.tables[name]?
      raise ArgumentError.new("Table '#{name}' not found in schema") unless table
      table
    end

    # Builds aggregate expression with String alias in the inner Expression::Column
    private def build_aggr_expression(aggr : Symbol, column_name : Symbol | String)
      base_col = find_column(column_name)                           # Handles String/Symbol
      col_alias_str = find_alias_for_table(base_col.table.not_nil!) # Returns String
      # Create Expression::Column with String alias
      col_expr = Expression::Column.new(base_col, alias_name: col_alias_str)
      case aggr
      when :count then Expression::Count.new(col_expr)
      when :sum   then Expression::Sum.new(col_expr)
      when :avg   then Expression::Avg.new(col_expr)
      when :min   then Expression::Min.new(col_expr)
      when :max   then Expression::Max.new(col_expr)
      else
        raise ArgumentError.new "Invalid aggregate function #{aggr}"
      end
    end

    # Finds BaseColumn based on String or Symbol name (potentially qualified), uses String alias hint
    private def find_column(name_or_qualified : Symbol | String, table_alias_hint : String? = nil) : CQL::BaseColumn
      search_alias_str : String? = table_alias_hint
      # Store column name as String
      column_name_str : String? = nil

      case name_or_qualified
      when String
        parts = name_or_qualified.split('.', 2)
        if parts.size == 2
          search_alias_str = parts[0] # Use String alias directly
          # Store column name part as String
          column_name_str = parts[1]
        else
          # Unqualified string, treat as column name String
          column_name_str = name_or_qualified
          search_alias_str = table_alias_hint # Keep hint if provided
        end
      when Symbol
        # Convert Symbol to String immediately
        column_name_str = name_or_qualified.to_s
        search_alias_str = table_alias_hint # Keep hint if provided
      end

      unless column_name_str
        raise ArgumentError.new("Invalid column identifier: #{name_or_qualified}")
      end

      if search_alias_str
        # Specific table/alias requested (use String alias)
        table_info = @query_tables[search_alias_str]?
        raise ArgumentError.new "Table or alias '#{search_alias_str}' not found in query tables: #{@query_tables.keys.join(", ")}" unless table_info
        # Pass String column name
        column = find_column_in_table(table_info[:table], column_name_str)
        raise ArgumentError.new "Column '#{column_name_str}' not found in table/alias '#{search_alias_str}'" unless column
        column
      else
        # Search across all tables/aliases in the query (using String aliases)
        found_column : CQL::BaseColumn? = nil
        found_in_alias_str : String? = nil
        @query_tables.each do |current_alias_str, info|
          # Pass String column name
          if column = find_column_in_table(info[:table], column_name_str)
            if found_column
              # Ambiguous column name - use String aliases in error message
              raise ArgumentError.new "Column '#{column_name_str}' is ambiguous between '#{found_in_alias_str}' and '#{current_alias_str}'. Qualify with table alias (e.g., #{current_alias_str}.#{column_name_str})."
            end
            found_column = column
            found_in_alias_str = current_alias_str # Store String alias
          end
        end
        raise ArgumentError.new "Column '#{column_name_str}' not found in any tables/aliases: #{@query_tables.keys.join(", ")}" unless found_column
        found_column.not_nil!
      end
    end

    # Helper to find column in table using String comparison
    private def find_column_in_table(table : CQL::Table, column_name_str : String) : CQL::BaseColumn?
      # Iterate and compare strings
      table.columns.each_value do |col|
        return col if col.name.to_s == column_name_str
      end
      # Check primary key using string comparison
      pk = table.primary_key
      return pk if pk && pk.name.to_s == column_name_str
      nil # Not found
    end

    # --- Helper methods for inferred joins (Using String aliases internally) --- #

    # Accepts an Enumerable of {TableNameSym, AliasNameSym} pairs
    private def join_inferred(tables_with_aliases : Enumerable({Symbol, Symbol}), type : Expression::JoinType)
      # Iterate over the {table_name, alias_name} tuples
      tables_with_aliases.each do |target_table_name_sym, target_alias_sym|
        # Ensure alias is a Symbol (should be guaranteed by callers now)
        unless target_alias_sym.is_a?(Symbol)
          raise ArgumentError.new("Internal Error: Invalid alias type for table '#{target_table_name_sym}'. Expected Symbol, got #{target_alias_sym.class}")
        end

        target_table = find_schema_table(target_table_name_sym)
        # determine_alias expects Symbol? for alias, returns String
        final_alias_str = determine_alias(target_table_name_sym, target_alias_sym)
        ensure_alias_available(final_alias_str) # Expects String

        # First add the table to query_tables so it's available for relationship inferences
        @query_tables[final_alias_str] = {table: target_table, alias: final_alias_str}

        found_fk = find_foreign_key_link(target_table)
        # determine_join_sides returns String aliases
        left_alias_str, left_columns_sym, right_alias_str, right_columns_sym = determine_join_sides(found_fk, final_alias_str)
        # build_join_condition expects String aliases
        on_condition = build_join_condition(left_alias_str, left_columns_sym, right_alias_str, right_columns_sym)
        # add_join_expression creates the join expression
        add_join_expression(target_table, final_alias_str, type, on_condition)

        # The table stays in query_tables for subsequent operations like select
      end
      self
    end

    # Returns String aliases
    private def determine_join_sides(fk : ForeignKey, target_alias_str : String)
      fk_owning_table = fk.table
      fk_referenced_table_name_sym = fk.references_table

      begin
        owning_alias_str = find_alias_for_table(fk_owning_table) # Returns String
        # Referenced table name is Symbol, need to find its String alias
        referenced_alias_str = find_alias_for_table_name(fk_referenced_table_name_sym) # Returns String?
        if referenced_alias_str.nil?                                                   # Check if referenced is NOT already there
          other_alias_str = target_alias_str
        else # If referenced IS already there, owning must be the target
          owning_alias_str = target_alias_str
          other_alias_str = referenced_alias_str
        end
      rescue KeyError # Owning table not found, so it must be the target
        owning_alias_str = target_alias_str
        other_alias_str = find_alias_for_table_name(fk_referenced_table_name_sym) # Returns String?
      end

      unless owning_alias_str && other_alias_str
        raise "Internal Error: Could not resolve join side aliases for FK between '#{fk_owning_table.table_name}' and '#{fk_referenced_table_name_sym}' with target alias '#{target_alias_str}'. Query tables: #{@query_tables.keys}"
      end

      left_table_alias_str = owning_alias_str
      left_columns_sym = fk.columns # Array(Symbol)
      right_table_alias_str = other_alias_str
      right_columns_sym = fk.references_columns # Array(Symbol)

      # Return String aliases and Symbol column names
      {left_table_alias_str, left_columns_sym, right_table_alias_str, right_columns_sym}
    end

    # Finds the String alias for a given Table object
    private def find_alias_for_table(table_to_find : CQL::Table) : String
      rebound = @schema.binding.try(&.rebound_table(table_to_find))
      @query_tables.each do |alias_str, info|
        return alias_str if info[:table].same?(table_to_find) || info[:table].same?(rebound)
      end
      raise KeyError.new "Internal Error: Could not find String alias for table '#{table_to_find.table_name}' in query_tables: #{@query_tables.keys}"
    end

    # Finds the String alias for a given table name (Symbol)
    private def find_alias_for_table_name(table_name_to_find : Symbol) : String?
      @query_tables.each do |alias_str, info|
        return alias_str if info[:table].table_name == table_name_to_find
      end
      nil # Return nil if not found
    end

    # Takes String aliases and Symbol column names, creates Expression::Column with String alias
    private def build_join_condition(left_alias_str : String, left_columns_sym : Array(Symbol), right_alias_str : String, right_columns_sym : Array(Symbol))
      unless left_columns_sym.size == right_columns_sym.size
        raise "Internal Error: Mismatched column count in inferred join condition (#{left_columns_sym.size} vs #{right_columns_sym.size}) for aliases '#{left_alias_str}' and '#{right_alias_str}'"
      end

      conditions = left_columns_sym.zip(right_columns_sym).map do |left_col_sym, right_col_sym|
        # find_column expects String alias hint
        left_base_col = find_column(left_col_sym, left_alias_str)
        right_base_col = find_column(right_col_sym, right_alias_str)

        # Create Expression::Column with String alias
        Expression::CompareCondition.new(
          Expression::Column.new(left_base_col, alias_name: left_alias_str),
          "=",
          Expression::Column.new(right_base_col, alias_name: right_alias_str)
        )
      end

      conditions.reduce do |acc, cond|
        acc ? Expression::And.new(acc, cond) : cond
      end.not_nil!
    end

    # --- General Helper Methods (Using String Aliases) --- #

    # Parses Symbol | Hash input, returns {Symbol<TableName>, Symbol?<AliasName>}
    # Conversion to String alias happens in caller (`determine_alias`)
    private def parse_table_or_alias(item : Symbol | Hash(Symbol, Symbol)) : {Symbol, Symbol?}
      case item
      when Symbol
        {item, nil} # Return raw Symbols
      when Hash(Symbol, Symbol)
        if item.size != 1
          raise ArgumentError.new("Alias mapping must contain exactly one entry, got #{item}")
        end
        name, al = item.first
        {name, al} # Return raw Symbols
      else
        # Should not happen with current type signature
        raise ArgumentError.new("Invalid argument type for table/alias: #{item.class}")
      end
    end

    # Determines the String alias to use, converting Symbols using .to_s
    private def determine_alias(table_name_sym : Symbol, suggested_alias_sym : Symbol?) : String
      # Use suggested_alias if it's provided, otherwise fallback to table_name
      (suggested_alias_sym || table_name_sym).to_s
    end

    # Expects String alias
    private def ensure_alias_available(alias_to_check : String)
      if @query_tables.has_key?(alias_to_check)
        raise ArgumentError.new "Duplicate alias or table name '#{alias_to_check}' detected in join or from clause."
      end
    end

    # Expects String alias
    private def add_join_expression(table : CQL::Table, alias_name_str : String, type : Expression::JoinType, condition : Expression::Condition)
      # Create Expression::Table with String alias
      join_table_expr = Expression::Table.new(table, alias_name_str)
      joins << Expression::Join.new(type, join_table_expr, condition)
      # Store with String alias key
      @query_tables[alias_name_str] = {table: table, alias: alias_name_str} unless @query_tables.has_key?(alias_name_str)
    end

    # This seems okay, it deals with schema relationships (Symbols)
    private def find_foreign_key_link(target_table : CQL::Table) : ForeignKey
      possible_links = [] of ForeignKey
      existing_aliases_str = @query_tables.keys # Get String aliases

      @query_tables.each_value do |existing_info|
        existing_table = existing_info[:table]
        # Check FKs defined on the existing table referencing the target table (uses Symbol names)
        existing_table.foreign_keys.each do |foreign_key|
          if foreign_key.references_table == target_table.table_name
            possible_links << foreign_key
          end
        end
        # Check FKs defined on the target table referencing the existing table (uses Symbol names)
        target_table.foreign_keys.each do |foreign_key|
          if foreign_key.references_table == existing_table.table_name
            possible_links << foreign_key
          end
        end
      end

      case possible_links.size
      when 0
        raise ArgumentError.new "Could not find a foreign key relationship between '#{target_table.table_name}' and existing tables/aliases [#{existing_aliases_str.join(", ")}]"
      when 1
        possible_links.first
      else
        link_descriptions = possible_links.map do |foreign_key|
          "'#{foreign_key.table.table_name}' (#{foreign_key.columns.join(", ")}) -> '#{foreign_key.references_table}' (#{foreign_key.references_columns.join(", ")})"
        end.join("; ")
        raise ArgumentError.new "Ambiguous relationship found for '#{target_table.table_name}' with existing tables/aliases [#{existing_aliases_str.join(", ")}]. Possible links: #{link_descriptions}. Specify join condition explicitly."
      end
    end
  end
end
