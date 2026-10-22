require "./executable"

module CQL
  # Builds `self <operator> other` for anything that can be executed as a
  # statement (a `Query` or another `CompoundQuery`).
  module SetOperations
    def union(other : Executable) : CompoundQuery
      CompoundQuery.new(self, Expression::SetOperator::Union, other)
    end

    def union_all(other : Executable) : CompoundQuery
      CompoundQuery.new(self, Expression::SetOperator::UnionAll, other)
    end

    def intersect(other : Executable) : CompoundQuery
      CompoundQuery.new(self, Expression::SetOperator::Intersect, other)
    end

    def except(other : Executable) : CompoundQuery
      CompoundQuery.new(self, Expression::SetOperator::Except, other)
    end
  end

  # Two statements combined with UNION / INTERSECT / EXCEPT, executed like any
  # query. ORDER BY / LIMIT set on an operand stay on that operand; ordering or
  # limiting the combined result is not supported yet.
  class CompoundQuery
    include Executable
    include SetOperations

    getter left : Executable
    getter operator : Expression::SetOperator
    getter right : Executable

    def initialize(@left : Executable, @operator : Expression::SetOperator, @right : Executable)
    end

    def schema : Schema
      left.schema
    end

    def build : Expression::SetOperation
      Expression::SetOperation.new(left.build, operator, right.build)
    end
  end
end
