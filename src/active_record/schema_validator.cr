module CQL
  module ActiveRecord
    class SchemaMappingError < CQL::Error; end

    module SchemaValidator
      extend self

      def validate_model!(
        model_name : String,
        schema : CQL::Schema,
        table_name : Symbol,
        getter_types : Hash(String, String),
        primary_key : Symbol = :id,
      ) : Nil
        table = schema.tables[table_name]?
        unless table
          raise SchemaMappingError.new(
            "CQL schema mapping error in #{model_name}: table `#{table_name}` is not defined in schema `#{schema.name}`."
          )
        end

        validate_primary_key!(model_name, table_name, table, primary_key)

        table.columns.each do |column_name, column|
          # A plain `id` column on a table keyed elsewhere is not what the model's `id` reads
          next if column_name == :id && primary_key != :id
          getter_name = column_name == primary_key ? "id" : column_name.to_s
          getter_type = getter_types[getter_name]?

          next unless getter_type

          expected_type = normalize_type(column.strict_type.to_s)
          actual_type = normalize_type(getter_type)

          unless compatible_type?(expected_type, actual_type)
            raise SchemaMappingError.new(
              "CQL schema mapping error in #{model_name}: schema column `#{table_name}.#{column_name}` type #{expected_type} does not match model getter `#{getter_name}` type #{actual_type}. Update the schema column or the model property type."
            )
          end

          # Nilability is intentionally not enforced here. Active Record models
          # commonly allow nil while a record is transient and before database
          # defaults, primary keys, or foreign keys are assigned.
        end
      end

      private def validate_primary_key!(model_name : String, table_name : Symbol, table : CQL::Table, primary_key : Symbol) : Nil
        declared = table.primary_key.try(&.name)
        return if declared.nil? || declared == primary_key

        raise SchemaMappingError.new(
          "CQL schema mapping error in #{model_name}: table `#{table_name}` declares primary key `#{declared}`, but the model maps `id` to `#{primary_key}`. Declare `db_context ..., primary_key: :#{declared}` on the model."
        )
      end

      private def normalize_type(type_name : String) : String
        type_name
          .split("|")
          .map(&.strip)
          .reject { |part| part == "Nil" || part == "::Nil" }
          .map { |part| part.starts_with?("::") ? part[2..] : part }
          .map { |part| TYPE_ALIASES.fetch(part, part) }
          .join(" | ")
      end

      # Getter types are written as the model spells them; schema columns use the resolved type.
      private TYPE_ALIASES = {"Bytes" => "Slice(UInt8)"}

      private def compatible_type?(expected_type : String, actual_type : String) : Bool
        return true if expected_type == actual_type

        # UUIDs are stored as strings by the existing UUID model adapter path,
        # while the public model getter exposes UUID for type safety.
        expected_type == "String" && actual_type == "UUID"
      end
    end
  end
end
