module CQL
  module ActiveRecord
    module Persistence
      macro included
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

        # Save the record to the database or update it if it already exists
        # - **@return** [Bool] True if saved successfully, false otherwise
        #
        # **Example** Saving a record
        #
        # ```
        # user.save
        # ```
        def save
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
            create_success = !@id.nil?
            run_callbacks(:after_create) if create_success
            create_success
          else
            # Update path
            return false unless run_callbacks(:before_update)
            result = update!
            run_callbacks(:after_update) if result
            result
          end

          # Run after save callbacks
          run_callbacks(:after_save) if success

          success
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
        # rescue CQL::RecordInvalid
        #   # Handle validation errors
        # rescue CQL::RecordNotSaved
        #   # Handle other save errors
        # end
        # ```
        def save!
          return true if save
          if errors.any?
            raise CQL::RecordInvalid.new("Record invalid: #{errors.join(", ")}")
          else
            raise CQL::RecordNotSaved.new("Failed to save the record")
          end
        end
      end
    end
  end
end
