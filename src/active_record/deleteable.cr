module CQL
  module ActiveRecord
    module Deleteable
      macro included
        # Internal property to track destroyed state
        @[DB::Field(ignore: true)]
        property destroyed : Bool = false

        # Delete a record by ID
        # - **@param** id [PrimaryKey] The ID of the record
        #
        # **Example** Deleting a record by ID
        #
        # ```
        # User.delete!(1)
        # ```
        def self.delete!(id : Pk)
          {% if Pk == UUID %}
            CQL::Delete
              .new({{@type.id}}.schema)
              .from({{@type.id}}.table)
              .where(id: id.to_s)
              .commit
          {% else %}
            CQL::Delete
              .new({{@type.id}}.schema)
              .from({{@type.id}}.table)
              .where(id: id)
              .commit
          {% end %}
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

        # Deletes the rows with *ids* without callbacks, one statement per chunk of the dialect's
        # bind limit, and returns the number deleted.
        def self.delete_ids(ids : Array) : Int64
          sum_over_id_chunks(ids) { |chunk| delete_chunk(chunk) }
        end

        # Runs the block for each chunk of *ids* that fits one statement beside one other bound
        # value, and sums the rows it reports.
        protected def self.sum_over_id_chunks(ids : Array, & : Array(DB::Any) -> Int64) : Int64
          total = 0_i64
          CQL::ActiveRecord::IdChunks.each(ids, adapter.dialect.max_bind_params - 1) { |chunk| total += yield chunk }
          total
        end

        # The type ids are stored as (UUIDs as strings), for reading them back.
        def self.stored_id_type
          {% if Pk == UUID %}String{% else %}Pk{% end %}
        end

        # The statement `delete_ids` sends for one chunk of ids (soft deletes update instead).
        protected def self.delete_chunk(ids : Array(DB::Any)) : Int64
          CQL::Delete.new(schema).from(table).where(id: ids).commit.rows_affected
        end

        # Check if the record has been destroyed (deleted from the database)
        # - **@return** [Bool] True if the record has been destroyed, false otherwise
        #
        # **Example** Checking if the record is destroyed
        # ```
        # user.destroyed?
        # ```
        def destroyed?
          destroyed
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
            clear_id!
            self.destroyed = true
          end

          success
        end
      end
    end
  end
end
