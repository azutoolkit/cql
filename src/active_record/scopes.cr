require "./query"

module CQL
  module ActiveRecord
    module Scopes
      macro included
        # Determine the current model class where the scope is being defined
        CURRENT_MODEL_CLASS = {{@type.id}}
      end

      macro scope(name, scope_proc)
        # I. Define the class method on the model (e.g., Post.published)
        # This method starts a new query chain.
        def self.{{name.id}}(*args)
          # The scope_proc_code (e.g., `-> { where(published: true) }`) is invoked.
          # `self` inside the proc will refer to CURRENT_MODEL_CLASS due to lexical scoping.
          scope_call_result = ({{scope_proc}}).call(*args)

          if scope_call_result.is_a?(CQL::Query)
            # Proc directly returned a raw CQL::Query. Wrap it in Query.
            # Assumes Query(ModelType).new(cql_query) constructor.
            Query({{@type.id}}).new(scope_call_result)
          else
            # Assume scope_call_result is already a Query(CURRENT_MODEL_CLASS) instance
            # or a compatible type as per the original macro's logic.
            scope_call_result
          end
        end

        # Create the instance method for chaining
        def {{name.id}}(*args)
          # Execute the scope_proc_code. `self` inside the proc is CURRENT_MODEL_CLASS.
          # This will typically return a Query(CURRENT_MODEL_CLASS) or a raw CQL::Query.
          scope_logic_result = ({{scope_proc}}).call(*args)

          cql_query_fragment_for_scope : ::CQL::Query
          if scope_logic_result.is_a?(::CQL::Query)
            cql_query_fragment_for_scope = scope_logic_result
          elsif scope_logic_result.is_a?(Query({{@type.id}}))
            # Assumes Query has a `query` getter for its underlying CQL::Query.
            cql_query_fragment_for_scope = scope_logic_result.query
          else
            raise "Scope '{{name.id}}' for model #{CURRENT_MODEL_CLASS}, when applied in a chain, " \
                  "did not produce a compatible CQL::Query or Query(#{{{@type.id}}}). " \
                  "Received: #{scope_logic_result.class}"
          end

          # Merge the new scope's CQL query fragment into the existing query of this Query instance.
          # Assumes `self.query.merge(...)` returns a new, merged CQL::Query instance.
          current_underlying_query = self.query # Assumes .query getter
          new_underlying_query = current_underlying_query.merge(cql_query_fragment_for_scope)

          # Return a new Query instance with the merged query, promoting immutability.
          # Assumes Query(ModelType).new(cql_query) constructor.
          Query({{@type.id}}).new(new_underlying_query)
        end
      end
    end
  end
end
