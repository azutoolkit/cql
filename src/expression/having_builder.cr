require "./expressions"
require "./condition_builder"  # Needed for ConditionBuilder
require "./aggregator_builder" # Needed for AggregateBuilder
require "../query"             # Needed for Query::QueryTableInfo
require "../base_column"       # Needed for BaseColumn
require "../table"             # Needed for Table

module Expression
  class HavingBuilder
    # Store the query's table context (alias => {table, alias})
    @query_tables : Hash(String, CQL::Query::QueryTableInfo)

    # Accept the query table context in the initializer
    def initialize(@query_tables : Hash(String, CQL::Query::QueryTableInfo))
    end

    def count(column : Symbol | String)
      aggregate(Count, column)
    end

    def max(column : Symbol | String)
      aggregate(Max, column)
    end

    def min(column : Symbol | String)
      aggregate(Min, column)
    end

    def avg(column : Symbol | String)
      aggregate(Avg, column)
    end

    def sum(column : Symbol | String)
      aggregate(Sum, column)
    end

    # Find column using query context and create aggregate with aliased Expression::Column
    private def aggregate(klass, column_name_or_qualified : Symbol | String)
      col_expr = find_column(column_name_or_qualified) # find_column now returns Expression::Column
      AggregateBuilder.new(klass.new(col_expr))
    end

    # Find column across all tables in the context, create Expression::Column with alias
    private def find_column(name_or_qualified : Symbol | String) : Expression::Column
      search_alias : String? = nil
      # Store column name as String
      column_name_str : String? = nil

      case name_or_qualified
      when String
        parts = name_or_qualified.split('.', 2)
        if parts.size == 2
          search_alias = parts[0]
          # Store as String
          column_name_str = parts[1]
        else
          # Store as String
          column_name_str = name_or_qualified
        end
      when Symbol
        # Convert symbol to string immediately
        column_name_str = name_or_qualified.to_s
      end

      unless column_name_str
        raise ArgumentError.new("Invalid column identifier in HavingBuilder: #{name_or_qualified}")
      end

      if search_alias
        # Specific table/alias requested
        table_info = @query_tables[search_alias]?
        raise ArgumentError.new "Table or alias '#{search_alias}' not found in query tables (HavingBuilder)" unless table_info
        # Pass String column name
        base_col = find_column_in_cql_table(table_info[:table], column_name_str)
        raise ArgumentError.new "Column '#{column_name_str}' not found in table/alias '#{search_alias}' (HavingBuilder)" unless base_col
        Expression::Column.new(base_col, alias_name: search_alias) # Use the String alias
      else
        # Search across all tables/aliases
        found_column_expr : Expression::Column? = nil
        found_in_alias : String? = nil
        @query_tables.each do |current_alias, info|
          # Pass String column name
          if base_col = find_column_in_cql_table(info[:table], column_name_str)
            if found_column_expr
              raise ArgumentError.new "Column '#{column_name_str}' is ambiguous between '#{found_in_alias}' and '#{current_alias}' in HavingBuilder. Qualify with table alias."
            end
            # Create Expression::Column with the String alias
            found_column_expr = Expression::Column.new(base_col, alias_name: current_alias)
            found_in_alias = current_alias
          end
        end
        raise ArgumentError.new "Column '#{column_name_str}' not found in any query tables (HavingBuilder)" unless found_column_expr
        found_column_expr.not_nil!
      end
    end

    # Helper to find a column (including PK) within a specific CQL::Table object using String comparison
    private def find_column_in_cql_table(table : CQL::Table, column_name_str : String) : CQL::BaseColumn?
      # Iterate and compare strings
      table.columns.each_value do |col|
        return col if col.name.to_s == column_name_str
      end
      # Check primary key using string comparison
      pk = table.primary
      return pk if pk && pk.name.to_s == column_name_str
      nil # Not found
    end
  end
end
