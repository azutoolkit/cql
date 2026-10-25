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

            {% table_name = table.id %}

            # Schema constants initialize lazily, so a model without `db_context`
            # finds its schema at compile time: the one `CQL::Schema.define` block,
            # in its enclosing namespaces or at the top level, that declares its table.
            {% unless schema = @type.constant(:CQL_SCHEMA_CONTEXT) %}
              {% namespaces = @type.name(generic_args: false).split("::")[0...-1] %}
              {% declaring_schemas = [] of StringLiteral %}
              {% for depth in (0..namespaces.size) %}
                {% prefix = namespaces[0...(namespaces.size - depth)].map { |namespace| "::" + namespace }.join("") %}
                {% scope = prefix.empty? ? @top_level : parse_type(prefix).resolve? %}
                {% for name in scope.constants %}
                  {% definition = scope.constant(name) %}
                  {% defines_with_block = definition.is_a?(Call) && definition.name == "define" && definition.block %}
                  {% defines_schema = defines_with_block && definition.receiver.is_a?(Path) && definition.receiver.resolve? == CQL::Schema %}
                  {% body = defines_schema ? definition.block.body : nil %}
                  {% declarations = body.is_a?(Expressions) ? body.expressions : [body] %}
                  {% table_calls = declarations.select { |declaration| declaration.is_a?(Call) && declaration.name == "table" && declaration.args.first.is_a?(SymbolLiteral) } %}
                  {% declares_table = table_calls.any? { |table_call| table_call.args.first.id == table_name } %}
                  {% declaring_schemas << prefix + "::" + name.stringify if declares_table %}
                {% end %}
              {% end %}
              {% schema = declaring_schemas.size == 1 ? declaring_schemas.first : nil %}
            {% end %}

            # Return the schema for the model: the `db_context` schema, else the
            # schema whose `define` block declares the model's table
            # - **@return** [CQL::Schema] The schema
            #
            # **Example** Fetching the schema
            #
            # ```
            # User.schema
            # ```
            def self.schema
              {% if schema %}
                @@schema || {{schema.id}}
              {% else %}
                {% model = @type.name %}
                {% message = if declaring_schemas.empty?
                               "CQL schema mapping error in #{model}: no `CQL::Schema.define` block declares table `#{table_name}`. Declare the table in a schema, or add `db_context MySchema, :#{table_name}` to #{model}."
                             else
                               "CQL schema mapping error in #{model}: schemas #{declaring_schemas.map { |name| "`#{name.id}`" }.join(", ").id} all declare table `#{table_name}`. Add `db_context <one of them>, :#{table_name}` to #{model} to pick one."
                             end %}
                @@schema || raise CQL::ActiveRecord::SchemaMappingError.new({{message}})
              {% end %}
            end

            {% if @type.constant(:CQL_SCHEMA_CONTEXT) %}
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
