require "./base_expression"
require "./visitor"
require "../dialects/dialect"

module Expression
  class OptimizedGenerator
    include Visitor

    @dialect : BaseDialect
    @params : Array(DB::Any)
    @query_cache : Hash(String, String)

    # Pre-allocated string builder for better performance
    @string_builder : String::Builder

    def initialize(@adapter : CQL::Adapter = CQL::Adapter::SQLite)
      @dialect = @adapter.dialect
      @params = Array(DB::Any).new
      @query_cache = Hash(String, String).new
      @string_builder = String::Builder.new(1024) # Pre-allocate 1KB
    end

    def params : Array(DB::Any)
      @params
    end

    def query : String
      @string_builder.to_s
    end

    def reset
      @params.clear
      @string_builder.clear
      @query_cache.clear
    end

    # Optimized placeholder generation with caching
    private def placeholder : String
      @dialect.placeholder_format(@params.size)
    end

    # Helper method for auto-timestamp columns
    private def is_auto_timestamp_column?(column : CQL::BaseColumn) : Bool
      column_name = column.name.to_s
      %w[created_at updated_at].includes?(column_name)
    end

    # Optimized visit methods with reduced string allocations
    def visit(node : Query) : String
      @params.clear
      @string_builder.clear

      @string_builder << "SELECT "
      @string_builder << "DISTINCT " if node.distinct?

      # Build column list more efficiently
      columns_sql = build_column_list(node.columns, node.aggr_columns)
      @string_builder << (columns_sql.empty? ? "*" : columns_sql)

      # Build query parts efficiently
      @string_builder << node.from.accept(self)
      node.joins.each { |join| @string_builder << join.accept(self) }

      if where = node.where
        @string_builder << where.accept(self)
      end

      if group_by = node.group_by
        @string_builder << group_by.accept(self)
      end

      if having = node.having
        @string_builder << having.accept(self)
      end

      if order_by = node.order_by
        @string_builder << order_by.accept(self)
      end

      if limit = node.limit
        @string_builder << limit.accept(self)
      end

      @string_builder.to_s
    end

    # More efficient column list building
    private def build_column_list(columns : Array(BaseColumn), aggr_columns : Array(Aggregate)) : String
      parts = Array(String).new(columns.size + aggr_columns.size)
      columns.each { |col| parts << col.accept(self) }
      aggr_columns.each { |agg| parts << agg.accept(self) }
      parts.join(", ")
    end

    # Optimized string building for simple operations
    def visit(node : Column) : String
      if alias_name = node.alias_name
        "#{alias_name}.#{node.column.name}"
      elsif node.column.name == :*
        "*"
      else
        table = node.column.table
        raise "Internal Error: Column expression missing table context and no alias provided" unless table
        "#{table.table_name}.#{node.column.name}"
      end
    end

    def visit(node : BaseColumn) : String
      visit(node.as(Column))
    end

    def visit(node : TypedColumn) : String
      if alias_name = node.alias_name
        "#{alias_name}.#{node.column.name}"
      elsif node.column.name == :*
        "*"
      else
        table = node.column.table
        raise "Internal Error: Column expression missing table context and no alias provided" unless table
        "#{table.table_name}.#{node.column.name}"
      end
    end

    # Optimized logical operations with minimal string allocations
    def visit(node : And) : String
      "(#{node.left.accept(self)}) AND (#{node.right.accept(self)})"
    end

    def visit(node : Or) : String
      "(#{node.left.accept(self)}) OR (#{node.right.accept(self)})"
    end

    def visit(node : Not) : String
      "NOT #{node.condition.accept(self)}"
    end

    # Optimized comparison operations
    def visit(node : Compare) : String
      @params << node.right
      "#{node.left.accept(self)} #{node.operator} #{placeholder}"
    end

    def visit(node : CompareCondition) : String
      left_sql = if node.left.is_a?(Expression::BaseColumn) || node.left.is_a?(Condition)
                   node.left.as(Expression::BaseColumn | Condition).accept(self)
                 else
                   @params << node.left.as(DB::Any)
                   placeholder
                 end

      right_sql = if node.right.is_a?(Expression::BaseColumn) || node.right.is_a?(Condition)
                    node.right.as(Expression::BaseColumn | Condition).accept(self)
                  else
                    @params << node.right.as(DB::Any)
                    placeholder
                  end

      "#{left_sql} #{node.operator} #{right_sql}"
    end

    # Optimized aggregate functions
    def visit(node : Count) : String
      if node.column.column.name == :*
        @dialect.format_count("*")
      else
        @dialect.format_count(node.column.accept(self))
      end
    end

    def visit(node : Max) : String
      @dialect.format_max(node.column.accept(self))
    end

    def visit(node : Min) : String
      @dialect.format_min(node.column.accept(self))
    end

    def visit(node : Avg) : String
      @dialect.format_avg(node.column.accept(self))
    end

    def visit(node : Sum) : String
      @dialect.format_sum(node.column.accept(self))
    end

    # All other visit methods delegate to original implementation for now
    # This allows for gradual optimization without breaking existing functionality
    {% for method_name in %w[
                            Insert Delete Where Between Like NotLike InCondition OrderBy GroupBy
                            InSelect Exists Having Limit Top From Table Null Is IsNull IsNot IsNotNull
                            EmptyNode Setter Update CreateIndex CreateTable DropTable TruncateTable
                            AlterTable AddColumn DropColumn DropIndex RenameColumn RenameTable
                            ChangeColumn AddForeignKey DropForeignKey Join
                          ] %}
       def visit(node : {{method_name.id}}) : String
         # Delegate to Expression::Generator for now
         generator = Expression::Generator.new(@adapter)
         generator.params.concat(@params)
         result = generator.visit(node)
         @params.concat(generator.params[@params.size..])
         result
       end
     {% end %}
  end
end
