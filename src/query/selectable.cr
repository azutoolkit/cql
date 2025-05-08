# Handles methods related to selecting columns.
module Selectable
  # Specifies the columns to select.
  # - **@param** fields [Hash(Symbol, Array(Symbol) | Symbol)] The columns to select
  # - **@return** [Query] The query object
  #
  # **Example**
  #
  # ```
  # query.from(:users, :address).select(users: [:name, :age], address: [:city, :state])
  # => "SELECT users.name, users.age, address.city, address.state FROM users, address"
  # ```
  #
  # ** Example with aggregates **
  #
  # ```
  # query.from(:users).select(count: :id)
  # => "SELECT COUNT(id) FROM users"
  # ```
  #
  # ** Example with aliases **
  #
  # ```
  # query.from(:users, :orders).select(users: [:name, :age], orders: [:total_amount, :status])
  # => "SELECT users.name, users.age, orders.total_amount, orders.status FROM users, orders"
  # ```
  def select(**fields : Hash(String | Symbol, Array(Symbol) | Symbol))
    fields.each do |key, value|
      # Convert Symbol key to String for consistency
      alias_or_aggr_str = key.is_a?(Symbol) ? key.to_s : key

      if [:count, :sum, :avg, :min, :max].includes?(key) && value.is_a?(Symbol)
        # Aggregates handle alias lookup internally now via build_aggr_expression
        # Use original Symbol key here for aggregate type
        @aggr_columns << build_aggr_expression(key, value) # Pass Symbol for aggr type
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
        @aggr_columns << build_aggr_expression(key, value)
      else
        if value.is_a?(Array(Symbol))
          value.map { |name| @columns << find_column(name, key.to_s) }
        else
          @columns << find_column(value, key.to_s)
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
  def select(*columns : Symbol | String)
    added_cols = columns.map do |col_name_or_qualified|
      # find_column handles String/Symbol, ambiguity check, returns BaseColumn
      find_column(col_name_or_qualified)
    end
    @columns.concat(added_cols)
    @columns.uniq!(&.object_id)
    self
  end

  # Sets the distinct flag to true.
  #
  # **Example** Setting the distinct flag to true
  #
  # ```
  # query.distinct
  # ```
  def distinct
    @distinct = true
    self
  end
end
