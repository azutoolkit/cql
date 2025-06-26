require "./base_expression"

module Expression
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
end
