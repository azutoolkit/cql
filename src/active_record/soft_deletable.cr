module CQL
  module ActiveRecord
    # The SoftDeletable module provides "paranoid" delete functionality,
    # allowing records to be marked as deleted with a timestamp rather than
    # being physically removed from the database.
    #
    # ## Features
    #
    # - Mark records as deleted using `deleted_at` timestamp
    # - Automatic filtering of soft-deleted records from queries
    # - `with_deleted`, `only_deleted` class methods for accessing soft-deleted records
    # - `restore` functionality to undelete records
    # - Integration with existing Active Record patterns
    #
    # ## Usage
    #
    # The table needs a nullable `deleted_at` column:
    #
    # ```
    # AppDB = CQL::Schema.define(:app_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://./app.db") do
    #   table :accounts do
    #     primary :id, Int64, auto_increment: true
    #     column :name, String
    #     column :deleted_at, Time, null: true
    #   end
    # end
    #
    # class Account
    #   include CQL::ActiveRecord::Model(Int64)
    #   include CQL::ActiveRecord::SoftDeletable # adds property deleted_at : Time?
    #   db_context AppDB, :accounts
    #
    #   property name : String = ""
    #
    #   def initialize
    #   end
    # end
    #
    # # Basic usage
    # account = Account.create!(name: "John")
    # account.delete! # Soft deletes the account (sets deleted_at)
    # Account.all     # Returns accounts without soft-deleted ones
    #
    # # Working with soft-deleted records
    # Account.with_deleted.all # Returns all accounts including soft-deleted
    # Account.only_deleted.all # Returns only soft-deleted accounts
    # account.restore!         # Restores a soft-deleted account
    # account.force_delete!    # Permanently deletes the account
    # ```
    module SoftDeletable
      macro included
        # Add deleted_at timestamp tracking
        property deleted_at : Time? = nil

        # Mark the model as soft deletable
        @@_acts_as_paranoid = true

        # Define class method to check if model uses soft deletes
        def self.acts_as_paranoid?
          @@_acts_as_paranoid
        end

        # Override the base query method to automatically exclude soft-deleted records
        @[CQL::ActiveRecord::StaticQuery]
        def self.query
          if acts_as_paranoid?
            previous_def.where { {{@type.id}}.table_column(:deleted_at).null}
          else
            previous_def
          end
        end

        # Every record, soft-deleted ones included. It starts a query: once `query` has filtered out
        # the soft-deleted rows, no later call can bring them back.
        def self.with_deleted
          query_without_soft_delete_filter
        end

        # Only the soft-deleted records; like `with_deleted`, it starts a query.
        def self.only_deleted
          query_without_soft_delete_filter.where { {{@type.id}}.table_column(:deleted_at).not_null }
        end

        # Helper method to get query without soft delete filter
        def self.query_without_soft_delete_filter
          QueryBuilder({{@type.id}}).from_model({{@type.id}})
        end

        # Check if this record is soft deleted
        def deleted? : Bool
          !@deleted_at.nil?
        end

        # Check if this record is not soft deleted
        def persisted? : Bool
          !new_record? && !deleted?
        end

        # Override delete! to perform soft delete; the `dependent:` strategies of the associations
        # still apply, and `restore!` does not undo them. An already soft deleted record is left as it
        # is (false, no callbacks), so it keeps its first `deleted_at`.
        def delete! : Bool
          return false if id.nil? || deleted?

          check_delete_restrictions

          # Run before destroy callbacks
          return false unless run_callbacks(:before_destroy)

          timestamp = Time.utc

          # Update the record in the database
          where_attrs = {self.class.primary_key_column => CQL::ActiveRecord::IdChunks.bound(id!)}

          update_attrs = Hash(Symbol, DB::Any).new
          update_attrs[:deleted_at] = timestamp.as(DB::Any)

          success = delete_with_dependents { {{@type.id}}.update_by(where_attrs, update_attrs).rows_affected > 0 }

          # Run after destroy callbacks
          if success
            undo_soft_delete_on_rollback
            @deleted_at = timestamp
            run_callbacks(:after_destroy)
            self.destroyed = true
          end

          success
        end

        # Permanently delete the record from the database, applying the `dependent:` strategies
        def force_delete! : Bool
          return false if id.nil?

          check_delete_restrictions

          # Run before destroy callbacks
          return false unless run_callbacks(:before_destroy)

          success = delete_with_dependents { {{@type.id}}.force_delete!(id!).rows_affected > 0 }

          # Run after destroy callbacks and clear the ID if successful
          if success
            run_callbacks(:after_destroy)
            undo_delete_on_rollback
            clear_id!
            self.destroyed = true
          end

          success
        end

        # A rollback undoes a soft delete or a restore, so the record's `deleted_at` is what its row holds again.
        private def undo_soft_delete_on_rollback : Nil
          deleted_at, destroyed = @deleted_at, self.destroyed
          {{@type.id}}.schema.on_rollback { @deleted_at = deleted_at; self.destroyed = destroyed }
        end

        # Restore a soft-deleted record
        def restore! : Bool
          return false unless deleted?

          undo_soft_delete_on_rollback
          @deleted_at = nil

          # Update the record in the database
          where_attrs = {self.class.primary_key_column => CQL::ActiveRecord::IdChunks.bound(id!)}

          update_attrs = Hash(Symbol, DB::Any).new
          update_attrs[:deleted_at] = nil.as(DB::Any)

          result = {{@type.id}}.update_by(where_attrs, update_attrs)

          success = result.rows_affected > 0

          if success
            self.destroyed = false
          end

          success
        end

        # Class method to restore a record by ID
        def self.restore!(id : Pk) : Bool
          record = with_deleted.find(id)
          return false unless record && record.deleted?
          record.restore!
        end

        # Delete a record by ID (soft delete)
        def self.delete!(id : Pk)
          record = with_deleted.find(id)
          return false unless record

          success = record.delete!
          success
        end

        # Force delete a record by ID (permanent delete)
        def self.force_delete!(id : Pk)
          delete_of(id).commit
        end

        # Soft delete records matching specific fields, record by record in one transaction
        def self.delete_by!(**fields)
          rows_affected = 0_i64

          schema.transaction do
            with_deleted.where(**fields).all.each do |record|
              rows_affected += 1 if record.delete!
            end
          end

          DB::ExecResult.new(rows_affected: rows_affected, last_insert_id: 0_i64)
        end

        # Force delete records matching specific fields
        def self.force_delete_by!(**fields)
          CQL::Delete
            .new({{@type.id}}.schema)
            .from({{@type.id}}.table)
            .where(**fields)
            .commit
        end

        # Soft deletes a chunk of ids for `delete_ids`: sets `deleted_at` instead of deleting.
        protected def self.delete_chunk(ids : Array(DB::Any)) : Int64
          set_deleted_at(ids, Time.utc)
        end

        # Soft deleting only stamps rows not already deleted, so their first `deleted_at` stands and
        # the count is of rows this call deleted.
        private def self.set_deleted_at(ids : Array(DB::Any), value : Time?) : Int64
          keys = primary_key_expression.in(ids)
          deleted_at = ::Expression::Column.new(cql_column(:deleted_at))
          rows = value ? keys & deleted_at.null : keys
          CQL::Update.new(schema).table(table).set({:deleted_at => value.as(DB::Any)})
            .where { rows }
            .commit.rows_affected
        end

        # Soft deletes every active record and returns how many, in bulk unless the model
        # declares destroy callbacks.
        def self.delete_all : Int64
          query.delete_all
        end

        # Force delete all records in the table
        def self.force_delete_all
          CQL::Delete
            .new({{@type.id}}.schema)
            .from({{@type.id}}.table)
            .commit
        end

        # Restores every soft-deleted record with one UPDATE per chunk of ids and returns how many.
        def self.restore_all : Int64
          sum_over_id_chunks(only_deleted.ids(as: stored_id_type)) { |chunk| set_deleted_at(chunk, nil) }
        end

        # Count including soft-deleted records
        def self.count_with_deleted(column : Symbol = :*)
          with_deleted.count(column)
        end

        # Count only soft-deleted records
        def self.count_only_deleted(column : Symbol = :*)
          only_deleted.count(column)
        end
    end
    end
  end
end
