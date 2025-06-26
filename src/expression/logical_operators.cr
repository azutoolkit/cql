require "./base_expression"

module Expression
  # Empty node for no conditions
  class EmptyNode < Condition
    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  # Logical AND operator
  class And < Condition
    getter left : Condition
    getter right : Condition

    def initialize(@left : Condition, @right : Condition)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  # Logical OR operator
  class Or < Condition
    getter left : Condition
    getter right : Condition

    def initialize(@left : Condition, @right : Condition)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  # Logical NOT operator
  class Not < Condition
    getter condition : Condition

    def initialize(@condition : Condition)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end
end
