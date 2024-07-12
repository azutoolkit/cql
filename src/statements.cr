module Sql
  abstract class Node
    abstract def accept(visitor : Sql::Visitor)
  end

  abstract class Condition < Node
  end

  class AndCondition < Condition
    property left : Condition
    property right : Condition

    def initialize(@left : Condition, @right : Condition)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class OrCondition < Condition
    property left : Condition
    property right : Condition

    def initialize(@left : Condition, @right : Condition)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class NotCondition < Condition
    property condition : Condition

    def initialize(@condition : Condition)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class ComparisonCondition < Condition
    property left : String
    property operator : String
    property right : String

    def initialize(@left : String, @operator : String, @right : String)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class BetweenCondition < Condition
    property column : String
    property low : String
    property high : String

    def initialize(@column : String, @low : String, @high : String)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class LikeCondition < Condition
    property column : String
    property pattern : String

    def initialize(@column : String, @pattern : String)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class InCondition < Condition
    property column : String
    property values : Array(String)

    def initialize(@column : String, @values : Array(String))
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class InSelectCondition < Condition
    property column : String
    property sub_query : SelectStatement

    def initialize(@column : String, @sub_query : SelectStatement)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class NotInSelectCondition < Condition
    property column : String
    property sub_query : SelectStatement

    def initialize(@column : String, @sub_query : SelectStatement)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class IsNullCondition < Condition
    property column : String

    def initialize(@column : String)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class IsNotNullCondition < Condition
    property column : String

    def initialize(@column : String)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class Column < Node
    property name : String
    property alias_name : String?
    property? is_count : Bool
    property? is_distinct : Bool

    def initialize(@name : String, @alias_name : String? = nil, @is_count : Bool = false, @is_distinct : Bool = false)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class WhereClause < Node
    property condition : Condition

    def initialize(@condition : Condition)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class SelectStatement < Node
    property columns : Array(Column)
    property table : String
    property is_distinct : Bool
    property where_clause : WhereClause?
    property group_by_clause : GroupByClause?
    property order_by_clause : OrderByClause?

    def initialize(
      @columns : Array(Column),
      @table : String,
      @is_distinct : Bool = false,
      @where_clause : WhereClause? = nil,
      @group_by_clause : GroupByClause? = nil,
      @order_by_clause : OrderByClause? = nil
    )
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class OrderByClause < Node
    property table : String
    property table_alias : String
    property orders : Array(Tuple(String, String))

    def initialize(@table : String, @table_alias : String, @orders : Array(Tuple(String, String)))
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class GroupByClause < Node
    property table : String
    property table_alias : String
    property columns : Array(String)

    def initialize(@table : String, @table_alias : String, @columns : Array(String))
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class InsertStatement < Node
    property table : String
    property columns : Array(String)
    property values : Array(String)

    def initialize(@table : String, @columns : Array(String), @values : Array(String))
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end
end
