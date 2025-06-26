require "./base_expression"
require "./optimized_condition_builder"
require "./optimized_aggregator_builder"
require "./aggregate_functions"

module Expression
  class HavingBuilder
    # Store the query's table context more efficiently
    @query_tables : Hash(String, CQL::Query::QueryTableInfo)
    @column_cache : Hash(String, Expression::Column)

    def initialize(@query_tables : Hash(String, CQL::Query::QueryTableInfo))
      # Pre-allocate cache for better performance
      @column_cache = Hash(String, Expression::Column).new
    end

    # Optimized aggregate functions with compile-time generation
    {% for func in %w[count max min avg sum] %}
      def {{func.id}}(column : Symbol | String) : AggregateBuilder
        aggregate({{func.capitalize.id}}, column)
      end
    {% end %}

    # Efficient column finding with caching
    private def find_column(name_or_qualified : Symbol | String) : Expression::Column
      cache_key = name_or_qualified.to_s
      return @column_cache[cache_key] if @column_cache.has_key?(cache_key)

      search_alias : String? = nil
      column_name_str = case name_or_qualified
                        when String
                          parts = name_or_qualified.split('.', 2)
                          if parts.size == 2
                            search_alias = parts[0]
                            parts[1]
                          else
                            name_or_qualified
                          end
                        when Symbol
                          name_or_qualified.to_s
                        else
                          raise ArgumentError.new("Invalid column identifier: #{name_or_qualified}")
                        end

      column_expr = if search_alias
                      # Specific table/alias requested
                      find_column_in_specific_table(search_alias, column_name_str)
                    else
                      # Search across all tables/aliases
                      find_column_across_tables(column_name_str)
                    end

      # Cache the result for future lookups
      @column_cache[cache_key] = column_expr
      column_expr
    end

    private def find_column_in_specific_table(search_alias : String, column_name_str : String) : Expression::Column
      table_info = @query_tables[search_alias]?
      raise ArgumentError.new "Table or alias '#{search_alias}' not found in query tables (HavingBuilder)" unless table_info

      base_col = find_column_in_cql_table(table_info[:table], column_name_str)
      raise ArgumentError.new "Column '#{column_name_str}' not found in table/alias '#{search_alias}' (HavingBuilder)" unless base_col

      Expression::Column.new(base_col, alias_name: search_alias)
    end

    private def find_column_across_tables(column_name_str : String) : Expression::Column
      found_column_expr : Expression::Column? = nil
      found_in_alias : String? = nil

      @query_tables.each do |current_alias, info|
        if base_col = find_column_in_cql_table(info[:table], column_name_str)
          if found_column_expr
            raise ArgumentError.new "Column '#{column_name_str}' is ambiguous between '#{found_in_alias}' and '#{current_alias}' in HavingBuilder. Qualify with table alias."
          end
          found_column_expr = Expression::Column.new(base_col, alias_name: current_alias)
          found_in_alias = current_alias
        end
      end

      raise ArgumentError.new "Column '#{column_name_str}' not found in any query tables (HavingBuilder)" unless found_column_expr
      found_column_expr.not_nil!
    end

    # Create aggregate with optimized column lookup
    private def aggregate(klass, column_name_or_qualified : Symbol | String) : AggregateBuilder
      col_expr = find_column(column_name_or_qualified)
      AggregateBuilder.new(klass.new(col_expr))
    end

    # Optimized column lookup in CQL table with early exit
    private def find_column_in_cql_table(table : CQL::Table, column_name_str : String) : CQL::BaseColumn?
      # Check primary key first (common case)
      pk = table.primary
      return pk if pk && pk.name.to_s == column_name_str

      # Then check regular columns
      table.columns.each_value do |col|
        return col if col.name.to_s == column_name_str
      end

      nil # Not found
    end

    # Utility methods for complex having conditions
    def any_aggregate_matches(& : AggregateBuilder -> ConditionBuilder) : ConditionBuilder?
      # Helper for building complex HAVING clauses with multiple aggregates
      conditions = [] of ConditionBuilder

      %w[count max min avg sum].each do |func|
        @query_tables.each_value do |info|
          info[:table].columns.each_value do |col|
            agg = AggregateBuilder.new(Expression.const_get(func.capitalize).new(Expression::Column.new(col)))
            if condition = yield(agg)
              conditions << condition
            end
          end
        end
      end

      return nil if conditions.empty?
      conditions.reduce { |acc, cond| acc | cond }
    end
  end
end
