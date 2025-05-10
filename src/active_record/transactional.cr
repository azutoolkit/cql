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
            block.call(tx)
          end
        end
      end
    end
  end
end
