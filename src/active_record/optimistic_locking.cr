module CQL
  module ActiveRecord
    # Provides optimistic locking functionality for Active Record models.
    # This module allows you to prevent concurrent updates from overwriting each other
    # by using a version column in the database.
    #
    # ## Usage
    #
    # Include this module in your model and name its version column:
    #
    # ```
    # class User
    #   include CQL::ActiveRecord::Model(Int64)
    #   include CQL::ActiveRecord::OptimisticLocking
    #   db_context AppDB, :users
    #
    #   property name : String = ""
    #   property version : Int32 = 1
    #
    #   optimistic_locking version_column: :version
    # end
    # ```
    #
    # The table needs that column. The `lock_version` table helper names it `version` unless told
    # otherwise, while a bare `optimistic_locking` reads `lock_version`, so pass `version_column:`:
    #
    # ```
    # AppDB = CQL::Schema.define(:app_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://./app.db") do
    #   table :users do
    #     primary :id, Int64, auto_increment: true
    #     text :name
    #     lock_version :version
    #   end
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
      # - **@param** version_column [Symbol] the name of the version column (default: :lock_version)
      #
      # **Example**
      #
      # ```
      # optimistic_locking version_column: :version
      # ```
      macro optimistic_locking(version_column = :lock_version)
        # Store the name of the version column
        class_getter version_column : Symbol = {{version_column}}

        # Update a record using optimistic locking
        def self.update_with_lock!(record : {{@type.id}})
          raise CQL::Error.new("Record must be persisted for optimistic locking") if record.new_record?
          if record.responds_to?(:stamp_deferred_update)
            return record unless record.changed?
            record.stamp_deferred_update(record.changed_columns)
          end
          lock_version_col = :{{version_column.id}}

          current_version = record.{{version_column.id}}
          raise CQL::Error.new("Version value missing for optimistic locking") if current_version.nil?

          # The key only scopes the row, and the lock writes the next version itself
          attrs = record.attributes
          attrs.delete(primary_key_column)
          attrs.delete(lock_version_col)

          update_of(record.id!)
            .set(attrs)
            .with_optimistic_lock(current_version, lock_version_col)
            .commit

          # If successful (no exception), increment the local version to match DB
          record.{{version_column.id}} = current_version + 1
          record.clear_changes! if record.responds_to?(:clear_changes!)
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
