module Cql::Relations
  # Define the has_one association
  module HasOne
    macro has_one(name, type)
      def {{name.id}} : {{type.id}}
        {{type.id}}.find_by({{T.stringify.underscore.id}}_id: @id)
      end

      def {{name.id}}=(record : {{type.id}})
        record.{{T.name.underscore.id}}_id = @id.not_nil!
      end

      def build_{{name.id}}(**attributes) : {{type.id}}
        attr = attributes.merge({{T.stringify.underscore.id}}_id: @id.not_nil!)
        record = {{type.id}}.new(**attr)
        record
      end

      def create_{{name.id}}(**attributes) : {{type.id}}
        record = build_{{type.stringify.underscore.id}}(**attributes)
        record.save
        {{name.id}}
      end

      def update_{{name.id}}(**attributes) : {{type.id}}
        record = {{name.id}}
        record.update(**attributes)
        record
      end

      def delete_{{name.id}} : Bool
        {{type.id}}.delete({{name.id}}.id).rows_affected > 0
      end
    end
  end
end
