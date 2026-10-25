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

        {% verbatim do %}
          macro db_context(schema, table)
            CQL_SCHEMA_CONTEXT = {{schema}}
            CQL_TABLE_NAME = {{table}}

            self.db_context({{schema}}, {{table}})
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

        # Build a new object of type T with the given attributes
        # - **@param** hash_attrs [Hash(Symbol, DB::Any)] The attributes to use
        # - **@return** [T] The new object
        #
        # **Example** Building a new user object
        #
        # ```
        # User.from_hash({name: "Alice", email: "alice@example.com"})
        # ```
        def self.from_hash(hash_attrs : Hash(Symbol, DB::Any))
          # Create instance using build method with empty fields and then set attributes
          instance = allocate
          instance.initialize
          # Use the existing attributes method to set the hash values
          instance.attributes(hash_attrs) if instance.responds_to?(:attributes)
          instance
        end

        {% verbatim do %}
          macro finished
            {% unless table = @type.constant(:CQL_TABLE_NAME) %}
              {% singular = @type.name(generic_args: false).split("::").last.underscore %}
              {% table = if singular =~ /[^aeiou]y$/
                           singular[0..-2] + "ies"
                         elsif singular =~ /(s|x|z|ch|sh)$/
                           singular + "es"
                         else
                           singular + "s"
                         end.id.symbolize %}
            {% end %}

            # Return the table for the model: the `db_context` table, else the
            # pluralized, underscored type name (`OrderItem` => `:order_items`)
            # - **@return** [Symbol] The table
            # **Example** Fetching the table
            # ```
            # User.table
            # ```
            def self.table
              @@table || {{table}}
            end

            {% if schema = @type.constant(:CQL_SCHEMA_CONTEXT) %}
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
                  } of String => String
                )
              end
            {% end %}
          end
        {% end %}
      end
    end
  end
end
