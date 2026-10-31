module CQL
  module ActiveRecord
    # Applies the `dependent:` strategies of a model's associations when a record is deleted.
    #
    # `has_many` and `has_one` register an association when it declares `dependent:`;
    # `many_to_many` always registers one, so deleting a record removes its join rows.
    # A `restrict_with_error` association is checked before anything is deleted; the others
    # run in declaration order, in the same transaction as the record's own delete.
    module Dependents
      macro included
        RESTRICTING_ASSOCIATIONS = [] of Symbol
        DEPENDENT_ASSOCIATIONS   = [] of Symbol

        # Registers an association whose records prevent deleting the owner.
        macro restrict_delete_by(name)
          \{% RESTRICTING_ASSOCIATIONS << name %}
        end

        # Registers an association whose `dependent:` strategy runs when the owner is deleted.
        macro apply_on_delete(name)
          \{% DEPENDENT_ASSOCIATIONS << name %}
        end

        # Whether `delete!` applies `dependent:` strategies. Bulk deletes go record by record then,
        # so the strategies run.
        def self.delete_applies_dependents? : Bool
          \{{ !RESTRICTING_ASSOCIATIONS.empty? || !DEPENDENT_ASSOCIATIONS.empty? }}
        end

        # Raises `RelationError` when a `restrict_with_error` association still has records.
        private def check_delete_restrictions : Nil
          \{% for name in RESTRICTING_ASSOCIATIONS %}
            handle_\{{name.id}}_dependency
          \{% end %}
        end

        # Applies each registered strategy and then deletes the row with the block, in one
        # transaction (a savepoint when one is already open), and returns the block's result.
        private def delete_with_dependents(& : -> Bool) : Bool
          \{% if DEPENDENT_ASSOCIATIONS.empty? %}
            yield
          \{% else %}
            deleted = false
            persistence_schema.transaction do
              \{% for name in DEPENDENT_ASSOCIATIONS %}
                handle_\{{name.id}}_dependency
              \{% end %}
              deleted = yield
            end
            deleted
          \{% end %}
        end
      end
    end
  end
end
