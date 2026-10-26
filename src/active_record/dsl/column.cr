module CQL
  module DSL
    # A model column in the typed query DSL (`where { age >= 18 }`).
    #
    # Comparisons only accept values of the column's own type *T*; anything else
    # is a compile-time error that names both types. Nullable columns are typed
    # by their non-nil type, and `== nil` / `!= nil` mean IS NULL / IS NOT NULL.
    class Col(T)
      getter expression : Expression::BaseColumn

      def initialize(@expression : Expression::BaseColumn)
      end

      {% for name, sql in {"==" => "=", "!=" => "!=", "<" => "<", "<=" => "<=", ">" => ">", ">=" => ">=",
                           "eq" => "=", "neq" => "!=", "lt" => "<", "lte" => "<=", "gt" => ">", "gte" => ">="} %}
        def {{ name.id }}(value : T) : Expression::ConditionBuilder
          compare({{ sql }}, value)
        end

        def {{ name.id }}(other : Col(T)) : Expression::ConditionBuilder
          Expression::ConditionBuilder.new(Expression::CompareCondition.new(@expression, {{ sql }}, other.expression))
        end

        # An integer literal against a numeric column of another width (`id == 7` on an Int64 column).
        def {{ name.id }}(value : Int) : Expression::ConditionBuilder
          \{% if T < Number %}
            compare({{ sql }}, widen(value))
          \{% else %}
            \{% raise "CQL: cannot compare a #{T} column with an integer using `{{ name.id }}`" %}
          \{% end %}
        end

        # A float literal against a floating point column.
        def {{ name.id }}(value : Float) : Expression::ConditionBuilder
          \{% if T < Float %}
            compare({{ sql }}, T.new(value))
          \{% else %}
            \{% raise "CQL: cannot compare a #{T} column with a float using `{{ name.id }}`" %}
          \{% end %}
        end

        def {{ name.id }}(other : U) : NoReturn forall U
          \{% raise "CQL: cannot compare a #{T} column with #{U} using `{{ name.id }}`; use a #{T} value or another #{T} column" %}
        end
      {% end %}

      def ==(other : Nil) : Expression::ConditionBuilder
        null
      end

      def !=(other : Nil) : Expression::ConditionBuilder
        not_null
      end

      def null : Expression::ConditionBuilder
        Expression::ConditionBuilder.new(Expression::IsNull.new(@expression))
      end

      def not_null : Expression::ConditionBuilder
        Expression::ConditionBuilder.new(Expression::IsNotNull.new(@expression))
      end

      def in(values : Array(T)) : Expression::ConditionBuilder
        in_list(values)
      end

      # Integer literals against a numeric column of another width (`id.in([1, 2])` on Int64).
      def in(values : Array(Int)) : Expression::ConditionBuilder
        {% if T < Number %}
          in_list(values.map { |value| widen(value) })
        {% else %}
          {% raise "CQL: cannot compare a #{T} column with integers using `in`" %}
        {% end %}
      end

      def not_in(values : Array(T)) : Expression::ConditionBuilder
        self.in(values).not
      end

      def not_in(values : Array(Int)) : Expression::ConditionBuilder
        self.in(values).not
      end

      def between(min : T, max : T) : Expression::ConditionBuilder
        Expression::ConditionBuilder.new(Expression::Between.new(@expression, bindable(min), bindable(max)))
      end

      private def in_list(values : Array(T)) : Expression::ConditionBuilder
        Expression::ConditionBuilder.new(Expression::InCondition.new(@expression, bindables(values)))
      end

      private def widen(value : Int) : T
        T.new(value)
      rescue OverflowError
        raise ArgumentError.new("#{value} does not fit a #{T} column (#{@expression.alias_name}.#{@expression.column.name})")
      end

      private def compare(operator : String, value : T) : Expression::ConditionBuilder
        Expression::ConditionBuilder.new(Expression::Compare.new(@expression, operator, bindable(value)))
      end

      # Values the database driver cannot bind directly (UUID, ULID, ...) travel as text.
      private def bindable(value : T) : DB::Any
        {% if DB::Any >= T %}
          value.as(DB::Any)
        {% elsif T < Int %}
          value.to_i64.as(DB::Any)
        {% else %}
          value.to_s.as(DB::Any)
        {% end %}
      end

      private def bindables(values : Array(T)) : Array(DB::Any)
        values.map { |value| bindable(value) }
      end
    end

    # String columns add pattern matching.
    class TextCol < Col(String)
      def like(pattern : String) : Expression::ConditionBuilder
        @expression.like(pattern)
      end

      def not_like(pattern : String) : Expression::ConditionBuilder
        @expression.not_like(pattern)
      end

      def ilike(pattern : String) : Expression::ConditionBuilder
        @expression.ilike(pattern)
      end

      def not_ilike(pattern : String) : Expression::ConditionBuilder
        @expression.not_ilike(pattern)
      end
    end

    # JSON columns add document predicates.
    class JsonCol < Col(JSON::Any)
      def json_eq(path : Expression::JsonPath::Segment | Array(Expression::JsonPath::Segment), value : String | Int | Float | Bool) : Expression::ConditionBuilder
        @expression.json_eq(path, value)
      end

      def json_contains(value) : Expression::ConditionBuilder
        @expression.json_contains(value)
      end
    end
  end
end
