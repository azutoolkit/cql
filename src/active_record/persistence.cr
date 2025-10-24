require "./timestamp_manager"

module CQL
  module ActiveRecord
    module Persistence
      macro included
        include CQL::ActiveRecord::TimestampManager
        # Reload the record from the database
        # - **@return** [Nil]
        #
        # **Example** Reloading a record
        #
        # ```
        # user.reload!
        # ```
        def reload!
          record = {{@type.id}}.find!(id!)
          self.attributes(record.attributes)
          self
        end

        # Check if the record has been persisted to the database
        # - **@return** [Bool] True if the record has an ID, false otherwise
        #
        # **Example** Checking if the record is persisted
        # ```
        # user.persisted?
        # ```
        def persisted?
          !id.nil?
        end

        # Check if the record is a new record (not yet saved to the database)
        # - **@return** [Bool] True if the record is new (no ID), false if persisted
        #
        # **Example** Checking if the record is new
        # ```
        # user.new_record?
        # ```
        def new_record?
          id.nil?
        end

        # Touch one or more timestamp attributes without triggering callbacks
        # Updates the specified timestamp fields to the current time and saves
        # directly to the database without running validations or callbacks.
        #
        # - **@param** *fields [Symbol] The timestamp fields to update (defaults to :updated_at)
        # - **@param** time [Time] The time to set (defaults to Time.utc)
        # - **@return** [Bool] True if the touch operation was successful
        # - **@raise** [CQL::Error] If the record is not persisted
        #
        # **Example** Touch the updated_at timestamp
        #
        # ```
        # user.touch
        # ```
        #
        # **Example** Touch specific timestamp fields
        #
        # ```
        # user.touch(:last_seen_at, :updated_at)
        # ```
        #
        # **Example** Touch with a specific time
        #
        # ```
        # user.touch(:updated_at, time: Time.utc - 1.hour)
        # ```
        def touch(*fields, time : Time = Time.utc)
          raise CQL::Error.new("Cannot touch on a new record object") unless persisted?

          # Default to :updated_at if no fields specified
          touch_fields = fields.empty? ? [:updated_at] : fields.to_a

          # Build the attributes hash for the update
          attrs = {} of Symbol => DB::Any
          touch_fields.each do |field|
            attrs[field] = time.as(DB::Any)
          end

          # Get the table schema to validate the columns exist
          table = {{@type.id}}.schema.tables[{{@type.id}}.table]
          attrs.each do |field_name, _|
            column = table.columns[field_name]?
            unless column
              raise CQL::Error.new("Unknown column: #{field_name}")
            end
            # Note: For now, we skip timestamp validation to focus on core functionality
            # In production, you may want to validate that these are timestamp columns
          end

          # Update the database directly without callbacks
          result = CQL::Update
            .new({{@type.id}}.schema)
            .table({{@type.id}}.table)
            .set(attrs)
            .where(id: id!)
            .commit

          # Update the local instance attributes to match
          if result.rows_affected > 0
            # Update the local attributes using the attributes setter if available
            attrs_for_local_update = {} of Symbol => DB::Any
            touch_fields.each do |field|
              attrs_for_local_update[field] = time.as(DB::Any)
            end
            self.attributes(attrs_for_local_update) if self.responds_to?(:attributes)
            true
          else
            false
          end
        end

        # Touch the updated_at timestamp
        # Convenience method that calls touch with :updated_at
        # - **@param** time [Time] The time to set (defaults to Time.utc)
        # - **@return** [Bool] True if the touch operation was successful
        #
        # **Example** Touch the updated_at timestamp
        #
        # ```
        # user.touch!
        # ```
        def touch!(time : Time = Time.utc)
          touch(:updated_at, time: time)
        end

                # Class method to touch multiple records by IDs without callbacks
        # Updates the specified timestamp fields for multiple records
        # - **@param** ids [Array(Pk)] The IDs of the records to touch
        # - **@param** *fields [Symbol] The timestamp fields to update (defaults to :updated_at)
        # - **@param** time [Time] The time to set (defaults to Time.utc)
        # - **@return** [Int64] Number of records touched
        #
        # **Example** Touch multiple records
        #
        # ```
        # User.touch_all([1, 2, 3])
        # User.touch_all([1, 2, 3], :last_seen_at, :updated_at)
        # ```
        def self.touch_all(ids : Array(Pk), *fields, time : Time = Time.utc)
          return 0_i64 if ids.empty?

          # Default to :updated_at if no fields specified
          touch_fields = fields.empty? ? [:updated_at] : fields.to_a

          # Build the attributes hash for the update
          attrs = {} of Symbol => DB::Any
          touch_fields.each do |field|
            attrs[field] = time.as(DB::Any)
          end

          # Get the table schema to validate the columns exist
          table = {{@type.id}}.schema.tables[{{@type.id}}.table]
          attrs.each do |field_name, _|
            column = table.columns[field_name]?
            unless column
              raise CQL::Error.new("Unknown column: #{field_name}")
            end
            # Note: For now, we skip timestamp validation to focus on core functionality
            # In production, you may want to validate that these are timestamp columns
          end

          # Update multiple records directly without callbacks using IN clause
          result = CQL::Update
            .new({{@type.id}}.schema)
            .table({{@type.id}}.table)
            .set(attrs)
            .where(id: ids.map(&.as(DB::Any)))
            .commit

          result.rows_affected
        end

        # Save the record to the database or update it if it already exists
        # - **@return** [Bool] True if saved successfully, false otherwise
        #
        # **Example** Saving a record
        #
        # ```
        # user.save
        # ```
        def save
          # Set timestamps before running callbacks
          set_timestamps!

          # Run validation callbacks first
          return false unless run_callbacks(:before_validation)
          return false unless run_callbacks(:after_validation)

          # Validate the record
          return false unless validate!

          # Run before save callbacks
          return false unless run_callbacks(:before_save)

          # Save the record
          success = if !persisted?
            # Create path
            return false unless run_callbacks(:before_create)
            result = create!
            @id = result.id if result
            create_success = !result.nil?
            run_callbacks(:after_create) if create_success
            create_success
          else
            # Update path
            return false unless run_callbacks(:before_update)
            result = update!
            @id = result.id if result
            update_success = !result.nil?
            run_callbacks(:after_update) if update_success
            update_success
          end

          # Run after save callbacks
          run_callbacks(:after_save) if success

          success
        end

        # Automatically set timestamp fields before save
        # Sets created_at on create and updated_at on both create and update
        # Uses TimestampManager module for consistent timestamp handling
        private def set_timestamps!
          timestamp_attrs = prepare_timestamps(!persisted?)
          apply_timestamps(timestamp_attrs)
        end

        # Save the record to the database or update it if it already exists
        # Raises an exception if the record cannot be saved
        # - **@return** [Bool] Always returns true when successful
        # - **@raise** [CQL::RecordInvalid] If the record is invalid
        # - **@raise** [CQL::RecordNotSaved] If the record cannot be saved for other reasons
        #
        # **Example** Saving a record with exception handling
        #
        # ```
        # begin
        #   user.save!
        # rescue ex : CQL::RecordInvalid
        #   # Handle validation errors
        #   puts "Validation failed: #{ex.error_messages.join(", ")}"
        # rescue ex : CQL::RecordNotSaved
        #   # Handle other save errors
        #   puts "Save failed: #{ex.message}"
        # end
        # ```
        def save!
          return true if save
          validation_errors = errors
          if validation_errors.any?
            error_summary = validation_errors.map { |e| "#{e.field}: #{e.message}" }.join(", ")
            # Convert validation errors to NamedTuple format for exception
            error_tuples = validation_errors.map { |e| {field: e.field, message: e.message} }
            raise CQL::RecordInvalid.new("Record invalid: #{error_summary}", error_tuples)
          else
            raise CQL::RecordNotSaved.new("Failed to save the record")
          end
        end
      end
    end
  end
end
