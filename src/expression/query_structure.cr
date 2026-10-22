require "./base_expression"
require "./aggregate_functions"

module Expression
  # Query structure - optimized for memory efficiency
  class Query < Statement
    getter columns : Array(BaseColumn)
    getter from : From
    getter where : Where? = nil
    getter group_by : GroupBy? = nil
    getter having : Having? = nil
    getter order_by : OrderBy?
    getter joins : Array(Join)
    getter limit : Limit? = nil
    getter? distinct : Bool = false
    getter select_expressions : Array(SelectExpression)
    getter ctes : Array(Cte)
    getter? recursive : Bool
    getter distinct_on : Array(BaseColumn)
    getter lock : RowLock?

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
      @select_expressions : Array(SelectExpression),
      @ctes : Array(Cte) = [] of Cte,
      @recursive : Bool = false,
      @distinct_on : Array(BaseColumn) = [] of BaseColumn,
      @lock : RowLock? = nil,
    )
    end

    def initialize(
      columns : Array(Column),
      from : From,
      where : Where?,
      group_by : GroupBy?,
      having : Having?,
      order_by : OrderBy?,
      joins : Array(Join) = [] of Join,
      limit : Limit? = nil,
      distinct : Bool = false,
      select_expressions : Array(SelectExpression) = [] of SelectExpression,
      @ctes : Array(Cte) = [] of Cte,
      @recursive : Bool = false,
      @distinct_on : Array(BaseColumn) = [] of BaseColumn,
      @lock : RowLock? = nil,
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
      @select_expressions = select_expressions
    end

    def needs_grouping_as_operand? : Bool
      !ctes.empty? || !order_by.nil? || !limit.nil?
    end

    # Selected columns plus aggregates that carry an alias (`sum(:x, as: :y)`).
    def output_columns : Array(CQL::BaseColumn)
      named = select_expressions.compact_map { |aggr| aggr.as_name.try { |name| CQL::Column(DB::Any).new(name).as(CQL::BaseColumn) } }
      columns.map(&.column) + named
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
    # Use Hash for efficient lookups - optimized for memory
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

  # Table and join operations - optimized
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
        @table.{{call.name.id}}.expression(@alias_name)
      end
    end
  end

  # A subquery used as a table: `(SELECT ...) AS alias`.
  class Subquery < Table
    getter statement : Statement

    def initialize(@statement : Statement, table : CQL::Table, alias_name : String)
      super(table, alias_name)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
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
