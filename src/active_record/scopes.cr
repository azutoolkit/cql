require "./queryable"

module CQL
  module ActiveRecord
    # The Scopes module provides a way to define reusable query logic
    # that can be chained with other query methods, similar to Rails ActiveRecord scopes.
    #
    # ## Features
    #
    # - Type-safe scope definitions using macros
    # - Chainable scopes that integrate with QueryBuilder
    # - Support for parameterized scopes
    # - Lazy evaluation for performance
    # - Integration with existing query cache
    # - Support for both lambda and block syntax
    #
    # ## Examples
    #
    # ```
    # class User < CQL::ActiveRecord::Model
    #   include CQL::ActiveRecord::Scopes
    #
    #   # Simple scope without parameters
    #   scope :active, -> { where(active: true) }
    #
    #   # Parameterized scope
    #   scope :by_role, ->(role : String) { where(role: role) }
    #
    #   # Complex scope with multiple conditions
    #   scope :recent, ->(days : Int32 = 7) {
    #     where("created_at > ?", Time.utc - days.days)
    #   }
    #
    #   # Scope that calls other scopes
    #   scope :active_admins, -> { active.by_role("admin") }
    # end
    #
    # # Usage examples:
    # User.active                              # Simple scope
    # User.by_role("admin")                    # Parameterized scope
    # User.active.by_role("admin")             # Chained scopes
    # User.recent(30)                          # Scope with parameter
    # User.active.recent.order(:created_at)    # Mixed with query methods
    # ```
    module Scopes
      macro included
        # Track all defined scopes for debugging and introspection
        @@defined_scopes = {} of String => String

        # Get all defined scopes
        def self.defined_scopes
          @@defined_scopes
        end
      end

      # Define a scope with the given name and query logic
      #
      # The scope_proc should return either:
      # - A QueryBuilder instance (recommended)
      # - A CQL::Query instance (will be wrapped in QueryBuilder)
      #
      # ## Parameters
      # - **name**: The scope name (identifier)
      # - **scope_proc**: A proc/lambda that defines the query logic
      #
      # ## Examples
      #
      # ```
      # # Simple scope
      # scope :published, -> { where(published: true) }
      #
      # # Parameterized scope
      # scope :by_category, ->(category : String) { where(category: category) }
      #
      # # Scope with complex logic
      # scope :recent_and_popular, ->(days : Int32 = 7) {
      #   where("created_at > ?", Time.utc - days.days)
      #     .where("views > ?", 100)
      #     .order(views: :desc)
      # }
      # ```
      macro scope(name, scope_proc)
        # Store scope definition for introspection
        @@defined_scopes[{{name.stringify}}] = {{scope_proc.stringify}}

        # Define the class method (e.g., Post.published)
        def self.{{name.id}}(*args, **kwargs)
          # Create the base query if we're starting fresh
          base_query = query

          # Execute the scope proc with provided arguments
          scope_result = begin
            # Handle different argument patterns
            {% if scope_proc.args.size > 0 %}
              # Scope expects arguments
              ({{scope_proc}}).call(*args, **kwargs)
            {% else %}
              # Scope expects no arguments
              if args.empty? && kwargs.empty?
                ({{scope_proc}}).call
              else
                raise ArgumentError.new("Scope '{{name.id}}' expects no arguments, got #{args.size} positional and #{kwargs.size} keyword arguments")
              end
            {% end %}
          rescue ex : ArgumentError
            raise ex
          rescue ex
            raise ArgumentError.new("Error in scope '{{name.id}}': #{ex.message}")
          end

          # Handle the result based on its type
          case scope_result
          when QueryBuilder({{@type.id}})
            scope_result
          when CQL::Query
            QueryBuilder({{@type.id}}).new(scope_result)
          when Nil
            raise ArgumentError.new("Scope '{{name.id}}' returned nil - scopes must return a QueryBuilder or CQL::Query")
          else
            raise ArgumentError.new("Scope '{{name.id}}' must return a QueryBuilder or CQL::Query, got #{scope_result.class}")
          end
        end

        # Define the instance method for chaining on QueryBuilder
        create_chainable_scope_method({{name}}, {{scope_proc}})
      end

      # Create a scope method that can be chained on QueryBuilder instances
      macro create_chainable_scope_method(name, scope_proc)
        # Add to QueryBuilder class to enable chaining
        class ::CQL::ActiveRecord::Queryable::QueryBuilder(T)
          def {{name.id}}(*args, **kwargs) : QueryBuilder(T) forall T
            # We need to execute the scope in the context of the model class
            # but merge it with the current query

            # Get the model class from the type parameter
            model_class = T

            # Create a fresh query to get the scope result
            scope_query_builder = begin
              # Execute scope proc with a clean query
              fresh_query = QueryBuilder(T).from_model(model_class)

              {% if scope_proc.args.size > 0 %}
                scope_result = ({{scope_proc}}).call(*args, **kwargs)
              {% else %}
                if args.empty? && kwargs.empty?
                  scope_result = ({{scope_proc}}).call
                else
                  raise ArgumentError.new("Scope '{{name.id}}' expects no arguments")
                end
              {% end %}

              case scope_result
              when QueryBuilder(T)
                scope_result
              when CQL::Query
                QueryBuilder(T).new(scope_result)
              else
                raise ArgumentError.new("Scope '{{name.id}}' must return a QueryBuilder or CQL::Query")
              end
            rescue ex : ArgumentError
              raise ex
            rescue ex
              raise ArgumentError.new("Error in scope '{{name.id}}': #{ex.message}")
            end

            # Merge the scope query with the current query
            # This is where we'd need to implement query merging logic
            # For now, we'll create a new QueryBuilder that combines both queries
            merged_query = merge_queries(self.query, scope_query_builder.query)
            QueryBuilder(T).new(merged_query, model_class)
          end

          # Helper method to merge two CQL::Query objects
          private def merge_queries(base_query : CQL::Query, scope_query : CQL::Query) : CQL::Query
            # Use the actual merge functionality from CQL::Query
            base_query.merge(scope_query)
          end
        end
      end

      # Utility methods for scope introspection and debugging
      module ScopeUtilities
        extend self

        # Check if a scope is defined on a model
        def scope_defined?(model_class : Class, scope_name : String) : Bool
          model_class.defined_scopes.has_key?(scope_name)
        end

        # Get the definition of a scope
        def scope_definition(model_class : Class, scope_name : String) : String?
          model_class.defined_scopes[scope_name]?
        end

        # List all scopes defined on a model
        def list_scopes(model_class : Class) : Array(String)
          model_class.defined_scopes.keys
        end
      end
    end
  end
end
