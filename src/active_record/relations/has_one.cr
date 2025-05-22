module CQL::ActiveRecord::Relations
  # Define the has_one association
  module HasOne
    macro has_one(name, kind)
      # Register the association
      register_association({{name}}, :has_one, {{kind}}, :{{@type.stringify.underscore.id}}_id)

      def {{name.id}} : {{kind.id}}?
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
        record = build_{{name.id}}(**attributes)
        record.create!
        record
      end

      def update_{{name.id}}(**attributes) : {{kind.id}}
        record = {{name.id}}.not_nil!
        record.update!(**attributes)
        record
      end

      def delete_{{name.id}} : Bool
        record = {{name.id}}
        return false if record.nil?
        id = record.id
        return false if id.nil?
        {{kind.id}}.delete!(id).rows_affected > 0
      end
    end
  end
end
