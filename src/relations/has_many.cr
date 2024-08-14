module Cql::Relations
  # Define the has_many association
  module HasMany
    macro has_many(name, foreign_key)
      def {{name.id}} : Array(T)
        primary_key_value = @id
        T.query.where({{foreign_key.id}} => primary_key_value).all
      end

      def build_{{name.id.singularize}}(attributes : Hash(Symbol, _)) : T
        attributes[:{{foreign_key.id}}] = @id
        record = T.new(attributes)
        record
      end

      def create_{{name.id.singularize}}(attributes : Hash(Symbol, _)) : T
        record = build_{{name.id.singularize}}(attributes)
        record.save
        record
      end

      def update_{{name.id.singularize}}(id : Int64, attributes : Hash(Symbol, _)) : T
        record = T.query.where(id: id).first
        record.update(attributes)
        record
      end

      def delete_{{name.id.singularize}}(id : Int64) : Bool
        record = T.query.where(id: id).first
        record.delete
      end

      def <<(record : T) : Bool
        record.{{foreign_key.id}} = @id
        record.save
      end
    end
  end
end
