module Cql::Relations
  module ManyToMany
    macro many_to_many(name, type, join_through)
      def <<(record : {{type.id}})
        {{join_through.camelcase.id}}.create({{T.stringify.underscore.id}}_id: @id, {{type.stringify.downcase.id}}_id: record.id)
      end

      def {{name.id}}! : Array({{type.id}})
        {{type.id}}.query
        .inner(:{{join_through.id}}) { ({{join_through.id}}.{{type.stringify.underscore.id}}_id == {{name.id}}.id)}.where{({{join_through.id}}.{{T.name.underscore.id}}_id == @id)}.all({{type.id}})
      end

      def add_{{name.id}}(record : {{type.id}}) : Bool
        join_table = {{join_through.id}}
        join_record = join_table.new({{T.stringify.underscore.id}}_id: @id, {{type.id}}_id: record.id)
        join_record.save
      end

      def remove_{{name.id}}(record : {{type.id}}) : Bool
        join_table = {{join_through.id}}
        join_record = join_table.query.where({{T.stringify.underscore.id}}_id: @id, {{type.id}}_id: record.id).first
        join_record.delete
      end
    end
  end
end
