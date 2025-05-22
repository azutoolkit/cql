module CQL
  module ActiveRecord
    module Scopes
      macro included
        # Determine the current model class where the scope is being defined
        CURRENT_MODEL_CLASS = {{@type.id}}
      end

      macro scope(name_ident, scope_proc_code)


        # I. Define the class method on the model (e.g., Post.published)
        # This method starts a new query chain.
        def self.{{name_ident.id}}(*args)
          # The scope_proc_code (e.g., `-> { where(published: true) }`) is invoked.
          # `self` inside the proc will refer to CURRENT_MODEL_CLASS due to lexical scoping.
          scope_call_result = ({{scope_proc_code}}).call(*args)

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

        create_scope_method(name_ident, scope_proc_code)
      end
    end
  end
end
