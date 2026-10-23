require "db"
require "json"
require "uuid"
require "../errors"

module CQL::Postgres::Types
  # One encoded bind parameter: text format unless the value is binary data.
  record Param, value : Bytes?, format : Int16 do
    TEXT   = 0_i16
    BINARY = 1_i16

    def self.text(value : String) : Param
      raise ArgumentError.new("NUL bytes cannot be bound as text") if value.includes?('\0')
      new(value.to_slice, TEXT)
    end

    def self.null : Param
      new(nil, TEXT)
    end

    def self.binary(value : Bytes) : Param
      new(value, BINARY)
    end
  end

  # Turns Crystal values into bind parameters. The server infers each
  # parameter's type from the statement and parses the text form.
  module ParamEncoder
    def self.encode(value : Nil) : Param
      Param.null
    end

    def self.encode(value : Bytes) : Param
      Param.binary(value)
    end

    def self.encode(value : String) : Param
      Param.text(value)
    end

    def self.encode(value : Bool | Int | Float | UUID | DecimalText | Time | JSON::Any) : Param
      Param.text(text_of(value))
    end

    def self.encode(value : Array) : Param
      Param.text(array_literal(value))
    end

    def self.encode(value) : Param
      raise ArgumentError.new("cannot bind a #{value.class} to a PostgreSQL parameter")
    end

    private def self.text_of(value : Time) : String
      value.to_utc.to_s("%F %T.%6N+00")
    end

    private def self.text_of(value : JSON::Any) : String
      value.to_json
    end

    private def self.text_of(value : Bool) : String
      value ? "t" : "f"
    end

    private def self.text_of(value) : String
      value.to_s
    end

    private def self.array_literal(values : Array) : String
      elements = values.map do |element|
        case element
        when Nil                                                          then "NULL"
        when Array                                                        then array_literal(element)
        when Bytes                                                        then raise ArgumentError.new("cannot bind bytea elements inside an array")
        when String, Bool, Int, Float, UUID, DecimalText, Time, JSON::Any then quote_element(element)
        else                                                                   raise ArgumentError.new("cannot bind a #{element.class} inside an array")
        end
      end
      "{#{elements.join(',')}}"
    end

    private def self.quote_element(element) : String
      text = text_of(element)
      return text unless text.empty? || text.compare("null", case_insensitive: true) == 0 || text.matches?(/[\s{},"\\]/)
      %("#{text.gsub(/["\\]/) { |match| "\\#{match}" }}")
    end
  end
end
