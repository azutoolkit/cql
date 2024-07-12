require "./visitor"

module Sql
  class Generator
    include Visitor

    def visit(node : SelectStatement) : String
      String::Builder.build do |sb|
        sb << "SELECT"
        sb << " DISTINCT" if node.is_distinct
        sb << " #{node.columns.map(&.accept(self)).join(", ")} FROM #{node.table}"
        sb << " #{node.where_clause.not_nil!.accept(self)}" unless node.where_clause.nil?
        sb << " #{node.group_by_clause.not_nil!.accept(self)}" unless node.group_by_clause.nil?
        sb << node.order_by_clause.not_nil!.accept(self) unless node.order_by_clause.nil?
      end
    end

    def visit(node : InsertStatement) : String
      "INSERT INTO #{node.table} (#{node.columns.join(", ")}) VALUES (#{node.values.join(", ")})"
    end

    def visit(node : WhereClause) : String
      "WHERE (#{node.condition.accept(self)})"
    end

    def visit(node : Column) : String
      String::Builder.build do |sb|
        sb << "COUNT(" if node.is_count?
        sb << "DISTINCT " if node.is_distinct?
        sb << node.name
        sb << ")" if node.is_count?
        sb << " AS #{node.alias_name}" if node.alias_name
      end
    end

    def visit(node : AndCondition) : String
      "#{node.left.accept(self)} AND #{node.right.accept(self)}"
    end

    def visit(node : OrCondition) : String
      "#{node.left.accept(self)} OR #{node.right.accept(self)}"
    end

    def visit(node : NotCondition) : String
      "NOT #{node.condition.accept(self)}"
    end

    def visit(node : ComparisonCondition) : String
      "#{node.left} #{node.operator} #{node.right}"
    end

    def visit(node : BetweenCondition) : String
      "#{node.column} BETWEEN #{node.low} AND #{node.high}"
    end

    def visit(node : LikeCondition) : String
      "#{node.column} LIKE '#{node.pattern}'"
    end

    def visit(node : InCondition) : String
      "#{node.column} IN (#{node.values.join(", ")})"
    end

    def visit(node : IsNullCondition) : String
      "#{node.column} IS NULL"
    end

    def visit(node : IsNotNullCondition) : String
      "#{node.column} IS NOT NULL"
    end

    def visit(node : OrderByClause) : String
      orders = node.orders.map { |order| "#{order[0]} #{order[1]}" }.join(", ")
      "ORDER BY #{orders}"
    end

    def visit(node : GroupByClause) : String
      return "" if node.columns.empty?

      "GROUP BY #{node.columns.join(",")} "
    end

    def visit(node : InSelectCondition) : String
      "#{node.column} IN (#{node.sub_query.accept(self)})"
    end

    def visit(node : NotInSelectCondition) : String
      "#{node.column} NOT IN (#{node.sub_query.accept(self)})"
    end
  end
end
