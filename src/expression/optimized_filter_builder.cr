require "./base_expression"
require "./optimized_condition_builder"
require "./query_structure"

module Expression
  class FilterBuilder
    # Use a more memory-efficient table storage pattern
    @tables : Hash(String, Expression::Table)

    def initialize(query_tables : Hash(String, CQL::Query::QueryTableInfo))
      # Pre-allocate hash size for better performance
      @tables = Hash(String, Expression::Table).new(initial_capacity: query_tables.size)

      query_tables.each do |alias_str, table_info|
        @tables[alias_str] = Expression::Table.new(table_info[:table], alias_str)
      end
    end

    # Optimized exists? method
    def exists?(sub_query : CQL::Query) : ConditionBuilder
      ConditionBuilder.new(Exists.new(sub_query.build))
    end

    # Direct table access with caching for better performance
    def table(name : String) : Expression::Table
      @tables[name]? || raise "Table '#{name}' not found in filter context. Available tables: #{@tables.keys.join(", ")}"
    end

    def table(name : Symbol) : Expression::Table
      table(name.to_s)
    end

    # More efficient table lookup using a method cache pattern
    private macro cache_table_method(name)
      @{{name.id}}_table : Expression::Table?

      private def {{name.id}}_table_cached : Expression::Table
        @{{name.id}}_table ||= (@tables[{{name.stringify}}]? ||
          raise "Table '{{name.id}}' not found in filter context. Available tables: #{@tables.keys.join(", ")}")
      end
    end

    # Generate optimized methods for each table using method_missing
    macro method_missing(call)
      def {{call.name.id}} : Expression::Table
        table_name = {{call.name.stringify}}
        @tables[table_name]? || raise "Table '#{table_name}' not found in filter context. Available tables: #{@tables.keys.join(", ")}"
      end
    end

    # Utility methods for complex filtering
    def any_table_matches(& : Expression::Table -> ConditionBuilder) : ConditionBuilder?
      conditions = [] of ConditionBuilder
      @tables.each_value do |table|
        if condition = yield(table)
          conditions << condition
        end
      end

      return nil if conditions.empty?
      return conditions.first if conditions.size == 1

      # Combine all conditions with OR
      conditions.reduce { |acc, cond| acc | cond }
    end

    def all_tables_match(& : Expression::Table -> ConditionBuilder) : ConditionBuilder?
      conditions = [] of ConditionBuilder
      @tables.each_value do |table|
        if condition = yield(table)
          conditions << condition
        end
      end

      return nil if conditions.empty?
      return conditions.first if conditions.size == 1

      # Combine all conditions with AND
      conditions.reduce { |acc, cond| acc & cond }
    end
  end
end
