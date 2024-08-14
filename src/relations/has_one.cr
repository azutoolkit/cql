module Cql::Relations
  # Define the has_one association
  module HasOne
    macro has_one(name, foreign_key)
      @@associations[:has_one] ||= {} of Symbol => Symbol
      @@associations[:has_one][:{{name.id}}] = :{{foreign_key.stringify.underscore.id}}

      def {{name.id}} : {{foreign_key.id}}
        {{foreign_key}}.find_by({{T.stringify.underscore.id}}_id: @id)
      end

      def {{name.id}}=(record : {{foreign_key.id}})
        record.{{T.name.underscore.id}}_id = @id.not_nil!
      end

      def build_{{name.id}}(attributes : Hash(Symbol, DB::Any)) : T
        attributes[:{{foreign_key.stringify.underscore.id}}] = @id
        record = T.new(attributes)
        record
      end

      def create_{{name.id}}(attributes : Hash(Symbol, DB::Any)) : T
        attributes[:{{foreign_key.id}}] = @id
        record = build_{{name.id}}(attributes)
        record.save
        record
      end

      def update_{{name.id}}(attributes : Hash(Symbol, DB::Any)) : T
        record = {{name.id}}
        record.update(attributes)
        record
      end

      def delete_{{name.id}} : Bool
        record = {{name.id}}
        record.delete
      end
    end
  end
end
