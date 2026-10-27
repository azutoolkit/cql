module CQL
  module ActiveRecord
    module Deleteable
      macro included
        # Internal property to track destroyed state
        @[DB::Field(ignore: true)]
        property destroyed : Bool = false

        # Delete a record by ID
        # - **@param** id [Pk] The ID of the record
        #
        # **Example** Deleting a record by ID
        #
        # ```
        # User.delete!(1)
        # ```
        def self.delete!(id : Pk)
          delete_of(id).commit
        end

        # A delete of the row whose primary key (`primary_key_column`) is *id*.
        protected def self.delete_of(id : Pk) : CQL::Delete
          CQL::Delete.new(schema).from(table)
            .where({primary_key_column => CQL::ActiveRecord::IdChunks.bound(id)})
        end

        # A delete of the rows whose primary key is any of *ids*, already bound (`IdChunks.each`
        # yields them as `DB::Any`, UUIDs as text).
        protected def self.delete_of(ids : Array(DB::Any)) : CQL::Delete
          key = primary_key_expression
          CQL::Delete.new(schema).from(table).where { key.in(ids) }
        end

        # Delete records matching specific fields
        # - **@param** fields [NamedTuple] The fields to match
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
        # User.delete_by!({:email => "alice@example.com"} of Symbol => DB::Any)
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
          delete_of(ids).commit.rows_affected
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

        # Delete the record from the database, applying the `dependent:` strategy of its associations
        # - **@return** [Bool] True if deleted successfully, false otherwise
        # - **@raise** [CQL::ActiveRecord::Relations::BaseRelation::RelationError] If a
        #   `restrict_with_error` association has records; nothing is deleted then
        # - **@raise** [CQL::OptimisticLockError] With `optimistic_locking`, if the row no longer has this
        #   copy's version or is gone; nothing is deleted then
        #
        # **Example** Deleting a record
        #
        # ```
        # user.delete!
        # ```
        def delete!
          return false if id.nil?

          check_delete_restrictions

          # Run before destroy callbacks
          return false unless run_callbacks(:before_destroy)

          success = delete_with_dependents { delete_row! }

          # Run after destroy callbacks and clear the ID if successful
          if success
            run_callbacks(:after_destroy)
            clear_id!
            self.destroyed = true
          end

          success
        end

        # Deletes this record's row and reports whether there was one; `optimistic_locking`
        # overrides it to delete only the version this copy read.
        private def delete_row! : Bool
          {{@type.id}}.delete!(id!).rows_affected > 0
        end
      end
    end
  end
end
