require "./base_expression"
require "./aggregate_functions"

module Expression
  # Query structure - optimized for memory efficiency
  class Query < Node
    getter columns : Array(BaseColumn)
    getter from : From
    getter where : Where? = nil
    getter group_by : GroupBy? = nil
    getter having : Having? = nil
    getter order_by : OrderBy?
    getter joins : Array(Join)
    getter limit : Limit? = nil
    getter? distinct : Bool = false
    getter aggr_columns : Array(Aggregate)

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
      joins : Array(Join) = [] of Join,
      limit : Limit? = nil,
      distinct : Bool = false,
      aggr_columns : Array(Aggregate) = [] of Aggregate,
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
        @table.{{call.name.id}}.expression
      end
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
