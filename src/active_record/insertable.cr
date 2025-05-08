module CQL
  module ActiveRecord
    module Insertable
      macro included
        # Find a record by attributes or create it if not found
        # - **param** : attributes (Hash(Symbol, String | Int64) | NamedTuple)
        # - **return** : Target
        # - **raise** : CQL::Error on creation failure
        #
        # **Example**
        #
        # ```
        # user = User.find_or_create_by(email: "user@example.com")
        # ```
        def self.find_or_create_by(**attributes)
          find_by(**attributes) || create!(**attributes)
        end

        def self.find_or_create_by(attributes : Hash(Symbol, DB::Any))
          find_by(attributes) || create!(attributes)
        end

        # Create a new record with given attributes
        # - **@param** attrs [Hash(Symbol, DB::Any)] The attributes to use
        # - **@return** [PrimaryKey] The ID of the new record
        #
        # **Example** Creating a new record
        #
        # ```
        # User.create(name: "Alice", email: "alice@example.com")
        # ```
        def self.create!(attrs : Hash(Symbol, DB::Any)) : Pk
          id = CQL::Insert
            .new({{@type.id}}.schema)
            .into({{@type.id}}.table)
            .values(attrs)
            .commit
            .last_insert_id

          if Pk.is_a?(Int32.class)
            id.to_i32
          else
            id.as(Pk)
          end
        end

        # Create a new record with given fields
        # - **@param** fields [Hash(Symbol, DB::Any)] The fields to use
        # - **@return** [PrimaryKey] The ID of the new record
        #
        # **Example** Creating a new record
        #
        # ```
        # User.create(name: "Alice", email: "alice@example.com")
        # ```
        def self.create!(**fields) : Pk
          id = CQL::Insert
            .new({{@type.id}}.schema)
            .into({{@type.id}}.table)
            .values(**fields)
            .commit
            .last_insert_id

          if Pk.is_a?(Int32.class)
            id.to_i32
          else
            id.as(Pk)
          end
        end

        # Create a new record from a model instance
        # - **@param** record [T] The record to create
        # - **@return** [PrimaryKey] The ID of the new record
        #
        # **Example** Creating a new record from a model instance
        #
        # ```
        # user = User.new(name: "Alice", email: "alice@example.com")
        # User.create(user)
        # ```
        def self.create!(record : {{@type.id}}) : {{@type.id}}
          attrs = record.attributes
          attrs.delete(:id)

          # Create the record
          id = CQL::Insert
            .new({{@type.id}}.schema)
            .into({{@type.id}}.table)
            .values(attrs)
            .commit
            .last_insert_id

          new_id = if Pk.is_a?(Int32.class)
            id.to_i32
          else
            id.as(Pk)
          end

          record.id = new_id.as(Pk)

          record.as({{@type.id}})
        end

        # Create a new record, validates the record first
        # - **@param** fields [Hash(Symbol, DB::Any)] The fields to use
        # - **@return** [PrimaryKey] The ID of the new record
        # - **@raise** [ValidationError] If validation fails
        #
        # **Example** Creating a new record
        #
        # ```
        # User.create!(name: "Alice", email: "alice@example.com")
        # ```
        def self.create!(**fields) : Pk
          id = CQL::Insert
            .new({{@type.id}}.schema)
            .into({{@type.id}}.table)
            .values(**fields)
            .commit
            .last_insert_id

          if Pk.is_a?(Int32.class)
            id.to_i32
          else
            id.as(Pk)
          end
        end

        # Create a new record with given attributes
        # - **@param** attrs [Hash(Symbol, DB::Any)] The attributes to use
        # - **@return** [PrimaryKey] The ID of the new record
        #
        # **Example** Creating a new record
        #
        def create!
          {{@type.id}}.create!(self)
        end
      end
    end
  end
end
