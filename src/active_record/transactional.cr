module CQL
  module ActiveRecord
    module Transactional
      macro included
        # Defines a class method `transaction` on the model.
        # This method will use the model's schema to execute a database transaction.
        #
        # Example (with transaction object):
        # ```
        # User.transaction do |tx|
        #   # Operations within this block are part of the transaction
        #   user = User.create!(name: "John Doe")
        #   user.update!(email: "john.doe@example.com")
        #   # If any exception is raised here, the transaction will be rolled back.
        #   # tx.rollback # to manually rollback
        # end
        # ```
        def self.transaction(&block : DB::Transaction -> _)
          self.schema.transaction do |tx|
            yield tx
          end
        end

        # Defines a class method `transaction` that takes an existing transaction
        # to create a nested transaction (SAVEPOINT).
        #
        # This method allows for operations to be grouped within a savepoint
        # of an outer transaction. If the block raises an exception or if
        # `tx.rollback` is called on the yielded transaction object, only
        # the operations within this nested block (since the savepoint)
        # will be rolled back. The outer transaction will remain active.
        #
        # Example (nested transaction):
        # ```
        # User.transaction do |outer_tx|
        #   # Operations in outer transaction
        #   User.create!(name: "Outer User")
        #
        #   User.transaction(outer_tx) do |inner_tx|
        #     # Operations in nested transaction (savepoint)
        #     user = User.create!(name: "Inner User")
        #     # If an error occurs here, or if inner_tx.rollback is called,
        #     # only the creation of "Inner User" is rolled back.
        #     # The "Outer User" would still be part of the outer_tx,
        #     # pending commit or rollback of outer_tx.
        #     # inner_tx.rollback # to manually rollback the nested part
        #   end
        #
        #   # Outer transaction continues...
        # end
        # ```
        def self.transaction(existing_tx : DB::Transaction, &block : DB::Transaction -> _)
          # Call 'transaction' ON THE EXISTING TRANSACTION OBJECT to create a nested transaction/savepoint
          existing_tx.transaction do |nested_db_tx|
            # Use the schema's overloaded transaction method to manage @active_connection
            # for the duration of this nested block, passing the new nested_db_tx.
            self.schema.transaction(nested_db_tx) do |tx_for_block|
              # tx_for_block will be nested_db_tx, correctly yielded to the user's block.
              yield tx_for_block
            end
          end
        end
      end
    end
  end
end
