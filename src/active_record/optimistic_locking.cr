module CQL
  module ActiveRecord
    # Provides optimistic locking functionality for Active Record models.
    # This module allows you to prevent concurrent updates from overwriting each other
    # by using a version column in the database.
    #
    # ## Usage
    #
    # Give the table a version column and include this module in the model, naming that column.
    # The `lock_version` table helper names it `version` unless told otherwise, while a bare
    # `optimistic_locking` reads `lock_version`, so pass `version_column:`:
    #
    # ```
    # AppDB = CQL::Schema.define(:app_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://./app.db") do
    #   table :documents do
    #     primary :id, Int64, auto_increment: true
    #     text :title
    #     lock_version :version
    #   end
    # end
    #
    # class Document
    #   include CQL::ActiveRecord::Model(Int64)
    #   include CQL::ActiveRecord::OptimisticLocking
    #   db_context AppDB, :documents
    #
    #   property title : String = ""
    #   property version : Int32 = 1
    #
    #   optimistic_locking version_column: :version
    #
    #   def initialize
    #   end
    # end
    #
    # # When updating a record, a concurrent update is detected:
    # document = Document.find!(1)
    # # Somebody else updates this record in another process
    # begin
    #   document.update!(title: "New Title") # raises: the version moved on
    # rescue CQL::OptimisticLockError
    #   document.reload!                     # Get the latest version
    #   document.update!(title: "New Title") # Try again
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

          # If successful (no exception), increment the local version to match DB; a rollback puts it back
          undo = record.persistence_snapshot
          schema.on_rollback { record.{{version_column.id}} = current_version; undo.call }
          record.{{version_column.id}} = current_version + 1
          record.clear_changes! if record.responds_to?(:clear_changes!)
          record
        end

        # Override the standard update! method to use optimistic locking
        def update!
          {{@type.id}}.update_with_lock!(self)
        end

        # Deletes the row only while it still holds the version this copy read, so a row another
        # process changed or already deleted raises instead of being deleted or reported as false.
        private def delete_row! : Bool
          expected = self.{{version_column.id}}
          raise CQL::Error.new("Version value missing for optimistic locking") if expected.nil?
          return true if {{@type.id}}.delete_of(id!).where({{version_column.id}}: expected).commit.rows_affected > 0
          # The id stays out of the error: its message ends up in logs, and a key can be a natural one
          raise CQL::OptimisticLockError.new(model_class: self.class.name, expected_version: expected)
        end
      end
    end
  end
end
