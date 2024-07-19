module Sql
  class Constraint
    enum ConstraintType
      PRIMARY_KEY
      FOREIGN_KEY
      UNIQUE
      CHECK
      NOT_NULL
      DEFAULT
    end

    property name : String

    def initialize(@name : String)
    end
  end
end
