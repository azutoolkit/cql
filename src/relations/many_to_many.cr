module Cql::Relations
  module ManyToMany
    # Defines a many-to-many relationship between two models.
    # This method will define a getter method that returns a ManyToMany::Collection.
    # The collection can be used to add and remove records from the join table.
    # - **param** : name (Symbol) - The name of the association
    # - **param** : type (Cql::Model) - The target model
    # - **param** : join_through (Cql::Model) - The join table model
    # - **param** : cascade (Bool) - Delete associated records
    #
    # **Example**
    #
    # ```
    # class Movie
    #   include Cql::Model(Movie, Int64)
    #   property id : Int64
    #   property title : String
    #   many_to_many :actors, Actor, join_through: :movies_actors
    # end
    #
    # class Actor
    #   include Cql::Model(Actor, Int64)
    #   property id : Int64
    #   property name : String
    # end
    #
    # class MoviesActors
    #   include Cql::Model(MoviesActors, Int64)
    #   property id : Int64
    #   property movie_id : Int64
    #   property actor_id : Int64
    # end
    # ```
    macro many_to_many(name, type, join_through, cascade = false)
      @[DB::Field(ignore: true)]
      getter {{name.id}} : Cql::Relations::ManyCollection({{type.id}}, {{join_through.camelcase.id}}, Pk) do
        Cql::Relations::ManyCollection({{type.id}}, {{join_through.camelcase.id}}, Pk).new(
          key: :{{T.name.underscore.id}}_id,
          id: @id.not_nil!,
          target_key: :{{type.stringify.underscore.id}}_id,
          cascade: {{cascade.id}},
          query: {{type.id}}.query
            .inner(:{{join_through.id}}) { ({{join_through.id}}.{{type.stringify.underscore.id}}_id == {{T.id}}.schema.{{name.id}}.expression.id)}
            .where{({{join_through.id}}.{{T.name.underscore.id}}_id == @id.not_nil!)}
        )
      end
    end
  end
end
