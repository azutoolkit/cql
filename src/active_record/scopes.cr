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
    #   scope :recent, ->(days : Int32) {
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
    # User.active.recent(7).order(:created_at) # Mixed with query methods
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
      # The body runs on the query the scope is called on, as if it were written there: chained after
      # other query methods it adds to them, and `Model.name` runs it on `Model.query`. Call the
      # builder's methods (`where`, `order`, ...) in it; a bare `query` is the receiver's `CQL::Query`,
      # which `where` changes in place, and a body that starts its own query (`Post.query...`)
      # replaces the chain.
      #
      # The body returns either:
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
      # scope :recent_and_popular, ->(days : Int32) {
      #   where("created_at > ?", Time.utc - days.days)
      #     .where("views > ?", 100)
      #     .order(views: :desc)
      # }
      # ```
      macro scope(name, scope_proc)
        # Store scope definition for introspection
        @@defined_scopes[{{name.id.stringify}}] = {{scope_proc.stringify}}

        # Define the class method (e.g., Post.published)
        def self.{{name.id}}(*args, **kwargs)
          query.{{name.id}}(*args, **kwargs)
        end

        # The scope's body run on *cql_builder*; `QueryBuilder#{{name.id}}` dispatches here.
        def self._scope_{{name.id}}(cql_builder, {% if scope_proc.args.empty? %}*args, **kwargs{% else %}{{scope_proc.args.splat}}{% end %})
          {% if scope_proc.args.empty? %}
            CQL::ActiveRecord::Scopes.expect_no_arguments({{name.id.stringify}}, args, kwargs)
          {% end %}
          result = CQL::ActiveRecord::Scopes.evaluate({{name.id.stringify}}, cql_builder) do
            {{scope_proc.body}}
          end

          case result
          when QueryBuilder({{@type.id}})
            result
          when CQL::Query
            QueryBuilder({{@type.id}}).new(result)
          when Nil
            raise ArgumentError.new("Scope '{{name.id}}' returned nil - scopes must return a QueryBuilder or CQL::Query")
          else
            raise ArgumentError.new("Scope '{{name.id}}' must return a QueryBuilder or CQL::Query, got #{result.class}")
          end
        end

        # Every model's builder gets the same method, which runs the scope of the builder's model
        class ::CQL::ActiveRecord::Queryable::QueryBuilder(T)
          def {{name.id}}(*args, **kwargs)
            T._scope_{{name.id}}(self, *args, **kwargs)
          end
        end
      end

      def self.expect_no_arguments(name : String, args : Tuple, kwargs : NamedTuple) : Nil
        return if args.empty? && kwargs.empty?
        raise ArgumentError.new("Scope '#{name}' expects no arguments, got #{args.size} positional and #{kwargs.size} keyword arguments")
      end

      # Runs a scope's body with *builder* as the receiver of its unqualified calls; a call the
      # builder does not answer goes to the model.
      def self.evaluate(name : String, builder, &)
        with builder yield
      rescue ex : ArgumentError
        raise ex
      rescue ex
        raise ArgumentError.new("Error in scope '#{name}': #{ex.message}")
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
