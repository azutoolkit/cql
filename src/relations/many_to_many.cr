module Cql::Relations
  module ManyToMany
    macro many_to_many(name, type, join_through)
      def <<(record : {{type.id}})
        {{join_through.camelcase.id}}.create({{T.stringify.underscore.id}}_id: @id, {{type.stringify.downcase.id}}_id: record.id)
      end

      def {{name.id}} : Array({{type.id}})
        {{type.id}}.query
          .inner(:{{join_through.id}}) {
            ({{join_through.id}}.{{type.stringify.underscore.id}}_id == {{T.id}}.schema.{{name.id}}.expression.id)}
          .where{({{join_through.id}}.{{T.name.underscore.id}}_id == @id)}
          .all({{type.id}})
      end

      def create_{{name.id}}(**attributes) : {{type.id}}
        record_id = {{type.id}}.create(**attributes)

        {{join_through.camelcase.id}}.new(
          {{T.stringify.underscore.id}}_id: @id.not_nil!,
          {{type.stringify.underscore.id}}_id: record_id
        ).save

        {{type.id}}.find!(record_id)
      end

      def delete(record : {{type.id}}) : Bool
        {{type.id}}.delete(record.id).rows_affected > 0
      end
    end
  end
end
