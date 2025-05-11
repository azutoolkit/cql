module CQL
  module ActiveRecord
    module Deleteable
      macro included
        # Delete a record by ID
        # - **@param** id [PrimaryKey] The ID of the record
        #
        # **Example** Deleting a record by ID
        #
        # ```
        # User.delete!(1)
        # ```
        def self.delete!(id : Pk)
          CQL::Delete
            .new({{@type.id}}.schema)
            .from({{@type.id}}.table)
            .where(id: id)
            .commit
        end

        # Delete records matching specific fields
        # - **@param** fields [Hash(Symbol, DB::Any)] The fields to match
        #
        # **Example** Deleting records by email
        #
        # ```
        # User.delete_by!(email: "alice@example.com")
        # ```
        def self.delete_by!(**fields)
          CQL::Delete
            .new({{@type.id}}.schema)
            .from({{@type.id}}.table)
            .where(**fields)
            .commit
        end

         # Delete records matching specific fields
        # - **@param** fields [Hash(Symbol, DB::Any)] The fields to match
        #
        # **Example** Deleting records by email
        #
        # ```
        # User.delete_by!(email: "alice@example.com")
        # ```
        def self.delete_by!(fields : Hash(Symbol, DB::Any))
          CQL::Delete
            .new({{@type.id}}.schema)
            .from({{@type.id}}.table)
            .where(fields)
            .commit
        end

        # Delete all records in the table
        #
        # **Example** Deleting all records
        #
        # ```
        # User.delete_all
        # ```
        def self.delete_all
          CQL::Delete
            .new({{@type.id}}.schema)
            .from({{@type.id}}.table)
            .commit
        end

        # Delete the record from the database
        # - **@return** [Bool] True if deleted successfully, false otherwise
        #
        # **Example** Deleting a record
        #
        # ```
        # user.delete
        # ```
        def delete!
          return false if id.nil?

          # Run before destroy callbacks
          return false unless run_callbacks(:before_destroy)

          # Delete the record
          result = {{@type.id}}.delete!(id!)
          success = result.rows_affected > 0

          # Run after destroy callbacks and clear the ID if successful
          if success
            run_callbacks(:after_destroy)
            @id = nil
          end

          success
        end
      end
    end
  end
end
