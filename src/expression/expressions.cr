require "db"
require "../cql"

module Expression
  # Core abstract classes
  abstract class Node
    abstract def accept(visitor : Visitor)
  end

  abstract class Condition < Node
  end

  # Comparison operators for compile-time generation
  COMPARISON_OPERATORS = {
    "==" => "=",
    "!=" => "!=",
    "<=" => "<=",
    "<"  => "<",
    ">"  => ">",
    ">=" => ">=",
  }

  # Base column class with common functionality
  abstract class BaseColumn < Node
    getter column : CQL::BaseColumn
    getter alias_name : String?

    def initialize(@column : CQL::BaseColumn, @alias_name : String? = nil)
    end

    # Generate comparison methods at compile time
    {% for operator, sql_operator in COMPARISON_OPERATORS %}
      def {{operator.id}}(value : DB::Any) : ConditionBuilder
        compare({{sql_operator}}, value)
      end

      def {{operator.id}}(value : BaseColumn) : ConditionBuilder
        compare({{sql_operator}}, value)
      end
    {% end %}

    # Method aliases for comparison operators
    {% for operator, method_name in {
                                      "==" => :eq,
                                      "!=" => :neq,
                                      "<=" => :lte,
                                      "<"  => :lt,
                                      ">"  => :gt,
                                      ">=" => :gte,
                                    } %}
      def {{method_name.id}}(value : DB::Any) : ConditionBuilder
        self.{{operator.id}}(value)
      end

      def {{method_name.id}}(value : BaseColumn) : ConditionBuilder
        self.{{operator.id}}(value)
      end
    {% end %}

    # Common query methods
    def in(items : Array(DB::Any)) : ConditionBuilder
      ConditionBuilder.new(InCondition.new(self, items))
    end

    def in(sub_query : CQL::Query) : ConditionBuilder
      ConditionBuilder.new(InSelect.new(self, sub_query.build))
    end

    def not_in(values : Array(DB::Any)) : ConditionBuilder
      ConditionBuilder.new(Not.new(InCondition.new(self, values)))
    end

    def not_in(sub_query : CQL::Query) : ConditionBuilder
      ConditionBuilder.new(Not.new(InSelect.new(self, sub_query.build)))
    end

    def like(pattern : String) : ConditionBuilder
      ConditionBuilder.new(Like.new(self, pattern))
    end

    def not_like(pattern : String) : ConditionBuilder
      ConditionBuilder.new(NotLike.new(self, pattern))
    end

    def null : ConditionBuilder
      ConditionBuilder.new(IsNull.new(self))
    end

    def is_null : ConditionBuilder
      null
    end

    def not_null : ConditionBuilder
      ConditionBuilder.new(IsNotNull.new(self))
    end

    def is_not_null : ConditionBuilder
      not_null
    end

    def between(min : DB::Any, max : DB::Any) : ConditionBuilder
      ConditionBuilder.new(Between.new(self, min, max))
    end

    def not_between(min : DB::Any, max : DB::Any) : ConditionBuilder
      ConditionBuilder.new(Not.new(Between.new(self, min, max)))
    end

    def exists? : ConditionBuilder
      ConditionBuilder.new(Exists.new(self))
    end

    def not_exists? : ConditionBuilder
      ConditionBuilder.new(Not.new(Exists.new(self)))
    end

    protected abstract def compare(operator : String, value : DB::Any) : ConditionBuilder
    protected abstract def compare(operator : String, value : BaseColumn) : ConditionBuilder

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  # Untyped column for dynamic queries
  class Column < BaseColumn
    protected def compare(operator : String, value : DB::Any) : ConditionBuilder
      ConditionBuilder.new(Compare.new(self, operator, value))
    end

    protected def compare(operator : String, value : BaseColumn) : ConditionBuilder
      ConditionBuilder.new(CompareCondition.new(self, operator, value))
    end
  end

  # Type-safe column for compile-time type checking
  class TypedColumn(T) < BaseColumn
    def type
      @column.type
    end

    # Type-safe comparison methods
    {% for operator, sql_operator in COMPARISON_OPERATORS %}
      def {{operator.id}}(value : T) : ConditionBuilder
        compare({{sql_operator}}, value)
      end

      def {{operator.id}}(value : TypedColumn(T)) : ConditionBuilder
        compare({{sql_operator}}, value)
      end
    {% end %}

    # Type-safe collection methods
    def in(items : Array(T)) : ConditionBuilder
      ConditionBuilder.new(InCondition.new(self, items.map(&.as(DB::Any))))
    end

    def not_in(values : Array(T)) : ConditionBuilder
      ConditionBuilder.new(Not.new(InCondition.new(self, values.map(&.as(DB::Any)))))
    end

    def between(min : T, max : T) : ConditionBuilder
      ConditionBuilder.new(Between.new(self, min.as(DB::Any), max.as(DB::Any)))
    end

    def not_between(min : T, max : T) : ConditionBuilder
      ConditionBuilder.new(Not.new(Between.new(self, min.as(DB::Any), max.as(DB::Any))))
    end

    protected def compare(operator : String, value : T) : ConditionBuilder
      ConditionBuilder.new(Compare.new(self, operator, value.as(DB::Any)))
    end

    protected def compare(operator : String, value : TypedColumn(T)) : ConditionBuilder
      ConditionBuilder.new(CompareCondition.new(self, operator, value))
    end

    # Override base methods to use typed versions
    protected def compare(operator : String, value : DB::Any) : ConditionBuilder
      ConditionBuilder.new(Compare.new(self, operator, value))
    end

    protected def compare(operator : String, value : BaseColumn) : ConditionBuilder
      ConditionBuilder.new(CompareCondition.new(self, operator, value))
    end
  end

  # Logical operators
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

  class Or < Condition
    getter left : Condition
    getter right : Condition

    def initialize(@left : Condition, @right : Condition)
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

  # Comparison conditions
  class Compare < Condition
    getter left : BaseColumn
    getter operator : String
    getter right : DB::Any

    def initialize(@left : BaseColumn, @operator : String, @right : DB::Any)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class CompareCondition < Condition
    getter left : Condition | BaseColumn | DB::Any
    getter operator : String
    getter right : Condition | BaseColumn | DB::Any

    def initialize(@left : Condition | BaseColumn | DB::Any, @operator : String, @right : Condition | BaseColumn | DB::Any)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  # Range and pattern matching
  class Between < Condition
    getter column : BaseColumn
    getter low : DB::Any
    getter high : DB::Any

    def initialize(@column : BaseColumn, @low : DB::Any, @high : DB::Any)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Like < Condition
    getter column : BaseColumn
    getter value : String

    def initialize(@column : BaseColumn, @value : String)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class NotLike < Condition
    getter column : BaseColumn
    getter value : String

    def initialize(@column : BaseColumn, @value : String)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  # Null checking
  class IsNull < Condition
    getter column : BaseColumn

    def initialize(@column : BaseColumn)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class IsNotNull < Condition
    getter column : BaseColumn

    def initialize(@column : BaseColumn)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  # Literal NULL value
  class Null < Condition
    getter column : BaseColumn?

    def initialize(@column : BaseColumn? = nil)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  # IS and IS NOT operations
  class Is < Condition
    getter column : BaseColumn
    getter value : DB::Any

    def initialize(@column : BaseColumn, @value : DB::Any)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class IsNot < Condition
    getter column : BaseColumn
    getter value : DB::Any

    def initialize(@column : BaseColumn, @value : DB::Any)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  # Collection operations
  class InCondition < Condition
    getter column : BaseColumn
    getter values : Array(DB::Any)

    def initialize(@column : BaseColumn, values)
      @values = values.map { |v| v.as(DB::Any) }
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class InSelect < Condition
    getter column : BaseColumn
    getter query : Query

    def initialize(@column : BaseColumn, @query : Query)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  # Subquery operations
  class Exists < Condition
    getter sub_query : Query

    def initialize(@sub_query : Query)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  # Query structure
  class Query < Node
    getter columns : Array(BaseColumn)
    getter from : From
    getter where : Where? = nil
    getter group_by : GroupBy? = nil
    getter having : Having? = nil
    getter order_by : OrderBy?
    getter joins : Array(Join) = [] of Join
    getter limit : Limit? = nil
    getter? distinct : Bool = false
    getter aggr_columns : Array(Aggregate) = [] of Aggregate

    def initialize(
      @columns : Array(BaseColumn),
      @from : From,
      @where : Where?,
      @group_by : GroupBy?,
      @having : Having?,
      @order_by : OrderBy?,
      @joins : Array(Join),
      @limit : Limit?,
      @distinct : Bool,
      @aggr_columns : Array(Aggregate),
    )
    end

    def initialize(
      columns : Array(Column),
      from : From,
      where : Where?,
      group_by : GroupBy?,
      having : Having?,
      order_by : OrderBy?,
      joins : Array(Join),
      limit : Limit?,
      distinct : Bool,
      aggr_columns : Array(Aggregate),
    )
      @columns = columns.map(&.as(BaseColumn))
      @from = from
      @where = where
      @group_by = group_by
      @having = having
      @order_by = order_by
      @joins = joins
      @limit = limit
      @distinct = distinct
      @aggr_columns = aggr_columns
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class From < Node
    getter tables : Array(Expression::Table)

    def initialize(@tables : Array(Expression::Table))
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

  class GroupBy < Node
    getter columns : Array(BaseColumn)

    def initialize(@columns : Array(BaseColumn) = [] of BaseColumn)
    end

    def initialize(columns : Array(Column))
      @columns = columns.map(&.as(BaseColumn))
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

  class OrderBy < Node
    getter orders : Hash(BaseColumn, OrderDirection)

    def initialize(@orders : Hash(BaseColumn, OrderDirection))
    end

    def initialize(orders : Hash(Column, OrderDirection))
      @orders = orders.transform_keys(&.as(BaseColumn))
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

  # Table and join operations
  class Table < Node
    getter table : CQL::Table
    getter alias_name : String?

    def initialize(@table : CQL::Table, @alias_name : String? = nil)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end

    macro method_missing(call)
      def {{call.name.id}} : BaseColumn
        @table.{{call.name.id}}.expression
      end
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

  # Aggregate functions
  alias Aggregate = Count | Max | Min | Sum | Avg

  class Count < Condition
    getter column : BaseColumn

    def initialize(@column : BaseColumn)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Max < Condition
    getter column : BaseColumn

    def initialize(@column : BaseColumn)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Min < Condition
    getter column : BaseColumn

    def initialize(@column : BaseColumn)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Avg < Condition
    getter column : BaseColumn

    def initialize(@column : BaseColumn)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Sum < Condition
    getter column : BaseColumn

    def initialize(@column : BaseColumn)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  # Data manipulation operations
  class Insert < Node
    getter table : Table
    getter columns : Set(BaseColumn) = Set(BaseColumn).new
    getter values : Array(Array(DB::Any)) = [] of Array(DB::Any)
    getter back : Array(BaseColumn) = Array(BaseColumn).new
    getter query : Query?

    def initialize(
      @table : Table,
      @columns : Set(BaseColumn) = Set(BaseColumn).new,
      @values : Array(Array(DB::Any)) = [] of Array(DB::Any),
      @back : Array(BaseColumn) = Array(BaseColumn).new,
      @query : Query? = nil,
    )
    end

    def initialize(
      table : Table,
      columns : Set(Column),
      values : Array(Array(DB::Any)) = [] of Array(DB::Any),
      back : Array(Column) = [] of Column,
      query : Query? = nil,
    )
      @table = table
      @columns = columns.map(&.as(BaseColumn)).to_set
      @values = values
      @back = back.map(&.as(BaseColumn))
      @query = query
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Update < Node
    getter table : Table
    getter setters : Array(Setter)
    getter where : Where?
    getter back : Set(BaseColumn) = Set(BaseColumn).new

    def initialize(
      @table : Table,
      @setters : Array(Setter) = [] of Setter,
      @where : Where? = nil,
      @back : Set(BaseColumn) = Set(BaseColumn).new,
    )
    end

    def initialize(
      table : Table,
      setters : Array(Setter) = [] of Setter,
      where : Where? = nil,
      back : Set(Column) = Set(Column).new,
    )
      @table = table
      @setters = setters
      @where = where
      @back = back.map(&.as(BaseColumn)).to_set
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Delete < Node
    getter table : Table
    getter where : Where?
    getter back : Set(BaseColumn) = Set(BaseColumn).new
    getter using : Table?

    def initialize(@table : Table, @where : Where? = nil, @back : Set(BaseColumn) = Set(BaseColumn).new, @using : Table? = nil)
    end

    def initialize(table : Table, where : Where? = nil, back : Set(Column) = Set(Column).new, using : Table? = nil)
      @table = table
      @where = where
      @back = back.map(&.as(BaseColumn)).to_set
      @using = using
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Setter < Node
    getter column : BaseColumn
    getter value : DB::Any

    def initialize(@column : BaseColumn, @value : DB::Any)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  # Schema operations
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

  # Schema alteration actions
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

  class DropForeignKey < AlterAction
    getter fk : String
    getter table : String

    def initialize(@fk : String, @table : String)
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

  # Enums
  enum OrderDirection
    ASC
    DESC
  end

  # Legacy/utility classes
  class Top < Node
    getter count : Int32

    def initialize(@count : Int32)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end
end
