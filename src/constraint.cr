module CQL
  # Represents a UNIQUE constraint on one or more columns.
  struct UniqueConstraint
    property columns : Array(Symbol)
    property name : String?

    def initialize(@columns : Array(Symbol), @name : String? = nil)
    end
  end

  # Represents a CHECK constraint with a custom condition.
  struct CheckConstraint
    property condition : String
    property name : String?

    def initialize(@condition : String, @name : String? = nil)
    end
  end
end
