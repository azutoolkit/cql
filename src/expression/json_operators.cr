require "./base_expression"

module Expression
  # A JSON path made of object keys and array indexes, e.g. `["tags", 0]`.
  # Keys are limited to word characters because they become part of path syntax.
  struct JsonPath
    alias Segment = String | Int32

    getter segments : Array(Segment)

    def self.parse(path : Segment | Array(Segment)) : JsonPath
      segments = [] of Segment
      path.is_a?(Array) ? path.each { |segment| segments << segment } : segments << path
      new(segments)
    end

    def initialize(@segments : Array(Segment))
      raise ArgumentError.new("A JSON path needs at least one segment") if segments.empty?
      segments.each { |segment| validate!(segment) }
    end

    private def validate!(segment : Segment) : Nil
      valid = segment.is_a?(Int32) ? segment >= 0 : segment.matches?(/\A\w+\z/)
      raise ArgumentError.new("Invalid JSON path segment #{segment.inspect}: use word characters or a non-negative index") unless valid
    end
  end

  # `column -> path` compared as text with *value*.
  class JsonEquals < Condition
    alias Value = String | Int64 | Float64 | Bool

    getter column : BaseColumn
    getter path : JsonPath
    getter value : Value

    def initialize(@column : BaseColumn, @path : JsonPath, @value : Value)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end

  # The column's JSON document contains the given JSON.
  class JsonContains < Condition
    getter column : BaseColumn
    getter json : String

    def initialize(@column : BaseColumn, @json : String)
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end
end
