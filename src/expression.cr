require "db"

module Expression
  abstract class Node
    abstract def accept(visitor : Visitor)
  end

  abstract class Condition < Node
  end

  class EmptyNode < Condition
    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class And < Condition
    property left : Condition
    property right : Condition

    def initialize(@left : Condition, @right : Condition)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Between < Condition
    property column : Column
    property low : DB::Any
    property high : DB::Any

    def initialize(@column : Column, @low : DB::Any, @high : DB::Any)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Column < Node
    getter column : Sql::Column

    def initialize(@column : Sql::Column)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Compare < Condition
    property left : Column
    property operator : String
    property right : DB::Any

    def initialize(@left : Column, @operator : String, @right : DB::Any)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class CompareCondition < Condition
    property left : Condition
    property operator : String
    property right : DB::Any

    def initialize(@left : Condition, @operator : String, @right : DB::Any)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Exists < Condition
    property sub_query : Query

    def initialize(@sub_query : Query)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class From < Node
    getter tables : Array(Sql::Table)

    def initialize(@tables : Array(Sql::Table))
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class GroupBy < Node
    property columns : Array(Column)

    def initialize(@columns : Array(Column) = [] of Sql::Column)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Having < Node
    property condition : Condition

    def initialize(@condition : Condition)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Count < Condition
    property column : Column

    def initialize(@column : Column)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Max < Condition
    property column : Column

    def initialize(@column : Column)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Min < Condition
    property column : Column

    def initialize(@column : Column)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Avg < Condition
    property column : Column

    def initialize(@column : Column)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Sum < Condition
    property column : Column

    def initialize(@column : Column)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class InCondition < Condition
    property column : Column
    property values : Array(DB::Any)

    def initialize(@column : Column, values : Array(T)) forall T
      @values = values.map { |v| v.as(DB::Any) }
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class InSelect < Condition
    property column : Column
    property query : Query

    def initialize(@column : Column, @query : Query)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Table < Node
    getter table : Sql::Table

    def initialize(@table : Sql::Table)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Insert < Node
    property table : Table
    property columns : Array(Column)
    property values : Array(String)

    def initialize(
      @table : Table,
      @columns : Array(Column),
      @values : Array(String)
    )
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  enum JoinType
    INNER
    LEFT
    RIGHT
    FULL
    CROSS
  end

  class Join < Node
    property table : Sql::Table
    property join_type : JoinType = JoinType::INNER
    property condition

    def initialize(@join_type : JoinType, @table : Table, @condition)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Like < Condition
    getter column : Column
    getter value : String

    def initialize(@column : Column, @value : String)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class NotLike < Condition
    getter column : Column
    getter value : String

    def initialize(@column : Column, @value : String)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Limit < Node
    getter limit : Int32?
    getter offset : Int32?

    def initialize(@limit : Int32?, @offset : Int32? = nil)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Not < Condition
    property condition : Condition

    def initialize(@condition : Condition)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Or < Condition
    property left : Condition
    property right : Condition

    def initialize(@left : Condition, @right : Condition)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  enum OrderDirection
    ASC
    DESC
  end

  class OrderBy < Node
    property orders : Hash(Column, OrderDirection)

    def initialize(@orders : Hash(Column, OrderDirection))
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Query < Node
    property columns : Array(Column)
    property from : From
    property where : Where? = nil
    property group_by : GroupBy? = nil
    property having : Having? = nil
    property order_by : OrderBy
    property joins : Array(Join) = [] of Join
    property limit : Limit? = nil
    property? distinct : Bool = false

    def initialize(
      @columns : Array(Column) = [] of Sql::Column,
      @from : From = [] of Sql::Table,
      @where : Where? = nil,
      @group_by : GroupBy? = nil,
      @having : Having? = nil,
      @order_by : OrderBy? = nil,
      @joins : Array(Join) = [] of Join,
      @limit : Limit? = nil,
      @distinct : Bool = false
    )
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Top < Node
    getter count : Int32

    def initialize(@count : Int32)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Where < Node
    property condition : Condition

    def initialize(@condition : Condition)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Null < Condition
    property column : Column?

    def initialize(@column : Column? = nil)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Is < Condition
    property column : Column
    property value : DB::Any

    def initialize(@column : Column, @value : DB::Any)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class IsNull < Condition
    property column : Column

    def initialize(@column : Column)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class IsNot < Condition
    property column : Column
    property value : DB::Any

    def initialize(@column : Column, @value : DB::Any)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class IsNotNull < Condition
    property column : Column

    def initialize(@column : Column)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  module Visitor
    abstract def visit(node : Query) : String
    abstract def visit(node : Insert) : String
    abstract def visit(node : Where) : String
    abstract def visit(node : Column) : String
    abstract def visit(node : And) : String
    abstract def visit(node : Or) : String
    abstract def visit(node : Not) : String
    abstract def visit(node : Compare) : String
    abstract def visit(node : Between) : String
    abstract def visit(node : Like) : String
    abstract def visit(node : NotLike) : String
    abstract def visit(node : InCondition) : String
    abstract def visit(node : OrderBy) : String
    abstract def visit(node : GroupBy) : String
    abstract def visit(node : InSelect) : String
    abstract def visit(node : Exists) : String
    abstract def visit(node : Having) : String
    abstract def visit(node : Limit) : String
    abstract def visit(node : Top) : String
    abstract def visit(node : Join) : String
    abstract def visit(node : From) : String
    abstract def visit(node : Table) : String
    abstract def visit(node : Null) : String
    abstract def visit(node : Is) : String
    abstract def visit(node : IsNull) : String
    abstract def visit(node : IsNot) : String
    abstract def visit(node : IsNotNull) : String
    abstract def visit(node : EmptyNode) : String
    abstract def visit(node : Count) : String
    abstract def visit(node : Max) : String
    abstract def visit(node : Min) : String
    abstract def visit(node : Avg) : String
    abstract def visit(node : Sum) : String
    abstract def visit(node : CompareCondition) : String
  end

  class Generator
    include Visitor

    def visit(node : Query) : String
      String::Builder.build do |sb|
        sb << "SELECT "
        sb << "DISTINCT " if node.distinct?
        node.columns.each_with_index do |column, i|
          sb << column.accept(self)
          sb << ", " if i < node.columns.size - 1
        end
        sb << node.from.accept(self)
        sb << node.where.try &.accept(self) if node.where
        sb << node.group_by.try &.accept(self) if node.group_by
        sb << node.having.try &.accept(self) if node.having
        sb << node.order_by.not_nil!.accept(self) if node.order_by
        sb << node.limit.try &.accept(self) if node.limit
      end
    end

    def visit(node : Insert) : String
      String::Builder.build do |sb|
        sb << "INSERT INTO "
        sb << node.table.name
        sb << " ("
        node.columns.each_with_index do |column, i|
          sb << column.column.name
          sb << ", " if i < node.columns.size - 1
        end
        sb << ") VALUES ("
        node.values.each_with_index do |value, i|
          sb << value
          sb << ", " if i < node.values.size - 1
        end
        sb << ")"
      end
    end

    def visit(node : Where) : String
      String::Builder.build do |sb|
        sb << " WHERE ("
        sb << node.condition.accept(self)
        sb << ")"
      end
    end

    def visit(node : Column) : String
      String::Builder.build do |sb|
        sb << node.column.table.not_nil!.name
        sb << "."
        sb << node.column.name
      end
    end

    def visit(node : And) : String
      String::Builder.build do |sb|
        sb << node.left.accept(self)
        sb << " AND "
        sb << node.right.accept(self)
      end
    end

    def visit(node : Or) : String
      String::Builder.build do |sb|
        sb << node.left.accept(self)
        sb << " OR "
        sb << node.right.accept(self)
      end
    end

    def visit(node : Not) : String
      String::Builder.build do |sb|
        sb << "NOT "
        sb << node.condition.accept(self)
      end
    end

    def visit(node : Compare) : String
      String::Builder.build do |sb|
        sb << node.left.accept(self)
        sb << " "
        sb << node.operator
        sb << " "
        sb << node.right.to_s
      end
    end

    def visit(node : CompareCondition) : String
      String::Builder.build do |sb|
        sb << node.left.accept(self)
        sb << " "
        sb << node.operator
        sb << " "
        sb << node.right.to_s
      end
    end

    def visit(node : Between) : String
      String::Builder.build do |sb|
        sb << node.column.accept(self)
        sb << " BETWEEN "
        sb << node.low.to_s
        sb << " AND "
        sb << node.high.to_s
      end
    end

    def visit(node : Like) : String
      String::Builder.build do |sb|
        sb << node.column.accept(self)
        sb << " LIKE "
        sb << node.value
      end
    end

    def visit(node : NotLike) : String
      String::Builder.build do |sb|
        sb << node.column.accept(self)
        sb << " NOT LIKE "
        sb << node.value
      end
    end

    def visit(node : InCondition) : String
      String::Builder.build do |sb|
        sb << node.column.accept(self)
        sb << " IN ("
        node.values.each_with_index do |value, i|
          sb << value.to_s
          sb << ", " if i < node.values.size - 1
        end
        sb << ")"
      end
    end

    def visit(node : OrderBy) : String
      return "" if node.orders.empty?
      String::Builder.build do |sb|
        sb << " ORDER BY "
        node.orders.each_with_index do |(column, direction), i|
          sb << column.accept(self)
          sb << " "
          sb << direction.to_s.upcase
          sb << ", " if i < node.orders.size - 1
        end
      end
    end

    def visit(node : GroupBy) : String
      return "" if node.columns.empty?

      String::Builder.build do |sb|
        sb << " GROUP BY "
        node.columns.each_with_index do |column, i|
          sb << column.accept(self)
          sb << ", " if i < node.columns.size - 1
        end
      end
    end

    def visit(node : InSelect) : String
      String::Builder.build do |sb|
        sb << node.column.accept(self)
        sb << " IN ("
        sb << node.query.accept(self)
        sb << ")"
      end
    end

    def visit(node : Exists) : String
      String::Builder.build do |sb|
        sb << "EXISTS ("
        sb << node.sub_query.accept(self)
        sb << ")"
      end
    end

    def visit(node : Having) : String
      String::Builder.build do |sb|
        sb << " HAVING "
        sb << node.condition.accept(self)
      end
    end

    def visit(node : Join) : String
      String::Builder.build do |sb|
        sb << " "
        sb << node.join_type.to_s
        sb << " JOIN "
        sb << node.table.name
        sb << " ON "
        sb << node.condition.accept(self)
      end
    end

    def visit(node : Limit) : String
      String::Builder.build do |sb|
        sb << " LIMIT "
        sb << node.limit.to_s
        sb << " OFFSET " << node.offset.to_s if node.offset
      end
    end

    def visit(node : Top) : String
      String::Builder.build do |sb|
        sb << "TOP "
        sb << node.count.to_s
      end
    end

    def visit(node : From) : String
      String::Builder.build do |sb|
        sb << " FROM "
        node.tables.each_with_index do |table, i|
          sb << table.name
          sb << " AS " << table.as_name if table.as_name
          sb << ", " if i < node.tables.size - 1
        end
      end
    end

    def visit(node : Table) : String
      node.table.name
    end

    def visit(node : Null) : String
      String::Builder.build do |sb|
        sb << "NULL"
        if column = node.column
          sb << column.accept(self)
        end
      end
    end

    def visit(node : Is) : String
      String::Builder.build do |sb|
        sb << node.column.accept(self)
        sb << " IS "
        sb << node.value.to_s
      end
    end

    def visit(node : IsNull) : String
      String::Builder.build do |sb|
        sb << node.column.accept(self)
        sb << " IS NULL"
      end
    end

    def visit(node : IsNot) : String
      String::Builder.build do |sb|
        sb << node.column.accept(self)
        sb << " IS NOT "
        sb << node.value.to_s
      end
    end

    def visit(node : IsNotNull) : String
      String::Builder.build do |sb|
        sb << node.column.accept(self)
        sb << " IS NOT NULL"
      end
    end

    def visit(node : EmptyNode) : String
      ""
    end

    def visit(node : Count) : String
      String::Builder.build do |sb|
        sb << "COUNT("
        sb << node.column.accept(self)
        sb << ")"
      end
    end

    def visit(node : Max) : String
      String::Builder.build do |sb|
        sb << "MAX("
        sb << node.column.accept(self)
        sb << ")"
      end
    end

    def visit(node : Min) : String
      String::Builder.build do |sb|
        sb << "MIN("
        sb << node.column.accept(self)
        sb << ")"
      end
    end

    def visit(node : Avg) : String
      String::Builder.build do |sb|
        sb << "AVG("
        sb << node.column.accept(self)
        sb << ")"
      end
    end

    def visit(node : Sum) : String
      String::Builder.build do |sb|
        sb << "SUM("
        sb << node.column.accept(self)
        sb << ")"
      end
    end
  end

  class ConditionBuilder
    getter condition : Condition

    def initialize(@condition : Condition = EmptyNode.new)
    end

    def &(other : ConditionBuilder)
      combine(other, And)
    end

    def |(other : ConditionBuilder)
      combine(other, Or)
    end

    def and(other : ConditionBuilder)
      combine(other, And)
    end

    def or(other : ConditionBuilder)
      combine(other, Or)
    end

    private def combine(other : ConditionBuilder, combinator : Class)
      ConditionBuilder.new(combinator.new(@condition, other.condition))
    end

    macro method_missing(call)
      def {{call.name.id}}
        find_column({{call.name.id.stringify}})
      end
    end
  end

  class WhereBuilder
    @columns : Array(Column)

    def initialize(sql_cols : Array(Sql::Column))
      @columns = sql_cols.map { |col| Column.new(col) }
    end

    def exists?(sub_query : Sql::Query)
      ConditionBuilder.new(Exists.new(sub_query.build))
    end

    # Generate methods for each column
    macro method_missing(call)
      def {{call.name.id}}
        find_column({{call.name.id.stringify}})
      end
    end

    private def find_column(name : String)
      @columns.each do |column|
        return ColumnBuilder.new(column) if column.column.name.to_s == name
      end

      raise "Column not found: #{name}"
    end
  end

  class ColumnBuilder
    getter column : Column

    def initialize(@column : Column)
    end

    def ==(value : DB::Any)
      compare("=", value)
    end

    def eq(value : DB::Any)
      compare("=", value)
    end

    def !=(value : DB::Any)
      compare("!=", value)
    end

    def neq(value : DB::Any)
      compare("!=", value)
    end

    def <(value : DB::Any)
      compare("<", value)
    end

    def <=(value : DB::Any)
      compare("<=", value)
    end

    def >(value : DB::Any)
      compare(">", value)
    end

    def >=(value : DB::Any)
      compare(">=", value)
    end

    def in(values : Array(DB::Any))
      ConditionBuilder.new(InCondition.new(@column, values))
    end

    def not_in(values : Array(DB::Any))
      ConditionBuilder.new(Not.new(InCondition.new(@column, values)))
    end

    def in(sub_query : Query)
      ConditionBuilder.new(InSelect.new(@column, sub_query.build))
    end

    def not_in(sub_query : Query)
      ConditionBuilder.new(InSelect.new(Not.new(@column, sub_query.build)))
    end

    def like(pattern : DB::Any)
      ConditionBuilder.new(Like.new(@column, pattern))
    end

    def not_like(pattern : DB::Any)
      ConditionBuilder.new(NotLike.new(@column, pattern))
    end

    def null
      ConditionBuilder.new(IsNull.new(@column))
    end

    def not_null
      ConditionBuilder.new(IsNotNull.new(@column))
    end

    private def compare(operator : String, value : DB::Any)
      ConditionBuilder.new(Compare.new(@column, operator, value))
    end
  end

  class HavingBuilder
    @columns : Array(Column)

    def initialize(sql_cols : Array(Sql::Column))
      @columns = sql_cols.map { |col| Column.new(col) }
    end

    def count(column : Symbol)
      aggregate(Count, column)
    end

    def max(column : Symbol)
      aggregate(Max, column)
    end

    def min(column : Symbol)
      aggregate(Min, column)
    end

    def avg(column : Symbol)
      aggregate(Avg, column)
    end

    def sum(column : Symbol)
      aggregate(Sum, column)
    end

    private def aggregate(klass, column : Symbol)
      col = find_column(column.to_s)
      AggregateBuilder.new(klass.new(col))
    end

    private def find_column(name : String)
      @columns.each do |column|
        return column if column.column.name.to_s == name
      end

      raise "Column not found: #{name}"
    end
  end

  class AggregateBuilder
    getter aggregate_function : Condition

    def initialize(@aggregate_function : Condition)
    end

    def >(value : DB::Any)
      ConditionBuilder.new(CompareCondition.new(@aggregate_function, ">", value))
    end

    def <(value : DB::Any)
      ConditionBuilder.new(CompareCondition.new(@aggregate_function, "<", value))
    end

    def >=(value : DB::Any)
      ConditionBuilder.new(CompareCondition.new(@aggregate_function, ">=", value))
    end

    def <=(value : DB::Any)
      ConditionBuilder.new(CompareCondition.new(@aggregate_function, "<=", value))
    end

    def ==(value : DB::Any)
      ConditionBuilder.new(CompareCondition.new(@aggregate_function, "=", value))
    end

    def !=(value : DB::Any)
      ConditionBuilder.new(CompareCondition.new(@aggregate_function, "!=", value))
    end
  end
end
