module CQL
  module ActiveRecord
    module Validations
      alias AllNumbers = Int32 | Int64 | UInt32 | UInt64 | Float32 | Float64 | Nil

      struct Error
        getter :field, :message

        def initialize(@field : Symbol, @message : String)
        end
      end

      class Errors
        @errors = Array(Error).new

        forward_missing_to @errors

        def messages
          @errors.map &.message
        end
      end

      module Equal
        def eq?(value, other)
          return false if value.nil? || other.nil?
          value == other
        end
      end

      module GreaterThan
        def gt?(value : AllNumbers, compare : AllNumbers)
          return false if value.nil? || compare.nil?
          value > compare
        end

        def gt?(value : Float, compare : Float)
          return false if value.nil? || compare.nil?
          value > compare
        end

        def gt?(value : Time, compare : Time)
          return false if value.nil? || compare.nil?
          value > compare
        end
      end

      module Exclusion
        def exclude?(value, exclusion : Array)
          return false if value.nil? || exclusion.nil?
          !exclusion.includes?(value)
        end

        def exclude?(value, exclusion : Range)
          return false if value.nil? || exclusion.nil?
          !exclusion.includes?(value)
        end
      end

      module GreaterThanOrEqual
        def gte?(value : AllNumbers, compare : AllNumbers)
          return false if value.nil? || compare.nil?
          value >= compare
        end

        def gte?(value : Time, compare : Time)
          return false if value.nil? || compare.nil?
          value >= compare
        end
      end

      module Inclusion
        def in?(value, included : Array)
          return false if value.nil? || included.nil?
          included.includes?(value)
        end

        def in?(value, included : Range)
          return false if value.nil? || included.nil?
          included.includes?(value)
        end
      end

      module LessThan
        def lt?(value : AllNumbers, compare : AllNumbers)
          return false if value.nil? || compare.nil?
          value < compare
        end

        def lt?(value : Time, compare : Time)
          return false if value.nil? || compare.nil?
          value < compare
        end
      end

      module LessThanOrEqual
        def lte?(value : AllNumbers, compare : AllNumbers)
          return false if value.nil? || compare.nil?
          value <= compare
        end

        def lte?(value : Time, compare : Time)
          return false if value.nil? || compare.nil?
          value <= compare
        end
      end

      module Presence
        def presence?(value, other)
          (!value.nil? && !value.empty?)
        end
      end

      module RegularExpression
        def match?(value : String, regex : Regex)
          !value.match(regex).nil?
        end
      end

      module Required
        def required?(value, other)
          !value.nil?
        end
      end

      module Confirmation
        def confirmation?(value, confirmation_value)
          return false if value.nil? || confirmation_value.nil?
          value == confirmation_value
        end
      end

      module Acceptance
        def accept?(value, accepted_values = true)
          return false if value.nil?
          # If accepted_values is true, use default acceptance values
          if accepted_values == true
            default_accepted = [true, "true", "1", "on", "yes"]
            default_accepted.includes?(value)
          else
            case accepted_values
            when Array
              accepted_values.includes?(value)
            else
              value == accepted_values
            end
          end
        end
      end

      module Size
        def size?(value, size : AllNumbers)
          return false if value.nil? || size.nil?
          value.size == size
        end

        def size?(value, size : Range)
          return false if value.nil? || size.nil?
          size.includes?(value.size)
        end
      end

      module Predicates
        include Equal
        include Exclusion
        include GreaterThan
        include GreaterThanOrEqual
        include Inclusion
        include LessThan
        include LessThanOrEqual
        include RegularExpression
        include Size
        include Presence
        include Required
        include Confirmation
        include Acceptance
      end

      class Constraint
        include Predicates

        @errors = Array(Error).new

        def initialize(&block : Constraint, Array(Error) -> Nil)
          @block = block
        end

        def valid? : Array(Error)
          @block.call(self, @errors)
          @errors
        end
      end

      abstract class CustomValidator
        include Predicates

        def initialize(@record)
        end

        abstract def valid? : Array(Error)
      end

      class ValidationError < Exception
        @errors : Array(Error)

        def initialize(@errors : Array(Error) = [] of Error)
        end

        def message
          @errors.map(&.message).join(",")
        end
      end

      macro use(*validators)
        {% for validator in validators %}
        {% SCHEMA_VALIDATORS << validator %}
        {% end %}
      end

      macro validate(attribute, **options)
        {% valid_predicates = %w(eq exclude gt gte in lt lte match size presence required confirmation accept) %}
        {% for predicate, expected_value in options %}
          {% unless ["message", "on"].includes?(predicate.stringify) || valid_predicates.includes?(predicate.stringify) %}
            {{ raise "CQL validation error in #{@type}: unsupported predicate `#{predicate}` for `#{attribute}`. Supported predicates: #{valid_predicates.join(", ")}." }}
          {% end %}
        {% end %}
        {% SCHEMA_VALIDATIONS[attribute] = options %}
      end

      macro predicates
        module Predicates
          {{yield}}
        end
      end

      macro create_validator
        {% type_validator = @type %}
        {% for name, options in type_validator.constant(:SCHEMA_VALIDATIONS) %}
          {% unless type_validator.methods.any? { |method| method.name == name.id.stringify } %}
            {{ raise "CQL validation error in #{type_validator}: unknown attribute `#{name}`. Define a readable property or getter for `#{name}` before calling `validate :#{name}`." }}
          {% end %}
          {% for predicate, expected_value in options %}
            {% if predicate.stringify == "confirmation" %}
              {% unless type_validator.methods.any? { |method| method.name == expected_value.id.stringify } %}
                {{ raise "CQL validation error in #{type_validator}: confirmation target `#{expected_value}` for `#{name}` does not exist. Define a readable property or getter for `#{expected_value}` before the validation." }}
              {% end %}
            {% end %}
          {% end %}
        {% end %}

        class Validator
          def self.validate(instance : {{type_validator}}, context = nil)
            errors = Array(Error).new
            rules = Array(Constraint | CustomValidator).new
            validations(rules, instance, context)
            rules.reduce([] of Error) do |errors, rule|
              errors + rule.valid?
            end
          end

          private def self.validations(rules, instance, context = nil)
            {% for validtor in type_validator.constant(:SCHEMA_VALIDATORS) %}
            rules << {{validtor}}.new(instance)
            {% end %}

            rules << Constraint.new do |rule, errors|
              {% for name, options in type_validator.constant(:SCHEMA_VALIDATIONS) %}
                {% if options[:on] %}
                  {% if options[:on] == context || context.nil? %}
                    {% for predicate, expected_value in options %}
                      {% if !["message", "on"].includes?(predicate.stringify) %}
                        {% if predicate.stringify == "confirmation" %}
                        unless rule.confirmation?(instance.{{name.id}}, instance.{{expected_value.id}})
                          errors << Error.new(:{{name.id}}, {{options[:message] || "#{name.id} confirmation doesn't match"}})
                        end
                        {% else %}
                        unless rule.{{predicate.id}}?(instance.{{name.id}}, {{expected_value}})
                          {% default_msg = "Invalid #{name.id}" %}
                          {% if predicate.stringify == "required" %}
                            {% default_msg = "#{name.id} is required" %}
                          {% elsif predicate.stringify == "eq" %}
                            {% default_msg = "#{name.id} must be equal to #{expected_value}" %}
                          {% elsif predicate.stringify == "gt" %}
                            {% default_msg = "#{name.id} must be greater than #{expected_value}" %}
                          {% elsif predicate.stringify == "gte" %}
                            {% default_msg = "#{name.id} must be greater than or equal to #{expected_value}" %}
                          {% elsif predicate.stringify == "lt" %}
                            {% default_msg = "#{name.id} must be less than #{expected_value}" %}
                          {% elsif predicate.stringify == "lte" %}
                            {% default_msg = "#{name.id} must be less than or equal to #{expected_value}" %}
                          {% elsif predicate.stringify == "in" %}
                            {% default_msg = "#{name.id} must be included in #{expected_value}" %}
                          {% elsif predicate.stringify == "exclude" %}
                            {% default_msg = "#{name.id} must not be included in #{expected_value}" %}
                          {% elsif predicate.stringify == "match" %}
                            {% default_msg = "#{name.id} must match the pattern #{expected_value}" %}
                          {% elsif predicate.stringify == "size" %}
                            {% default_msg = "#{name.id} must have a size of #{expected_value}" %}
                          {% elsif predicate.stringify == "presence" %}
                            {% default_msg = "#{name.id} must be present" %}
                          {% elsif predicate.stringify == "accept" %}
                            {% default_msg = "#{name.id} must be accepted" %}
                          {% end %}
                          errors << Error.new(:{{name.id}}, {{options[:message] || default_msg}})
                        end
                        {% end %}
                      {% end %}
                    {% end %}
                  {% end %}
                {% else %}
                  {% for predicate, expected_value in options %}
                    {% if !["message", "on"].includes?(predicate.stringify) %}
                      {% if predicate.stringify == "confirmation" %}
                      unless rule.confirmation?(instance.{{name.id}}, instance.{{expected_value.id}})
                        errors << Error.new(:{{name.id}}, {{options[:message] || "#{name.id} confirmation doesn't match"}})
                      end
                      {% else %}
                      unless rule.{{predicate.id}}?(instance.{{name.id}}, {{expected_value}})
                        {% default_msg = "Invalid #{name.id}" %}
                        {% if predicate.stringify == "required" %}
                          {% default_msg = "#{name.id} is required" %}
                        {% elsif predicate.stringify == "eq" %}
                          {% default_msg = "#{name.id} must be equal to #{expected_value}" %}
                        {% elsif predicate.stringify == "gt" %}
                          {% default_msg = "#{name.id} must be greater than #{expected_value}" %}
                        {% elsif predicate.stringify == "gte" %}
                          {% default_msg = "#{name.id} must be greater than or equal to #{expected_value}" %}
                        {% elsif predicate.stringify == "lt" %}
                          {% default_msg = "#{name.id} must be less than #{expected_value}" %}
                        {% elsif predicate.stringify == "lte" %}
                          {% default_msg = "#{name.id} must be less than or equal to #{expected_value}" %}
                        {% elsif predicate.stringify == "in" %}
                          {% default_msg = "#{name.id} must be included in #{expected_value}" %}
                        {% elsif predicate.stringify == "exclude" %}
                          {% default_msg = "#{name.id} must not be included in #{expected_value}" %}
                        {% elsif predicate.stringify == "match" %}
                          {% default_msg = "#{name.id} must match the pattern #{expected_value}" %}
                        {% elsif predicate.stringify == "size" %}
                          {% default_msg = "#{name.id} must have a size of #{expected_value}" %}
                        {% elsif predicate.stringify == "presence" %}
                          {% default_msg = "#{name.id} must be present" %}
                        {% elsif predicate.stringify == "accept" %}
                          {% default_msg = "#{name.id} must be accepted" %}
                        {% end %}
                        errors << Error.new(:{{name.id}}, {{options[:message] || default_msg}})
                      end
                      {% end %}
                    {% end %}
                  {% end %}
                {% end %}
              {% end %}
            end
          end
        end
      end

      macro included
        SCHEMA_VALIDATORS  = [] of Nil
        SCHEMA_VALIDATIONS = {} of Nil => Nil

        # Check if the record is valid
        # @param context [Symbol?] Optional validation context
        # @return [Bool] True if valid, false otherwise
        def valid?(context = nil)
          errors(context).empty?
        end

        # Validate the record and raise an exception if invalid
        # @param context [Symbol?] Optional validation context
        # @raise [ValidationError] If the record is invalid
        # @return [Bool] True if valid
        def validate!(context = nil)
          errs = errors(context)
          errs.empty? || raise ValidationError.new(errs)
        end

        # Get validation errors
        # @param context [Symbol?] Optional validation context
        # @return [Array(Error)] Array of validation errors
        def errors(context = nil)
          Validator.validate(self, context)
        end

        macro finished
          create_validator
        end
      end
    end
  end
end
