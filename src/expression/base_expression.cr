require "db"
require "../cql"

module Expression
  # Core abstract classes
  abstract class Node
    abstract def accept(visitor : Visitor)
  end

  abstract class Condition < Node
  end

  # Comparison operators for compile-time generation
  COMPARISON_OPERATORS = {
    "==" => "=",
    "!=" => "!=",
    "<=" => "<=",
    "<"  => "<",
    ">"  => ">",
    ">=" => ">=",
  }

  # Mixin for common comparison operations
  module Comparable
    # Generate comparison methods at compile time
    {% for operator, sql_operator in Expression::COMPARISON_OPERATORS %}
      def {{operator.id}}(value : DB::Any) : ConditionBuilder
        compare({{sql_operator}}, value)
      end

      def {{operator.id}}(value : BaseColumn) : ConditionBuilder
        compare({{sql_operator}}, value)
      end
    {% end %}

    # `== nil` / `!= nil` mean IS NULL / IS NOT NULL, as `where(col: nil)` does: a bound NULL matches no row.
    # Columns are typed by their non-nil type (nullability is `null: true`), so a nil always lands here.
    def ==(other : Nil) : ConditionBuilder
      null
    end

    def !=(other : Nil) : ConditionBuilder
      not_null
    end

    # Method aliases for comparison operators
    {% for operator, method_name in {
                                      "==" => :eq,
                                      "!=" => :neq,
                                      "<=" => :lte,
                                      "<"  => :lt,
                                      ">"  => :gt,
                                      ">=" => :gte,
                                    } %}
      def {{method_name.id}}(value : DB::Any) : ConditionBuilder
        self.{{operator.id}}(value)
      end

      def {{method_name.id}}(value : BaseColumn) : ConditionBuilder
        self.{{operator.id}}(value)
      end
    {% end %}

    # Common query methods
    def in(items : Array(DB::Any)) : ConditionBuilder
      ConditionBuilder.new(InCondition.new(self, items))
    end

    def in(sub_query : CQL::Query) : ConditionBuilder
      ConditionBuilder.new(InSelect.new(self, sub_query.build))
    end

    def not_in(values : Array(DB::Any)) : ConditionBuilder
      ConditionBuilder.new(Not.new(InCondition.new(self, values)))
    end

    def not_in(sub_query : CQL::Query) : ConditionBuilder
      ConditionBuilder.new(Not.new(InSelect.new(self, sub_query.build)))
    end

    def like(pattern : String) : ConditionBuilder
      ConditionBuilder.new(Like.new(self, pattern))
    end

    def not_like(pattern : String) : ConditionBuilder
      ConditionBuilder.new(NotLike.new(self, pattern))
    end

    # JSON documents: the value at *path* (a key, an index, or a list of them) equals
    # *value*, compared as text.
    def json_eq(path : JsonPath::Segment | Array(JsonPath::Segment), value : String | Int | Float | Bool) : ConditionBuilder
      typed = case value
              in Int          then value.to_i64
              in Float        then value.to_f64
              in String, Bool then value
              end
      ConditionBuilder.new(JsonEquals.new(self, JsonPath.parse(path), typed))
    end

    # JSON documents: this column contains *value* (anything JSON-serializable).
    def json_contains(value) : ConditionBuilder
      ConditionBuilder.new(JsonContains.new(self, value.to_json))
    end

    # Geospatial: this point column is within *meters* of (longitude, latitude).
    def within_distance(longitude : Float64, latitude : Float64, meters : Number) : ConditionBuilder
      ConditionBuilder.new(GeoWithin.new(self, longitude, latitude, meters.to_f))
    end

    # Case-insensitive LIKE (ILIKE where the database has it).
    def ilike(pattern : String) : ConditionBuilder
      ConditionBuilder.new(Like.new(self, pattern, insensitive: true))
    end

    def not_ilike(pattern : String) : ConditionBuilder
      ConditionBuilder.new(NotLike.new(self, pattern, insensitive: true))
    end

    def null : ConditionBuilder
      ConditionBuilder.new(IsNull.new(self))
    end

    def is_null : ConditionBuilder
      null
    end

    def not_null : ConditionBuilder
      ConditionBuilder.new(IsNotNull.new(self))
    end

    def is_not_null : ConditionBuilder
      not_null
    end

    def between(min : DB::Any, max : DB::Any) : ConditionBuilder
      ConditionBuilder.new(Between.new(self, min, max))
    end

    def not_between(min : DB::Any, max : DB::Any) : ConditionBuilder
      ConditionBuilder.new(Not.new(Between.new(self, min, max)))
    end

    def exists? : ConditionBuilder
      ConditionBuilder.new(Exists.new(self))
    end

    def not_exists? : ConditionBuilder
      ConditionBuilder.new(Not.new(Exists.new(self)))
    end

    protected abstract def compare(operator : String, value : DB::Any) : ConditionBuilder
    protected abstract def compare(operator : String, value : BaseColumn) : ConditionBuilder
  end

  # Enums for common types
  enum OrderDirection
    ASC
    DESC
  end

  enum JoinType
    INNER
    LEFT
    RIGHT
    FULL
    CROSS
  end
end
