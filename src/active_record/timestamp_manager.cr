module CQL
  module ActiveRecord
    # Module for managing timestamp fields (created_at, updated_at)
    # Provides automatic timestamp handling following Active Record conventions
    #
    # **Features**:
    # - Automatic created_at setting on record creation
    # - Automatic updated_at setting on record modification
    # - Touch functionality for updating timestamps without callbacks
    # - Bulk timestamp updates for multiple records
    #
    # **Example** Using timestamp management
    #
    # ```
    # struct User
    #   include CQL::ActiveRecord::Model(Int64)
    #   db_context AcmeDB, :users
    #
    #   getter id : Int64?
    #   getter name : String
    #   getter created_at : Time?
    #   getter updated_at : Time?
    #
    #   def initialize(@name : String)
    #   end
    # end
    #
    # user = User.new("Alice")
    # user.save  # Automatically sets created_at and updated_at
    # user.touch # Updates updated_at without running callbacks
    # ```
    module TimestampManager
      # Check if the model has a timestamp column
      # - **@param** column_name [Symbol] The timestamp column name
      # - **@return** [Bool] True if the column exists
      #
      # **Example** Checking for timestamp column
      #
      # ```
      # has_timestamp_column?(:created_at) # => true
      # ```
      macro has_timestamp_column?(column_name)
        {{@type.id}}.schema.tables[{{@type.id}}.table].columns[{{column_name}}]?
      end

      # Automatically set timestamp fields before save
      # Sets created_at on create and updated_at on both create and update
      # - **@param** is_new_record [Bool] Whether this is a new record
      # - **@return** [Hash(Symbol, DB::Any)] Hash of timestamp attributes to update
      #
      # **Example** Setting timestamps
      #
      # ```
      # timestamp_attrs = prepare_timestamps(new_record: true)
      # # => {created_at: Time.utc, updated_at: Time.utc}
      # ```
      macro prepare_timestamps(is_new_record)
        current_time = Time.utc
        table = {{@type.id}}.schema.tables[{{@type.id}}.table]
        has_created_at = table.columns[:created_at]?
        has_updated_at = table.columns[:updated_at]?

        timestamp_attrs = {} of Symbol => DB::Any

        if {{is_new_record}} && has_created_at
          timestamp_attrs[:created_at] = current_time.as(DB::Any)
        end

        if has_updated_at
          timestamp_attrs[:updated_at] = current_time.as(DB::Any)
        end

        timestamp_attrs
      end

      # Apply timestamp attributes to the record
      # - **@param** attrs [Hash(Symbol, DB::Any)] Timestamp attributes to apply
      #
      # **Example** Applying timestamps
      #
      # ```
      # apply_timestamps(timestamp_attrs)
      # ```
      macro apply_timestamps(attrs)
        unless {{attrs}}.empty?
          self.attributes({{attrs}}) if self.responds_to?(:attributes)
        end
      end

      # Validate that timestamp columns exist in the table
      # - **@param** fields [Array(Symbol)] Field names to validate
      # - **@raise** [CQL::Error] If any field doesn't exist in the table
      #
      # **Example** Validating timestamp fields
      #
      # ```
      # validate_timestamp_columns([:created_at, :updated_at])
      # ```
      macro validate_timestamp_columns(fields)
        table = {{@type.id}}.schema.tables[{{@type.id}}.table]
        {{fields}}.each do |field_name|
          column = table.columns[field_name]?
          unless column
            raise CQL::Error.new("Unknown column: #{field_name}")
          end
        end
      end
    end
  end
end
