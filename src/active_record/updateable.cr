module CQL
  module ActiveRecord
    module Updateable
      macro included
        # An update of the row whose primary key (`primary_key_column`) is *id*.
        protected def self.update_of(id : Pk) : CQL::Update
          CQL::Update.new(schema).table(table)
            .where({primary_key_column => CQL::ActiveRecord::IdChunks.bound(id)})
        end

        # An update of the rows whose primary key is any of *ids*, already bound (`IdChunks.each`
        # yields them as `DB::Any`, UUIDs as text).
        protected def self.update_of(ids : Array(DB::Any)) : CQL::Update
          key = primary_key_expression
          CQL::Update.new(schema).table(table).where { key.in(ids) }
        end

        # Update a record by ID with given attributes
        # - **@param** id [Pk] The ID of the record
        # - **@param** attrs [Hash(Symbol, DB::Any)] The attributes to update
        #
        # **Example** Updating a record by ID
        #
        # ```
        # User.update!(1, {:active => true} of Symbol => DB::Any)
        # ```
        def self.update!(id : Pk, attrs : Hash(Symbol, DB::Any))
          raise CQL::Error.new("No attributes to update") if attrs.empty?

          table = {{@type.id}}.schema.tables[{{@type.id}}.table]
          attrs.each do |key, value|
            column = table.columns[key]?
            raise CQL::Error.new("Unknown column: #{key}") unless column
            expected_type = column.strict_type
            is_nullable = column.null?
            if value.nil?
              unless is_nullable
                raise CQL::Error.new("Column #{key} cannot be null")
              end
            elsif value.class != expected_type
              raise CQL::Error.new("Invalid type for column #{key}: expected #{expected_type}, got #{value.class}")
            end
          end

          update_of(id).set(attrs).commit
        end

        # Update a record by ID with given fields
        # - **@param** id [Pk] The ID of the record
        # - **@param** attrs [NamedTuple] The fields to update
        #
        # **Example** Updating a record by ID
        #
        # ```
        # User.update!(1, active: true)
        # ```
        def self.update!(id : Pk, **attrs)
          raise CQL::Error.new("No attributes to update") if attrs.empty?

          table = {{@type.id}}.schema.tables[{{@type.id}}.table]
          attrs.each do |key, value|
            column = table.columns[key]?
            raise CQL::Error.new("Unknown column: #{key}") unless column
            expected_type = column.strict_type
            is_nullable = column.null?
            if value.nil?
              unless is_nullable
                raise CQL::Error.new("Column #{key} cannot be null")
              end
            elsif value.class != expected_type
              raise CQL::Error.new("Invalid type for column #{key}: expected #{expected_type}, got #{value.class}")
            end
          end

          update_of(id).set(**attrs).commit
        end

        # Write every column of a saved record to its row, without validations or callbacks
        # - **@param** record [{{@type.id}}] The record to update
        # - **@return** [{{@type.id}}] The record
        #
        # **Example** Updating a record
        #
        # ```
        # bob = User.find!(1)
        # bob.name = "Bob"
        # User.update!(bob)
        # ```
        def self.update!(record : {{@type.id}})
          attrs = record.attributes

          # Remove the ID from the attributes
          attrs.delete(primary_key_column)

          update_of(record.id!).set(attrs).commit

          record
        end

        # Update records matching where attributes with update attributes
        # - **@param** where_attrs [Hash(Symbol, DB::Any)] The attributes to match
        # - **@param** update_attrs [Hash(Symbol, DB::Any)] The attributes to update
        #
        # **Example** Updating records by email
        #
        # ```
        # User.update_by({:email => "alice@example.com"} of Symbol => DB::Any, {:active => true} of Symbol => DB::Any)
        # ```
        def self.update_by(
          where_attrs : Hash(Symbol, DB::Any),
          update_attrs : Hash(Symbol, DB::Any)
        )

          # Remove the ID from the attributes
          update_attrs.delete(primary_key_column)

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
        # User.update_all({:active => true} of Symbol => DB::Any)
        # ```
        def self.update_all(attrs : Hash(Symbol, DB::Any))
          CQL::Update
            .new({{@type.id}}.schema)
            .table({{@type.id}}.table)
            .set(attrs)
            .commit
        end

        # Write this record's columns to its row, without validations or callbacks
        # - **@return** [self] The record
        #
        # **Example** Updating a record
        #
        # ```
        # user.update!
        # ```
        def update!
          {{@type.id}}.update!(self)
        end

        # Assign the given fields and write the record to its row
        # - **@param** attrs [NamedTuple] The fields to update
        # - **@return** [self] The record
        #
        # **Example** Updating a record
        #
        # ```
        # user.update!(name: "Alice", email: "alice@example.com")
        # ```
        def update!(**attrs)
          self.attributes(**attrs)
          update!
        end

        # Assign the given attributes and write the record to its row
        # - **@param** attrs [Hash(Symbol, DB::Any)] The attributes to update
        # - **@return** [self] The record
        #
        # **Example** Updating a record
        #
        # ```
        # user.update!({:active => true} of Symbol => DB::Any)
        # ```
        def update!(attrs : Hash(Symbol, DB::Any))
          self.attributes(attrs)
          update!
        end
      end
    end
  end
end
