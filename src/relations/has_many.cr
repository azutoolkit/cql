module Cql::Relations
  # Define the has_many association
  module HasMany
    # Defines a collection class that interacts with the database
    # to manage the associations between two tables
    macro has_many(name, type, foreign_key)
      getter {{name.id}} = Relation::Collection({{type.id}}).new(
        T.schema, :{{name.id}}, fk_key: :{{foreign_key.id}}, fk_value: @id
      )
    end
  end
end
