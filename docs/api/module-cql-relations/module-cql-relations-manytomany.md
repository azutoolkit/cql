# module CQL::Relations::ManyToMany

## Macros

### macro many\_to\_many`(name, type, join_through, cascade = false)`

Defines a many-to-many relationship between two models. This method will define a getter method that returns a ManyToMany::Collection. The collection can be used to add and remove records from the join table.

* **param** : name (Symbol) - The name of the association
* **param** : type (CQL::Model) - The target model
* **param** : join\_through (CQL::Model) - The join table model
* **param** : cascade (Bool) - Delete associated records

**Example**

```crystal
class Movie
  include CQL::Model(Movie, Int64)
  property id : Int64
  property title : String
  many_to_many :actors, Actor, join_through: :movies_actors
end

class Actor
  include CQL::Model(Actor, Int64)
  property id : Int64
  property name : String
end

class MoviesActors
  include CQL::Model(MoviesActors, Int64)
  property id : Int64
  property movie_id : Int64
  property actor_id : Int64
end
```
