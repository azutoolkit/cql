module CQL
  module ActiveRecord
    # Generates, for every model, the pieces of the typed query DSL
    # (`where { age >= 18 }`, `joins(:profile) { ... }`):
    #
    # - `Model::Columns`: one typed accessor per column getter, and one per
    #   association that returns the target model's `Columns`;
    # - `Model.cql_columns` and `Model.cql_association(name)`;
    # - `Model::Row`: a lightweight record for partial selects, where every
    #   column is nilable.
    #
    # Columns are discovered from typed getters, so an accessor exists exactly
    # when the model declares a scalar getter of that name.
    module TypedColumns
      SCALAR_TYPES     = %w[String Int8 Int16 Int32 Int64 UInt8 UInt16 UInt32 UInt64 Float32 Float64 Bool Time UUID JSON::Any]
      INTERNAL_GETTERS = %w[destroyed run_destroy_callbacks run_after_destroy_callbacks]

      macro included
        {% verbatim do %}
          macro finished
            {% owner = @type %}
            {% pk = @type.constant(:CQL_PRIMARY_KEY_TYPE).stringify %}
            {% owner_key = @type.constant(:CQL_PRIMARY_KEY_COLUMN) || :id %}

            {% associations = [] of Nil %}
            {% for const in CQL::ActiveRecord::AssociationRegistry.constants %}
              {% meta = CQL::ActiveRecord::AssociationRegistry.constant(const).resolve %}
              {% associations << meta if meta.constant(:OWNER).resolve == owner %}
            {% end %}
            {% association_counts = associations.map { |meta| meta.constant(:ASSOCIATION).id.stringify + "_count" } %}

            {% columns = [] of Nil %}
            {% for method in owner.methods %}
              {% if method.args.empty? && method.return_type && method.body.stringify == "@" + method.name.stringify && !method.name.ends_with?("=") && !method.name.ends_with?("?") && !method.name.ends_with?("!") %}
                {% parts = method.return_type.stringify.gsub(/[()]/, "").split("|").map(&.strip).reject { |part| part == "::Nil" || part == "Nil" } %}
                {% if parts.size == 1 %}
                  {% type = parts[0] == "Pk" ? pk : parts[0] %}
                  {% if CQL::ActiveRecord::TypedColumns::SCALAR_TYPES.includes?(type) && !CQL::ActiveRecord::TypedColumns::INTERNAL_GETTERS.includes?(method.name.stringify) && !association_counts.includes?(method.name.stringify) %}
                    {% columns << {method.name.stringify, type} %}
                  {% end %}
                {% end %}
              {% end %}
            {% end %}

            {% if pk == "UUID" && !columns.any? { |column| column[0] == "id" } %}
              {% columns << {"id", "UUID"} %}
            {% end %}

            struct Columns
              def initialize(@table_alias : String)
              end

              {% for column in columns %}
                {% type = column[1] %}
                {% klass = type == "String" ? "CQL::DSL::TextCol" : (type == "JSON::Any" ? "CQL::DSL::JsonCol" : "CQL::DSL::Col(" + type + ")") %}
                def {{ column[0].id }} : {{ klass.id }}
                  {{ klass.id }}.new(::Expression::Column.new({{ owner }}.cql_column(:{{ column[0].id }}), alias_name: @table_alias))
                end
              {% end %}

              {% for meta in associations %}
                {% target = meta.constant(:TARGET) %}
                def {{ meta.constant(:ASSOCIATION).id }} : {{ target }}::Columns
                  {{ target }}.cql_columns
                end
              {% end %}
            end

            # A row of a partial select: only the selected columns are filled in.
            struct Row
              include DB::Serializable
              include DB::Serializable::NonStrict

              {% for column in columns %}
                {% name = column[0] %}
                {% type = column[1] %}
                {% stored = (type == "UUID" || type == "JSON::Any") ? "String" : type %}
                @[DB::Field(key: {{ name == "id" ? owner_key.id.stringify : name }})]
                @{{ name.id }} : {{ stored.id }}? = nil

                {% if type == "UUID" %}
                  def {{ name.id }} : UUID?
                    @{{ name.id }}.try { |text| UUID.new(text) }
                  end
                {% elsif type == "JSON::Any" %}
                  def {{ name.id }} : JSON::Any?
                    @{{ name.id }}.try { |text| JSON.parse(text) }
                  end
                {% else %}
                  def {{ name.id }} : {{ type.id }}?
                    @{{ name.id }}
                  end
                {% end %}
              {% end %}
            end

            # The typed column proxy for this model's table.
            def self.cql_columns : Columns
              Columns.new(table.to_s)
            end

            # The schema column, or a clear error when the getter has no column behind it.
            # The `id` getter maps to the declared primary key column.
            def self.cql_column(name : Symbol) : CQL::BaseColumn
              table_columns[name == :id ? {{ owner_key }} : name]? || raise ArgumentError.new("#{self} has no column #{name.inspect} in table #{table}. Columns: #{table_columns.keys.join(", ")}")
            end

            # The names of this model's columns, for error messages.
            def self.cql_column_names : Array(Symbol)
              [{% for column in columns %}:{{ column[0].id }}, {% end %}] of Symbol
            end

            # The joined table and ON condition for an association, used by `joins`.
            def self.cql_association(name : Symbol) : {Symbol, Proc(::Expression::FilterBuilder, ::Expression::ConditionBuilder)}
              case name
              {% for meta in associations %}
                {% target = meta.constant(:TARGET) %}
                {% fk = meta.constant(:FOREIGN_KEY) %}
                {% target_key = meta.constant(:TARGET).resolve.constant(:CQL_PRIMARY_KEY_COLUMN) || :id %}
                {% target_column, owner_column = meta.constant(:KIND) == :belongs_to ? {target_key, fk} : {fk, owner_key} %}
                when :{{ meta.constant(:ASSOCIATION).id }}
                  { {{ target }}.table, ->(j : ::Expression::FilterBuilder) { j.table({{ target }}.table).{{ target_column.id }}.eq(j.table({{ owner }}.table).{{ owner_column.id }}) } }
              {% end %}
              else
                raise ArgumentError.new("#{self} has no association #{name.inspect}. Associations: #{([{% for meta in associations %}{{ meta.constant(:ASSOCIATION).id.stringify }}, {% end %}] of String).join(", ")}")
              end
            end
          end
        {% end %}
      end
    end
  end
end
