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
    getter left : Condition
    getter right : Condition

    def initialize(@left : Condition, @right : Condition)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Between < Condition
    getter column : Column
    getter low : DB::Any
    getter high : DB::Any

    def initialize(@column : Column, @low : DB::Any, @high : DB::Any)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Column < Node
    getter column : CQL::BaseColumn

    def initialize(@column : CQL::BaseColumn)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Compare < Condition
    getter left : Column
    getter operator : String
    getter right : DB::Any

    def initialize(@left : Column, @operator : String, @right : DB::Any)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class CompareCondition < Condition
    getter left : Condition | Column | DB::Any
    getter operator : String
    getter right : Condition | Column | DB::Any

    def initialize(@left : Condition | Column | DB::Any, @operator : String, @right : Condition | Column | DB::Any)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Exists < Condition
    getter sub_query : Query

    def initialize(@sub_query : Query)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class From < Node
    getter tables : Array(CQL::Table)

    def initialize(@tables : Array(CQL::Table))
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class GroupBy < Node
    getter columns : Array(Column)

    def initialize(@columns : Array(Column) = [] of CQL::BaseColumn)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class CreateTable < Node
    getter table : CQL::Table

    def initialize(@table : CQL::Table)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class DropTable < Node
    getter table : CQL::Table

    def initialize(@table : CQL::Table)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class TruncateTable < Node
    getter table : CQL::Table

    def initialize(@table : CQL::Table)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class AlterTable < Node
    getter table : CQL::Table
    getter action : AlterAction

    def initialize(@table : CQL::Table, @action : AlterAction)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  abstract class AlterAction
    abstract def accept(visitor : Visitor)
  end

  class AddColumn < AlterAction
    getter column : CQL::BaseColumn

    def initialize(@column : CQL::BaseColumn)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class DropColumn < AlterAction
    getter column_name : String

    def initialize(@column_name : String)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class RenameColumn < AlterAction
    getter column : CQL::BaseColumn
    getter new_name : String
    getter old_name : String
    getter table_name : String

    def initialize(@column : CQL::BaseColumn, @new_name : String)
      @old_name = @column.name.to_s
      @table_name = @column.table.not_nil!.table_name.to_s
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class ChangeColumn < AlterAction
    getter column : CQL::BaseColumn
    getter type : CQL::Any
    getter table_name : String

    def initialize(@column : CQL::BaseColumn, @type : CQL::Any)
      @table_name = @column.table.not_nil!.table_name.to_s
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class RenameTable < AlterAction
    getter table : CQL::Table
    getter new_name : String

    def initialize(@table : CQL::Table, @new_name : String)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class AddForeignKey < AlterAction
    getter fk : CQL::ForeignKey

    def initialize(@fk : CQL::ForeignKey)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  alias AddIndex = CreateIndex

  class CreateIndex < AlterAction
    getter index : CQL::Index

    def initialize(@index : CQL::Index)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class DropIndex < AlterAction
    getter index : CQL::Index

    def initialize(@index : CQL::Index)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Having < Node
    getter condition : Condition

    def initialize(@condition : Condition)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Count < Condition
    getter column : Column

    def initialize(@column : Column)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Max < Condition
    getter column : Column

    def initialize(@column : Column)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Min < Condition
    getter column : Column

    def initialize(@column : Column)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Avg < Condition
    getter column : Column

    def initialize(@column : Column)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Sum < Condition
    getter column : Column

    def initialize(@column : Column)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class InCondition < Condition
    getter column : Column
    getter values : Array(DB::Any)

    def initialize(@column : Column, values : Array(T)) forall T
      @values = values.map { |v| v.as(DB::Any) }
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class InSelect < Condition
    getter column : Column
    getter query : Query

    def initialize(@column : Column, @query : Query)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Table < Node
    getter table : CQL::Table

    def initialize(@table : CQL::Table)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end

    macro method_missing(call)
      def {{call.name.id}} : ColumnBuilder
        @table.{{call.name.id}}.expression
      end
    end
  end

  class Insert < Node
    getter table : Table
    getter columns : Set(Column) = Set(Column).new
    getter values : Array(Array(DB::Any)) = [] of Array(DB::Any)
    getter back : Array(Column) = Array(Column).new
    getter query : Query?

    def initialize(
      @table : Table,
      @columns : Set(Column) = Set(Column).new,
      @values : Array(Array(DB::Any)) = [] of Array(DB::Any),
      @back : Array(Column) = Array(Column).new,
      @query : Query? = nil
    )
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Update < Node
    getter table : Table
    getter setters : Array(Setter)
    getter where : Where?
    getter back : Set(Column) = Set(Column).new

    def initialize(
      @table : Table,
      @setters : Array(Setter) = [] of Setter,
      @where : Where? = nil,
      @back : Set(Column) = Set(Column).new
    )
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Delete
    getter table : Table
    getter where : Where?
    getter back : Set(Column) = Set(Column).new
    getter using : Table?

    def initialize(@table : Table, @where : Where? = nil, @back : Set(Column) = Set(Column).new, @using : Table? = nil)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Setter < Node
    getter column : Column
    getter value : DB::Any

    def initialize(@column : Column, @value : DB::Any)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  enum JoinType
    INNER
    LEFT
    RIGHT
  end

  class Join < Node
    getter table : Table
    getter join_type : JoinType = JoinType::INNER
    getter condition : Condition

    def initialize(@join_type : JoinType, @table : Table, @condition : Condition)
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
    getter condition : Condition

    def initialize(@condition : Condition)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Or < Condition
    getter left : Condition
    getter right : Condition

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
    getter orders : Hash(Column, OrderDirection)

    def initialize(@orders : Hash(Column, OrderDirection))
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  alias Aggregate = Count | Max | Min | Sum | Avg

  class Query < Node
    getter columns : Array(Column)
    getter from : From
    getter where : Where? = nil
    getter group_by : GroupBy? = nil
    getter having : Having? = nil
    getter order_by : OrderBy
    getter joins : Array(Join) = [] of Join
    getter limit : Limit? = nil
    getter? distinct : Bool = false
    getter aggr_columns : Array(Aggregate) = [] of Aggregate

    def initialize(
      @columns : Array(Column) = [] of CQL::BaseColumn,
      @from : From = [] of CQL::Table,
      @where : Where? = nil,
      @group_by : GroupBy? = nil,
      @having : Having? = nil,
      @order_by : OrderBy? = nil,
      @joins : Array(Join) = [] of Join,
      @limit : Limit? = nil,
      @distinct : Bool = false,
      @aggr_columns : Array(Aggregate) = [] of Aggregate
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
    getter condition : Condition

    def initialize(@condition : Condition)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Null < Condition
    getter column : Column?

    def initialize(@column : Column? = nil)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Is < Condition
    getter column : Column
    getter value : DB::Any

    def initialize(@column : Column, @value : DB::Any)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class IsNull < Condition
    getter column : Column

    def initialize(@column : Column)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class IsNot < Condition
    getter column : Column
    getter value : DB::Any

    def initialize(@column : Column, @value : DB::Any)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class IsNotNull < Condition
    getter column : Column

    def initialize(@column : Column)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class DropForeignKey < AlterAction
    getter fk : String
    getter table : String

    def initialize(@fk : String, @table : String)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end
end
