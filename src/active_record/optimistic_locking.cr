module CQL
  module ActiveRecord
    # Provides optimistic locking functionality for Active Record models.
    # This module allows you to prevent concurrent updates from overwriting each other
    # by using a version column in the database.
    #
    # ## Usage
    #
    # Include this module in your model:
    #
    # ```
    # class User < CQL::ActiveRecord::Base
    #   include CQL::ActiveRecord::OptimisticLocking
    #
    #   optimistic_locking column_name: :version_number
    # end
    # ```
    #
    # The table should have a version column:
    #
    # ```
    # schema.create_table :users do |t|
    #   t.primary :id, Int64
    #   t.column :name, String
    #   t.column :email, String
    #   t.lock_version :version_number
    # end
    # ```
    #
    # When updating a record, any concurrent updates will be detected:
    #
    # ```
    # user = User.find!(1)
    # # Somebody else updates this record in another process
    # begin
    #   user.update!(name: "New Name") # This will fail
    # rescue CQL::OptimisticLockError
    #   # Handle concurrent update
    #   user.reload!                   # Get the latest version
    #   user.update!(name: "New Name") # Try again
    # end
    # ```
    module OptimisticLocking
      # Define optimistic locking for a model
      # Specifies optimistic locking settings for the model.
      # - **@param** column_name [Symbol] the name of the version column (default: :version)
      #
      # **Example**
      #
      # ```
      # class User < CQL::ActiveRecord::Base
      #   include CQL::ActiveRecord::OptimisticLocking
      #
      #   optimistic_locking column_name: :version
      # end
      # ```
      macro optimistic_locking(version_column = :lock_version)
        # Store the name of the version column
        class_getter version_column : Symbol = {{version_column}}

        # Update a record using optimistic locking
        def self.update_with_lock!(record : {{@type.id}})
          raise CQL::Error.new("Record must be persisted for optimistic locking") unless record.persisted?
          lock_version_col = :{{version_column.id}}

          current_version = record.{{version_column.id}}
          raise CQL::Error.new("Version value missing for optimistic locking") if current_version.nil?

          CQL::Update
            .new({{@type.id}}.schema)
            .table({{@type.id}}.table)
            .set(record.attributes)
            .where(id: record.id!)
            .with_optimistic_lock(current_version.as(Pk), lock_version_col)
            .commit

          # If successful (no exception), increment the local version to match DB
          record.{{version_column.id}} = current_version.as(Pk) + 1
          record
        end

        # Override the standard update! method to use optimistic locking
        def update!
          {{@type.id}}.update_with_lock!(self)
        end
      end
    end
  end
end
