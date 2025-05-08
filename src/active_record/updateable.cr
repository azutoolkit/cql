module CQL
  module ActiveRecord
    module Updateable
      macro included
        # Update a record by ID with given attributes
        # - **@param** id [PrimaryKey] The ID of the record
        # - **@param** attrs [Hash(Symbol, DB::Any)] The attributes to update
        #
        # **Example** Updating a record by ID
        #
        # ```
        # User.update(1, active: true)
        # ```
        def self.update!(id : Pk, attrs : Hash(Symbol, DB::Any))
          raise CQL::Error.new("No attributes to update") if attrs.empty?

          CQL::Update
            .new({{@type.id}}.schema)
            .table({{@type.id}}.table)
            .set(attrs)
            .where(id: id).commit
        end

        # Update a record by ID with given fields
        # - **@param** id [PrimaryKey] The ID of the record
        # - **@param** fields [Hash(Symbol, DB::Any)] The fields to update
        #
        # **Example** Updating a record by ID
        #
        # ```
        # User.update(1, active: true)
        # ```
        def self.update!(id : Pk, **attrs)
          raise CQL::Error.new("No attributes to update") if attrs.empty?
          CQL::Update
            .new({{@type.id}}.schema)
            .table({{@type.id}}.table)
            .set(**attrs)
            .where(id: id)
            .commit
        end

        # Update a record by ID with given record object
        # - **@param** id [PrimaryKey] The ID of the record
        # - **@param** record [T] The record to update
        #
        # **Example** Updating a record by ID
        #
        # ```
        # bob = User.new(name: "Bob", email: "bob@example.com")
        # id = bob.save
        #
        # bob.reload!
        #
        # User.update(1, bob)
        # ```
        def self.update!(record : {{@type.id}})
          # Update the record
          CQL::Update
            .new({{@type.id}}.schema)
            .table({{@type.id}}.table)
            .set(record.attributes)
            .where(id: record.id!)
            .commit

          record
        end

        # Update records matching where attributes with update attributes
        # - **@param** where_attrs [Hash(Symbol, DB::Any)] The attributes to match
        # - **@param** update_attrs [Hash(Symbol, DB::Any)] The attributes to update
        #
        # **Example** Updating records by email
        #
        # ```
        # User.update_by(email: "alice@example.com", active: true)
        # ```
        def self.update_by(
          where_attrs : Hash(Symbol, DB::Any),
          update_attrs : Hash(Symbol, DB::Any)
        )
          CQL::Update
            .new({{@type.id}}.schema)
            .table({{@type.id}}.table)
            .set(update_attrs)
            .where(where_attrs)
            .commit
        end

        # Update all records with given attributes
        # - **@param** attrs [Hash(Symbol, DB::Any)] The attributes to update
        #
        # **Example** Updating all records
        #
        # ```
        # User.update_all(active: true)
        # ```
        def self.update_all(attrs : Hash(Symbol, DB::Any))
          CQL::Update
            .new({{@type.id}}.schema)
            .table({{@type.id}}.table)
            .set(attrs)
            .commit
        end

        # Updates the given record
        # - **@param** record [T] The record to update
        # - **@return** [Bool] True if updated successfully, false otherwise
        #
        # **Example** Updating a record
        #
        # ```
        # user.update!
        # ```
        def update!
          {{@type.id}}.update!(self)
        end

        # Update the record with the given fields
        # - **@param** fields [Hash(Symbol, DB::Any)] The fields to update
        # - **@return** [Bool] True if updated successfully, false otherwise
        #
        # **Example** Updating a record
        #
        # ```
        # user.update(name: "Alice", email: "alice@example.com")
        # ```
        def update!(**attrs)
          self.attributes(**attrs)
          {{@type.id}}.update!(self)
        end

        # Update a record by ID with given attributes
        # - **@param** id [PrimaryKey] The ID of the record
        # - **@param** attrs [Hash(Symbol, DB::Any)] The attributes to update
        #
        # **Example** Updating a record by ID
        #
        # ```
        # User.update(1, active: true)
        # ```
        def update!(attrs : Hash(Symbol, DB::Any))
          self.attributes(attrs)
          {{@type.id}}.update!(self)
        end
      end
    end
  end
end
