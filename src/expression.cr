require "./expressions/node"
require "./expressions/condition"
require "./expressions/column"
require "./expressions/*"

module Expression
   class Node
     def accept(visitor : Sql::Visitor)
  end

   class Condition < Node
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

  class Column
    getter column : Sql::Column

    def initialize(@column : Sql::Column)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Comparare < Condition
    property left : String
    property operator : String
    property right : DB::Any

    def initialize(@left : String, @operator : String, @right : DB::Any)
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

    def initialize(*tables : Table)
      @tables = tables
    end

    def accept(visitor)
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

  class InCondition < Condition
    property column : Column
    property values : Array(DB::Any)

    def initialize(@column : Column, @values : Array(DB::Any))
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class InSelect < Condition
    property column : Column
    property select : Select

    def initialize(@column : Column, @select : Select)
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

  class IsNull < Condition
    property column : Column

    def initialize(@column : Column)
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
    property condition : Condition

    def initialize(@join_type : JoinType, @table : Table, @condition : Condition)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Like
    getter column : Column
    getter value : String

    def initialize(@column : Column, @value : String)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Limit < Node
    getter limit : Int32
    getter offset : Int32?

    def initialize(@limit : Int32, @offset : Int32? = nil)
    end

    def accept(visitor)
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

  class Query < Node
    property columns : Array(Sql::Column)
    property table : Array(Sql::Table)
    property where_clause : Where?
    property group_by : GroupBy?
    property having : Having?
    property order_by : OrderBy?
    property joins : Array(Join)
    property limit : Int32?
    property offset : Int32?

    def initialize(
      @columns : Array(Sql::Column),
      @table : Array(Sql::Table),
      @where_clause : Where? = nil,
      @group_by : GroupBy? = nil,
      @having : Having? = nil,
      @order_by : OrderBy? = nil,
      @joins : Array(Join) = [] of Join,
      @limit : Int32? = nil,
      @offset : Int32? = nil
    )
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  struct Top
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
    abstract def visit(node : InCondition) : String
    abstract def visit(node : IsNull) : String
    abstract def visit(node : OrderBy) : String
    abstract def visit(node : GroupBy) : String
    abstract def visit(node : InSelect) : String
    abstract def visit(node : Exists) : String
    abstract def visit(node : Having) : String
    abstract def visit(node : InnerJoin) : String
    abstract def visit(node : Limit) : String
    abstract def visit(node : Top) : String
    abstract def visit(node : Join) : String
    abstract def visit(node : From) : String
  end

  class Generator
    include Visitor

    def visit(node : Query) : String
      String::Builder.build do |sb|
        sb << "SELECT "
        node.columns.each_with_index do |column, i|
          sb << column.accept(self)
          sb << ", " if i < node.columns.size - 1
        end
        sb << " "
        sb << node.table.accept(self)
        node.joins.each do |join|
          sb << join.accept(self)
        end
        sb << node.where_clause.accept(self) if node.where_clause
        sb << node.group_by.accept(self) if node.group_by
        sb << node.having.accept(self) if node.having
        sb << node.order_by.accept(self) if node.order_by
        sb << node.limit.accept(self) if node.limit
        sb << node.offset.accept(self) if node.offset
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

    def visit(node : Where) : String
      String::Builder.build do |sb|
        sb << "WHERE "
        sb << node.condition.accept(self)
      end
    end

    def visit(node : Column) : String
      String::Builder.build do |sb|
        sb << node.column.table.name
        sb << "."
        sb << node.column.name
        sb << " AS " << node.column.as_name if node.column.as_name
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
        sb << node.left
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

    def visit(node : IsNull) : String
      String::Builder.build do |sb|
        sb << node.column.accept(self)
        sb << " IS NULL"
      end
    end

    def visit(node : OrderBy) : String
      String::Builder.build do |sb|
        sb << "ORDER BY "
        node.columns.each_with_index do |column, i|
          sb << column.accept(self)
          sb << " DESC" if node.descending
          sb << ", " if i < node.columns.size - 1
        end
      end
    end

    def visit(node : GroupBy) : String
      String::Builder.build do |sb|
        sb << "GROUP BY "
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
        sb << node.select.accept(self)
        sb << ")"
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
        sb << "HAVING "
        sb << node.condition.accept(self)
    end

    def visit(node : InnerJoin) : String
      String::Builder.build do |sb|
        sb << "INNER JOIN "
        sb << node.table.name
        sb << " ON "
        sb << node.condition.accept(self)
      end
    end

    def visit(node : Limit) : String
      String::Builder.build do |sb|
        sb << "LIMIT "
        sb << node.limit.to_s
        sb << " OFFSET " << node.offset.to_s if node.offset
    end

    def visit(node : Top) : String
      String::Builder.build do |sb|
        sb << "TOP "
        sb << node.count.to_s
      end
    end

    def visit(node : Join) : String
      String::Builder.build do |sb|
        sb << "JOIN "
        sb << node.table.name
        sb << " ON "
        sb << node.condition.accept(self)
      end
    end

    def visit(node : From) : String
      String::Builder.build do |sb|
        sb << "FROM "
        node.tables.each_with_index do |table, i|
        sb << table.name
        sb << " AS " << table.as_name
        sb << " " if i < node.tables.size - 1
      end
    end
  end
end
