require "./base_expression"

module Expression
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
end
