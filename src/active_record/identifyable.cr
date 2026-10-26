module CQL
  module ActiveRecord
    module Identifyable
      macro included
        {% if Pk == UUID %}
          # For UUID primary keys, store as String internally for DB compatibility
          # but expose as UUID for type safety
          @[DB::Field(key: "id")]
          @_id_storage : String? = nil

          def id : UUID?
            @_id_storage.try { |s| UUID.new(s) }
          end

          def id! : UUID
            UUID.new(@_id_storage.not_nil!)
          end

          def id=(id : UUID)
            @_id_storage = id.to_s
          end

          def id? : UUID?
            @_id_storage.try { |s| UUID.new(s) }
          end

          # Clear the ID (used after deletion)
          protected def clear_id!
            @_id_storage = nil
          end
        {% else %}
          @id : Pk? = nil

          # The record's ID, nil until it is saved
          # - **@return** [Pk?] The ID
          #
          # **Example** Getting the ID of a record
          #
          # ```
          # User.new("Alice", "alice@example.com").id # => nil
          # ```
          def id : Pk?
            @id
          end

          # The record's ID; raises `NilAssertionError` when it has none
          # - **@return** [Pk] The ID
          #
          # **Example** Getting the ID of a saved record
          #
          # ```
          # user.save
          # user.id!
          # ```
          def id! : Pk
            @id.not_nil!
          end

          # Set the record's ID
          # - **@param** id [Pk] The ID
          #
          # **Example** Setting the ID of a record
          #
          # ```
          # user.id = 1
          # ```
          def id=(id : Pk)
            @id = id
          end

          # Same as `id`: the record's ID, nil until it is saved
          # - **@return** [Pk?] The ID
          #
          # **Example** Getting the ID of a record
          #
          # ```
          # User.new("Alice", "alice@example.com").id? # => nil
          # ```
          def id? : Pk?
            @id
          end

          # Clear the ID (used after deletion)
          protected def clear_id!
            @id = nil
          end
        {% end %}
      end
    end
  end
end
