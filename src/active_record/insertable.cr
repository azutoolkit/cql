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
        def self.find_or_create_by(**attributes) : {{@type.id}}
          find_by(**attributes) || create!(**attributes)
        end

        def self.find_or_create_by(attributes : Hash(Symbol, DB::Any)) : {{@type.id}}
          find_by(attributes) || create!(attributes)
        end

        # Create a new record with given attributes
        # - **@param** attrs [Hash(Symbol, DB::Any)] The attributes to use
        # - **@return** [{{@type.id}}] The created record instance
        #
        # **Example** Creating a new record
        #
        # ```
        # user = User.create!(name: "Alice", email: "alice@example.com")
        # ```
        def self.create!(attrs : Hash(Symbol, DB::Any)) : {{@type.id}}
          schema = {{@type.id}}.schema
          table_name = {{@type.id}}.table

          insertable_attrs = attrs.dup
          insertable_attrs.delete(:id)

          # Filter out ignored fields (fields not in the database schema)
          table_columns = schema.tables[table_name].columns.keys
          insertable_attrs = insertable_attrs.select { |key, _| table_columns.includes?(key) }

          # Fallback for non-PostgreSQL
          pk_id = CQL::Insert.new(schema)
            .into(table_name)
            .values(insertable_attrs)
            .commit
            .last_insert_id # Int64

          actual_pk = if Pk.is_a?(Int32.class)
                        pk_id.to_i32
                      else
                        pk_id.as(Pk)
                      end

          {{@type.id}}.find!(actual_pk.as(Pk))
        end

        # Create a new record with given fields
        # - **@param** fields [NamedTuple] The fields to use
        # - **@return** [{{@type.id}}] The created record instance
        #
        # **Example** Creating a new record
        #
        # ```
        # user = User.create!(name: "Alice", email: "alice@example.com")
        # ```
        def self.create!(**fields) : {{@type.id}}
          schema = {{@type.id}}.schema
          table_name = {{@type.id}}.table

          fields_hash = {} of Symbol => DB::Any
          fields.each { |key, value| fields_hash[key] = value.as(DB::Any) }
          fields_hash.delete(:id)

          # Filter out ignored fields (fields not in the database schema)
          table_columns = schema.tables[table_name].columns.keys
          fields_hash = fields_hash.select { |key, _| table_columns.includes?(key) }

          # Fallback for non-PostgreSQL
          pk_id = CQL::Insert.new(schema)
            .into(table_name)
            .values(fields_hash)
            .last_insert_id # Int64

          actual_pk = if Pk.is_a?(Int32.class)
                        pk_id.to_i32
                      else
                        pk_id.as(Pk)
                      end

          {{@type.id}}.find!(actual_pk.as(Pk))
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

          # Filter out ignored fields (fields not in the database schema)
          schema = {{@type.id}}.schema
          table = {{@type.id}}.table
          table_columns = schema.tables[table].columns.keys
          filtered_attrs = attrs.select { |key, _| table_columns.includes?(key) }

          # Create the record
          id = CQL::Insert
            .new({{@type.id}}.schema)
            .into({{@type.id}}.table)
            .values(filtered_attrs)
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
        def self.create!(**fields) : {{@type.id}}
          # Filter out ignored fields (fields not in the database schema)
          schema = {{@type.id}}.schema
          table_name = {{@type.id}}.table
          table_columns = schema.tables[table_name].columns.keys

          # Convert NamedTuple to Hash and filter
          fields_hash = {} of Symbol => DB::Any
          fields.each { |key, value| fields_hash[key] = value.as(DB::Any) }
          filtered_fields = fields_hash.select { |key, _| table_columns.includes?(key) }

          id = CQL::Insert
            .new({{@type.id}}.schema)
            .into({{@type.id}}.table)
            .values(filtered_fields)
            .last_insert_id

          id = if Pk.is_a?(Int32.class)
            id.to_i32
          else
            id.as(Pk)
          end

          {{@type.id}}.find!(id.as(Pk))
        end

        # Create a new record with given attributes
        # - **@param** attrs [Hash(Symbol, DB::Any)] The attributes to use
        # - **@return** [PrimaryKey] The ID of the new record
        # - **@raise** [ValidationError] If validation fails
        #
        # **Example** Creating a new record
        #
        def create!
          # Validate before creating
          validate!

          # Create the record using the class method
          {{@type.id}}.create!(self)
        end
      end
    end
  end
end
