module CQL
  module ActiveRecord
    module Definition
      macro included
        @@schema : CQL::Schema? = nil
        @@table : Symbol? = nil

        # Define the schema and table for the model
        # - **@param** schema [CQL::Schema] The schema to use
        # - **@param** table [Symbol] The table to use
        # - **@return** [Nil]
        #
        # **Example** Defining the schema and table
        #
        # ```
        # struct User
        #   include CQL::ActiveRecord::Model
        #   db_context AcmeDB, :users
        # end
        # ```
        def self.db_context(schema : CQL::Schema, table : Symbol)
          @@schema = schema
          @@table = table
        end

        def self.primary_key_column : Symbol
          :id
        end

        # The primary key column as an expression, for conditions a where-hash cannot express (`IN`).
        protected def self.primary_key_expression : ::Expression::Column
          ::Expression::Column.new(cql_column(primary_key_column))
        end

        {% verbatim do %}
          macro db_context(schema, table, primary_key = :id)
            {% raise "db_context for #{@type}: primary_key must be a Symbol, got #{primary_key}" unless primary_key.is_a?(SymbolLiteral) %}
            CQL_SCHEMA_CONTEXT = {{schema}}
            CQL_TABLE_NAME = {{table}}
            CQL_PRIMARY_KEY_COLUMN = {{primary_key}}

            self.db_context({{schema}}, {{table}})

            {% if primary_key != :id %}
              def self.primary_key_column : Symbol
                {{primary_key}}
              end

              # Re-declares Identifyable's id storage so DB::Serializable maps it to the declared column
              {% if CQL_PRIMARY_KEY_TYPE.resolve == UUID %}
                @[DB::Field(key: {{primary_key.id.stringify}})]
                @_id_storage : String? = nil
              {% else %}
                @[DB::Field(key: {{primary_key.id.stringify}})]
                @id : {{CQL_PRIMARY_KEY_TYPE}}? = nil
              {% end %}
            {% end %}
          end
        {% end %}

        # Return the schema for the model
        # - **@return** [CQL::Schema] The schema
        #
        # **Example** Fetching the schema
        #
        # ```
        # User.schema
        # ```
        def self.schema
          @@schema.not_nil!
        end

        # Return the table for the model
        # - **@return** [Symbol] The table
        # **Example** Fetching the table
        # ```
        # User.table
        # ```
        def self.table
          @@table.not_nil!
        end

        def self.table_columns
          schema.tables[table].columns
        end

        def self.table_column(column : Symbol)
          table_columns[column].expression
        end

        # Return the adapter for the schema
        # - **@return** [CQL::Adapter] The adapter
        # **Example** Fetching the adapter
        # ```
        # User.adapter
        # ```
        def self.adapter
          schema.adapter
        end

        # Build a new object of type T with the given attributes
        # - **@param** attrs [Hash(Symbol, DB::Any)] The attributes to use
        # - **@return** [T] The new object
        #
        # **Example** Building a new user object
        #
        # ```
        # User.build(name: "Alice", email: "alice@example.com")
        # ```
        #
        def self.build(**fields)
          new(**fields)
        end

        # Builds a new, unsaved object from a hash of column values. The primary key is ignored, so a
        # hash from request params cannot make `save` update an existing row; pass
        # `with_primary_key: true` only for trusted data (a record that is then saved updates that row).
        # - **@param** hash_attrs [Hash(Symbol, DB::Any)] The attributes to use
        # - **@return** [T] The new object
        #
        # **Example** Building a new user object
        #
        # ```
        # User.from_hash({:name => "Alice", :email => "alice@example.com"} of Symbol => DB::Any)
        # ```
        def self.from_hash(hash_attrs : Hash(Symbol, DB::Any), *, with_primary_key : Bool = false)
          instance = allocate
          instance.initialize
          if with_primary_key
            instance._assign_attributes_with_primary_key(hash_attrs)
          else
            instance.attributes(hash_attrs)
          end
          instance
        end

        {% verbatim do %}
          macro finished
            {% if schema = @type.constant(:CQL_SCHEMA_CONTEXT) %}
              {% table = @type.constant(:CQL_TABLE_NAME) %}
              {% getter_types = {} of String => String %}
              {% for method in @type.methods %}
                {% if method.args.empty? && !method.name.ends_with?("=") && method.return_type %}
                  {% if method.name == "id" && @type.constant(:CQL_PRIMARY_KEY_TYPE) %}
                    {% return_type = @type.constant(:CQL_PRIMARY_KEY_TYPE).stringify + " | ::Nil" %}
                  {% else %}
                    {% return_type = method.return_type.stringify %}
                  {% end %}
                  {% getter_types[method.name] = return_type %}
                {% end %}
              {% end %}

              if ENV["CQL_VALIDATE_SCHEMA_MAPPINGS"]? == "1"
                CQL::ActiveRecord::SchemaValidator.validate_model!(
                  {{@type.name.stringify}},
                  {{schema}},
                  {{table}},
                  {
                    {% for name, type in getter_types %}
                      {{name.stringify}} => {{type}},
                    {% end %}
                  } of String => String,
                  primary_key: {{@type.constant(:CQL_PRIMARY_KEY_COLUMN) || :id}}
                )
              end
            {% end %}
          end
        {% end %}
      end
    end
  end
end
