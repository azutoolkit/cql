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
    #   user = User.create!(name: "Alice") # UUID generated here
    #   tx.rollback                        # UUID is "wasted" but harmless
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

        # Inserts *rows* with multi-row INSERT statements and returns the number inserted.
        # Runs no validations or callbacks. Fills missing `created_at`/`updated_at` columns and,
        # for UUID and ULID keys, missing ids. A *batch_size* may not bind more values per
        # statement than the dialect's `max_bind_params`.
        #
        # ```
        # User.insert_all([{name: "Ada", email: "ada@example.com"}, {name: "Linus", email: "linus@example.com"}])
        # ```
        def self.insert_all(rows : Array(Hash(Symbol, DB::Any)), batch_size : Int32? = nil) : Int64
          _bulk_insert(rows).call(batch_size)
        end

        def self.insert_all(rows : Array(NamedTuple), batch_size : Int32? = nil) : Int64
          insert_all(rows.map { |row| row.to_h.transform_values(&.as(DB::Any)) }, batch_size)
        end

        # Like `insert_all`, but a row whose *on_conflict* columns match an existing row updates it:
        # the *update* columns take the incoming values (by default every inserted column except
        # the conflict columns, the primary key and `created_at`; `[] of Symbol` leaves the row as it is).
        # Returns the rows affected as the database reports them (MySQL counts a changed row twice and
        # an unchanged one as zero).
        #
        # ```
        # Product.upsert_all([{sku: "a1", price: 10}], on_conflict: :sku, update: [:price])
        # ```
        def self.upsert_all(rows : Array(Hash(Symbol, DB::Any)), on_conflict : Symbol | Array(Symbol), update : Array(Symbol)? = nil, batch_size : Int32? = nil) : Int64
          target = on_conflict.is_a?(Symbol) ? [on_conflict] : on_conflict
          _bulk_insert(rows, CQL::ActiveRecord::BulkInsert::Conflict.new(target, update)).call(batch_size)
        end

        def self.upsert_all(rows : Array(NamedTuple), on_conflict : Symbol | Array(Symbol), update : Array(Symbol)? = nil, batch_size : Int32? = nil) : Int64
          upsert_all(rows.map { |row| row.to_h.transform_values(&.as(DB::Any)) }, on_conflict, update, batch_size)
        end

        private def self._bulk_insert(rows : Array(Hash(Symbol, DB::Any)), conflict : CQL::ActiveRecord::BulkInsert::Conflict? = nil) : CQL::ActiveRecord::BulkInsert
          {% if Pk == UUID %}
            generate_id = -> { UUID.random.to_s.as(DB::Any) }
          {% elsif Pk == String %}
            generate_id = -> { CQL::ULIDCompat.generate.as(DB::Any) }
          {% else %}
            generate_id = nil
          {% end %}
          CQL::ActiveRecord::BulkInsert.new({{@type.id}}.schema, {{@type.id}}.table, rows, generate_id, conflict, primary_key_column)
        end

        # Create a new record with given attributes and return it as stored, with the values the
        # database filled in. A model that reads through CQL's own `self.query` gets the row from the
        # INSERT's RETURNING clause where the dialect `supports_returning?` (PostgreSQL, CockroachDB);
        # otherwise the row is read back by id through `self.query`.
        # - **@param** attrs [Hash(Symbol, DB::Any)] The attributes to use
        # - **@return** [{{@type.id}}] The created record instance
        #
        # **Example** Creating a new record
        #
        # ```
        # user = User.create!({:name => "Alice".as(DB::Any)})
        # ```
        def self.create!(attrs : Hash(Symbol, DB::Any)) : {{@type.id}}
          # The including model's, which a subclass shares
          schema = {{@type.id}}.schema
          table = {{@type.id}}.table
          table_columns = schema.tables[table].columns
          insertable_attrs = attrs.select { |key, _| key != primary_key_column && table_columns.has_key?(key) }

          {% if Pk == UUID %}
            # Stored as a String for SQLite compatibility
            generated_id = UUID.random
            insertable_attrs[primary_key_column] = generated_id.to_s.as(DB::Any)
          {% elsif Pk == String %}
            generated_id = CQL::ULIDCompat.generate
            insertable_attrs[primary_key_column] = generated_id.as(DB::Any)
          {% end %}

          insert = CQL::Insert.new(schema).into(table).values(insertable_attrs)
          return insert.back(table_columns.keys).get!({{@type.id}}) if static_query? && schema.dialect.supports_returning?

          {% if Pk == UUID || Pk == String %}
            insert.commit
            {{@type.id}}.find!(generated_id)
          {% else %}
            # Int32/Int64 - use database auto-increment
            pk_id = insert.last_insert_id(as: Pk)

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

        # Create a new record with given fields (see `create!(attrs)`)
        # - **@param** fields [NamedTuple] The fields to use
        # - **@return** [{{@type.id}}] The created record instance
        #
        # **Example** Creating a new record
        #
        # ```
        # user = User.create!(name: "Alice", email: "alice@example.com")
        # ```
        def self.create!(**fields) : {{@type.id}}
          attrs = {} of Symbol => DB::Any
          fields.each { |key, value| attrs[key] = value.as(DB::Any) }
          create!(attrs)
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
          attrs.delete(primary_key_column)

          # Filter out ignored fields (fields not in the database schema)
          schema = {{@type.id}}.schema
          table = {{@type.id}}.table
          table_columns = schema.tables[table].columns.keys
          filtered_attrs = attrs.select { |key, _| table_columns.includes?(key) }

          {% if Pk == UUID %}
            # Generate UUID before insert, store as String for SQLite compatibility
            generated_id = UUID.random
            filtered_attrs[primary_key_column] = generated_id.to_s.as(DB::Any)

            CQL::Insert
              .new({{@type.id}}.schema)
              .into({{@type.id}}.table)
              .values(filtered_attrs)
              .commit

            record.id = generated_id
          {% elsif Pk == String %}
            # Generate ULID before insert (ULID stored as String)
            generated_id = CQL::ULIDCompat.generate
            filtered_attrs[primary_key_column] = generated_id.as(DB::Any)

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
              .last_insert_id(as: Pk)

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

        # Validate this record as `:create` and insert it, with its timestamps set as `save` sets them
        # (`set_timestamps!` comes from `Persistence`); no callbacks run.
        # - **@return** [{{@type.id}}] The record, with its new id
        # - **@raise** [ValidationError] If validation fails
        def create!
          set_timestamps!
          validate!(:create)

          # Create the record using the class method
          {{@type.id}}.create!(self)
        end
      end
    end
  end
end
