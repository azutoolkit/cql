require "db"
require "json"
require "uuid"
require "../errors"
require "./binary"

module CQL::Postgres::Types
  # A value whose wire form waits for the parameter's type: the statement has to
  # be described first, and only then is it known whether the server's type has a
  # binary encoding for this value (see `Binary`). It stands in for a `Param`
  # until `resolve` is called with the type the server reported.
  abstract class Deferred
    abstract def resolve(type_oid : UInt32?, text_only : Indexable(UInt32)) : Param

    # About how many bytes the parameter will take, for sizing a pipeline batch.
    abstract def size_hint : Int32
  end

  class DeferredValue(T) < Deferred
    def initialize(@value : T)
    end

    # Binary when the server's type has an encoding for the value (and is not
    # one the server reads differently from its text), otherwise exactly the
    # text the value would have been sent as.
    def resolve(type_oid : UInt32?, text_only : Indexable(UInt32)) : Param
      bytes = type_oid.try { |oid| Binary.encode(@value, oid) unless text_only.includes?(oid) }
      bytes ? Param.binary(bytes) : ParamEncoder.encode(@value)
    end

    def size_hint : Int32
      Binary.size_hint(@value)
    end

    def inspect(io : IO) : Nil
      io << "#<" << self.class.name << ">"
    end
  end

  # One encoded bind parameter: text format unless the value is binary data.
  # A *deferred* one has no bytes yet and cannot be sent as it is.
  record Param, value : Bytes?, format : Int16, deferred : Deferred? = nil do
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

    def self.deferred(value) : Param
      new(nil, TEXT, DeferredValue.new(value))
    end

    # Parameters can be bound values, so they are never printed.
    def inspect(io : IO) : Nil
      io << "#<" << self.class.name << " format=" << format << ">"
    end
  end

  # Turns Crystal values into bind parameters. The server infers each
  # parameter's type from the statement and parses the text form.
  module ParamEncoder
    # With *binary* the value is kept until the statement's parameter types are
    # known, when it may be sent in binary (see `Binary.supported?`).
    def self.encode(value, binary : Bool) : Param
      binary && Binary.supported?(value) ? Param.deferred(value) : encode(value)
    end

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
