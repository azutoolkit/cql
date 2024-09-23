module CQL::Relations
  # Define the has_one association
  module HasOne
    macro has_one(name, kind)
      def {{name.id}} : {{kind.id}}
        {{kind.id}}.find_by({{@type.stringify.underscore.id}}_id: @id)
      end

      def {{name.id}}=(record : {{kind.id}})
        record.{{@type.name.underscore.id}}_id = @id.not_nil!
      end

      def build_{{name.id}}(**attributes) : {{kind.id}}
        attr = attributes.merge({{@type.stringify.underscore.id}}_id: @id.not_nil!)
        record = {{kind.id}}.new(**attr)
        record
      end

      def create_{{name.id}}(**attributes) : {{kind.id}}
        record = build_{{kind.stringify.underscore.id}}(**attributes)
        record.save
        {{name.id}}
      end

      def update_{{name.id}}(**attributes) : {{kind.id}}
        record = {{name.id}}
        record.update(**attributes)
        record
      end

      def delete_{{name.id}} : Bool
        {{kind.id}}.delete({{name.id}}.id).rows_affected > 0
      end
    end
  end
end
