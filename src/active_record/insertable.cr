module CQL
  module ActiveRecord
    # Insertable module provides create! methods for ActiveRecord models.
    #
    # ## UUID/ULID Generation in Transactions
    #
    # **Important Note:** UUIDs and ULIDs are generated client-side BEFORE the INSERT
    # statement is executed. This design ensures cross-database compatibility (SQLite,
    # PostgreSQL, MySQL) by storing these IDs as strings.
    #
    # **Transaction Behavior:**
    # - If a transaction rolls back after UUID/ULID generation, the generated ID is
    #   not reused. This is expected behavior and does not cause data integrity issues.
    # - The UUID/ULID address space is large enough (128 bits for UUID, 128 bits for
    #   ULID) that "wasted" IDs are statistically insignificant.
    # - For Int32/Int64 primary keys, the database handles ID generation via
    #   auto-increment, so rollbacks do not waste IDs at the application level.
    #
    # **Example with transactions:**
    # ```
    # User.transaction do |tx|
    #   user = User.create!(name: "Alice")  # UUID generated here
    #   tx.rollback                          # UUID is "wasted" but harmless
    # end
    # ```
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

          {% if Pk == UUID %}
            # Generate UUID before insert, store as String for SQLite compatibility
            generated_id = UUID.random
            insertable_attrs[:id] = generated_id.to_s.as(DB::Any)

            CQL::Insert.new(schema)
              .into(table_name)
              .values(insertable_attrs)
              .commit

            {{@type.id}}.find!(generated_id)
          {% elsif Pk == String %}
            # Generate ULID before insert (ULID stored as String)
            generated_id = CQL::ULIDCompat.generate
            insertable_attrs[:id] = generated_id.as(DB::Any)

            CQL::Insert.new(schema)
              .into(table_name)
              .values(insertable_attrs)
              .commit

            {{@type.id}}.find!(generated_id)
          {% else %}
            # Int32/Int64 - use database auto-increment
            pk_id = CQL::Insert.new(schema)
              .into(table_name)
              .values(insertable_attrs)
              .commit
              .last_insert_id # Int64

            {% if Pk == Int32 %}
              if pk_id > Int32::MAX || pk_id < Int32::MIN
                raise CQL::Error.new("Primary key overflow: #{pk_id} exceeds Int32 range")
              end
              {{@type.id}}.find!(pk_id.to_i32)
            {% else %}
              {{@type.id}}.find!(pk_id.as(Pk))
            {% end %}
          {% end %}
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

          {% if Pk == UUID %}
            # Generate UUID before insert, store as String for SQLite compatibility
            generated_id = UUID.random
            fields_hash[:id] = generated_id.to_s.as(DB::Any)

            CQL::Insert.new(schema)
              .into(table_name)
              .values(fields_hash)
              .commit

            {{@type.id}}.find!(generated_id)
          {% elsif Pk == String %}
            # Generate ULID before insert (ULID stored as String)
            generated_id = CQL::ULIDCompat.generate
            fields_hash[:id] = generated_id.as(DB::Any)

            CQL::Insert.new(schema)
              .into(table_name)
              .values(fields_hash)
              .commit

            {{@type.id}}.find!(generated_id)
          {% else %}
            # Int32/Int64 - use database auto-increment
            pk_id = CQL::Insert.new(schema)
              .into(table_name)
              .values(fields_hash)
              .commit
              .last_insert_id # Int64

            {% if Pk == Int32 %}
              if pk_id > Int32::MAX || pk_id < Int32::MIN
                raise CQL::Error.new("Primary key overflow: #{pk_id} exceeds Int32 range")
              end
              {{@type.id}}.find!(pk_id.to_i32)
            {% else %}
              {{@type.id}}.find!(pk_id.as(Pk))
            {% end %}
          {% end %}
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

          {% if Pk == UUID %}
            # Generate UUID before insert, store as String for SQLite compatibility
            generated_id = UUID.random
            filtered_attrs[:id] = generated_id.to_s.as(DB::Any)

            CQL::Insert
              .new({{@type.id}}.schema)
              .into({{@type.id}}.table)
              .values(filtered_attrs)
              .commit

            record.id = generated_id
          {% elsif Pk == String %}
            # Generate ULID before insert (ULID stored as String)
            generated_id = CQL::ULIDCompat.generate
            filtered_attrs[:id] = generated_id.as(DB::Any)

            CQL::Insert
              .new({{@type.id}}.schema)
              .into({{@type.id}}.table)
              .values(filtered_attrs)
              .commit

            record.id = generated_id
          {% else %}
            # Int32/Int64 - use database auto-increment
            id = CQL::Insert
              .new({{@type.id}}.schema)
              .into({{@type.id}}.table)
              .values(filtered_attrs)
              .last_insert_id

            {% if Pk == Int32 %}
              if id > Int32::MAX || id < Int32::MIN
                raise CQL::Error.new("Primary key overflow: #{id} exceeds Int32 range")
              end
              record.id = id.to_i32
            {% else %}
              record.id = id.as(Pk)
            {% end %}
          {% end %}

          record.as({{@type.id}})
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
