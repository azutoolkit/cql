require "../compat"
require "./base_expression"
require "./condition_builder"

module Expression
  # A SQL fragment whose values are always bound as parameters, never
  # interpolated. Placeholders are `?` (positional) or `:name` (named); an
  # Array value expands to a comma-separated list for `IN (?)`.
  #
  # `??` is a literal `?` (PostgreSQL's jsonb operator), `::` is a cast, and
  # quoted strings, quoted identifiers and comments are left untouched.
  # The fragment itself must be a literal written by the developer.
  #
  # Notes: `nil` binds NULL, so `name = ?` never matches it (use
  # `IS NOT DISTINCT FROM ?`); PostgreSQL `$$...$$` strings, MySQL backslash
  # escapes and array slices like `a[1:n]` are not understood; only `where`
  # accepts fragments (not `having`).
  class Raw < Condition
    alias Value = DB::Any | Array(DB::Any)

    # Splits SQL text into literal fragments and the placeholders between them.
    struct Template
      MARKER = '\0'
      # Tokens that matter: quoted runs and comments (skipped), `??`, `?`, `::` and `:name`.
      TOKEN = /'(?:[^']++|'')*+'?|"(?:[^"]++|"")*+"?|`(?:[^`]++|``)*+`?|--[^\n]*|\/\*.*?(?:\*\/|\z)|\?\??|::|:[a-zA-Z_]\w*/m

      CACHE_LIMIT = 512

      @@cache = {} of String => Template
      @@cache_lock = CQL::Compat::Mutex.new

      getter fragments : Array(String)
      # One entry per placeholder: nil for `?`, the name for `:name`.
      getter slots = [] of String?

      # The parsed template for *sql*. Fragments are literals, so the same few strings repeat on
      # every call; parsed templates are kept and shared, the oldest inserted dropped past
      # `CACHE_LIMIT`.
      def self.for(sql : String) : Template
        if cached = @@cache_lock.synchronize { @@cache[sql]? }
          return cached
        end
        template = new(sql)
        @@cache_lock.synchronize do
          @@cache[sql]? || begin
            @@cache.shift if @@cache.size >= CACHE_LIMIT
            @@cache[sql] = template
          end
        end
      end

      def self.cached_count : Int32
        @@cache_lock.synchronize { @@cache.size }
      end

      def initialize(sql : String)
        raise ArgumentError.new("A SQL fragment cannot contain a NUL byte") if sql.includes?(MARKER)
        @fragments = sql.gsub(TOKEN) { |token| replace(token) }.split(MARKER)
      end

      private def replace(token : String) : String
        case token
        when "??" then "?"
        when "?"  then slot(nil)
        else
          named?(token) ? slot(token[1..]) : token
        end
      end

      private def named?(token : String) : Bool
        token.size > 1 && token[0] == ':' && token[1] != ':'
      end

      private def slot(name : String?) : String
        @slots << name
        MARKER.to_s
      end
    end

    getter fragments : Array(String)
    getter bindings : Array(Value)

    def initialize(@fragments : Array(String), @bindings : Array(Value))
      raise ArgumentError.new("A fragment needs one more text part than values") unless fragments.size == bindings.size + 1
    end

    def self.build(sql : String, positional : Tuple = Tuple.new, named : NamedTuple = NamedTuple.new) : Raw
      template = Template.for(sql)
      values = [] of Value
      positional.each { |value| values << to_value(value) }
      keyed = {} of String => Value
      named.each { |key, value| keyed[key.to_s] = to_value(value) }

      new(template.fragments, bind(template.slots, values, keyed))
    end

    # Pairs each placeholder with its value, rejecting any mismatch loudly:
    # a dropped value would silently widen the query.
    private def self.bind(slots : Array(String?), positional : Array(Value), named : Hash(String, Value)) : Array(Value)
      names = slots.compact
      raise ArgumentError.new("Cannot mix ? and :name placeholders in one fragment") if !names.empty? && names.size != slots.size

      values = names.empty? ? bind_positional(slots.size, positional, named) : bind_named(names, positional, named)
      values.each { |value| raise ArgumentError.new("Cannot bind an empty array; guard the condition instead") if value.is_a?(Array) && value.empty? }
      values
    end

    private def self.bind_positional(count : Int32, positional, named) : Array(Value)
      raise ArgumentError.new("Fragment has no :name placeholders but got named value(s): #{named.keys.map { |key| ":#{key}" }.join(", ")}") unless named.empty?
      raise ArgumentError.new("Fragment expects #{count} value(s), got #{positional.size}") unless positional.size == count
      positional
    end

    private def self.bind_named(names, positional, named) : Array(Value)
      raise ArgumentError.new("Fragment uses :name placeholders but got #{positional.size} positional value(s)") unless positional.empty?
      values = names.map { |name| named.fetch(name) { raise ArgumentError.new("Missing value for :#{name}") } }
      unused = named.keys - names
      raise ArgumentError.new("Unused named value(s): #{unused.map { |name| ":#{name}" }.join(", ")}") unless unused.empty?
      values
    end

    private def self.to_value(value : Array) : Value
      value.map { |item| item.as(DB::Any) }
    end

    private def self.to_value(value : T) : Value forall T
      {% if DB::Any >= T %}
        value.as(DB::Any)
      {% else %}
        {% raise "CQL: #{T} cannot be bound as a SQL parameter (use a DB::Any type: String, Int, Float, Bool, Time, Bytes, nil)" %}
      {% end %}
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end
end

module CQL
  # A safe SQL fragment as a condition, e.g. `where { raw("lower(email) = ?", e) & ... }`.
  def self.raw(sql : String, *positional, **named) : Expression::ConditionBuilder
    Expression::ConditionBuilder.new(Expression::Raw.build(sql, positional, named))
  end
end
