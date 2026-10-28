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
    getter? insensitive : Bool

    def initialize(@column : BaseColumn, @value : String, @insensitive : Bool = false)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  class NotLike < Condition
    getter column : BaseColumn
    getter value : String
    getter? insensitive : Bool

    def initialize(@column : BaseColumn, @value : String, @insensitive : Bool = false)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  # LIKE on user text that matches literally: its `%`, `_` and ESCAPE characters are escaped.
  class EscapedLike < Condition
    # Not a backslash: its SQL spelling changes under MySQL's NO_BACKSLASH_ESCAPES, and SQLite has no default.
    ESCAPE = '!'

    enum Position
      Contains
      StartsWith
      EndsWith
    end

    getter column : BaseColumn
    getter text : String
    getter position : Position

    def initialize(@column : BaseColumn, @text : String, @position : Position)
      raise ArgumentError.new("LIKE text must not contain NUL: SQLite would end the pattern there") if text.includes?('\0')
    end

    # The bound pattern: the escaped text with `%` on the sides its position leaves open.
    def pattern : String
      escaped = text.gsub { |char| char.in?(ESCAPE, '%', '_') ? "#{ESCAPE}#{char}" : char }
      case position
      in .contains?    then "%#{escaped}%"
      in .starts_with? then "#{escaped}%"
      in .ends_with?   then "%#{escaped}"
      end
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
