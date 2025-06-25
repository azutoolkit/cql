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
    # - `with_deleted`, `only_deleted` scopes for accessing soft-deleted records
    # - `restore` functionality to undelete records
    # - Integration with existing Active Record patterns
    #
    # ## Usage
    #
    # ```
    # class User < CQL::ActiveRecord::Model(Int32)
    #   db_context AcmeDB, :users
    #   include CQL::ActiveRecord::SoftDeletable
    #
    #   property name : String
    #   property email : String
    #   property deleted_at : Time? = nil
    # end
    #
    # # Basic usage
    # user = User.create!(name: "John", email: "john@example.com")
    # user.delete! # Soft deletes the user (sets deleted_at)
    # User.all     # Returns users without soft-deleted ones
    #
    # # Working with soft-deleted records
    # User.with_deleted  # Returns all users including soft-deleted
    # User.only_deleted  # Returns only soft-deleted users
    # user.restore!      # Restores a soft-deleted user
    # user.force_delete! # Permanently deletes the user
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
        def self.query
          if acts_as_paranoid?
            previous_def.where { {{@type.id}}.table_column(:deleted_at).null}
          else
            previous_def
          end
        end

        # Scope to include soft-deleted records
        scope :with_deleted, -> {
          query_without_soft_delete_filter
        }

        # Scope to show only soft-deleted records
        scope :only_deleted, -> {
          QueryBuilder({{@type.id}}).from_model({{@type.id}}).where {
            {{@type.id}}.table_column(:deleted_at).not_null
          }
        }

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

        # Override delete! to perform soft delete
        def delete! : Bool
          return false if id.nil?

          # Run before destroy callbacks
          return false unless run_callbacks(:before_destroy)

          # Set deleted_at timestamp
          @deleted_at = Time.utc

          # Update the record in the database
          where_attrs = Hash(Symbol, DB::Any).new
          where_attrs[:id] = id!.as(DB::Any)

          update_attrs = Hash(Symbol, DB::Any).new
          update_attrs[:deleted_at] = @deleted_at.as(DB::Any)

          result = {{@type.id}}.update_by(where_attrs, update_attrs)

          success = result.rows_affected > 0

          # Run after destroy callbacks
          if success
            run_callbacks(:after_destroy)
            self.destroyed = true
          end

          success
        end

        # Permanently delete the record from the database
        def force_delete! : Bool
          return false if id.nil?

          # Run before destroy callbacks
          return false unless run_callbacks(:before_destroy)

          # Actually delete the record from the database
          result = {{@type.id}}.force_delete!(id!)
          success = result.rows_affected > 0

          # Run after destroy callbacks and clear the ID if successful
          if success
            run_callbacks(:after_destroy)
            @id = nil
            self.destroyed = true
          end

          success
        end

        # Restore a soft-deleted record
        def restore! : Bool
          return false unless deleted?

          @deleted_at = nil

          # Update the record in the database
          where_attrs = Hash(Symbol, DB::Any).new
          where_attrs[:id] = id!.as(DB::Any)

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
          CQL::Delete
            .new({{@type.id}}.schema)
            .from({{@type.id}}.table)
            .where(id: id)
            .commit
        end

        # Soft delete records matching specific fields
        def self.delete_by!(**fields)
          records = with_deleted.where(**fields).all
          rows_affected = 0_i64

          records.each do |record|
            if record.delete!
              rows_affected += 1
            end
          end

          DB::ExecResult.new(0_i64, rows_affected)
        end

        # Force delete records matching specific fields
        def self.force_delete_by!(**fields)
          CQL::Delete
            .new({{@type.id}}.schema)
            .from({{@type.id}}.table)
            .where(**fields)
            .commit
        end

        # Soft delete all records in the table
        def self.delete_all
          all.each(&.delete!)
        end

        # Force delete all records in the table
        def self.force_delete_all
          CQL::Delete
            .new({{@type.id}}.schema)
            .from({{@type.id}}.table)
            .commit
        end

        # Restore all soft-deleted records
        def self.restore_all
          only_deleted.all.each(&.restore!)
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
