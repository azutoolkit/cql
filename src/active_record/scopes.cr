module CQL
  module ActiveRecord
    module Scopes
      macro scope(name_ident, scope_proc)
        def self.{{name_ident.id}}(*args)
          scope_result = {{scope_proc}}.call(*args)

          if scope_result.is_a?(::CQL::Query)
            # If the scope's proc returns a base CQL::Query,
            # wrap it in ChainableQuery to make it chainable.
            # `self` refers to the model class (e.g., Post).
            ChainableQuery({{@type.id}}).new(scope_result)
          else
            # Otherwise, assume the proc already returned a ChainableQuery
            # or another intended type.
            scope_result
          end
        end
      end
    end
  end
end
