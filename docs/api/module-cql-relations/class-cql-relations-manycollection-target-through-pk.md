# class CQL::Relations::ManyCollection(Target, Through, Pk)

`CQL::Relations::Collection` < `Reference` < `Object`

A collection of records for a many to many relationship This class is used to manage the relationship between two tables through a join table (through)

A many-to-many association occurs when multiple records of one model can be associated with multiple records of another model, and vice versa. Typically, it requires a join table (or a junction table) to store the relationships between the records of the two models.

Here’s how a many-to-many association is commonly implemented in CQL using Crystal.

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

movie = Movie.create(title: "The Matrix")
actor = Actor.create(name: "Keanu Reeves")
```

## Constructors

### def new`(key : Symbol, id : Pk, target_key : Symbol, cascade : Bool = false, query : CQL::Query = (CQL::Query.new(Target.schema)).from(Target.table))`

Initialize the many-to-many association collection class

* **param** : key (Symbol) - The key for the parent record
* **param** : id (Pk) - The id value for the parent record
* **param** : target\_key (Symbol) - The key for the associated record
* **param** : cascade (Bool) - Delete associated records
* **param** : query (CQL::Query) - Query object
* **return** : ManyCollection

**Example**

```crystal
ManyCollection.new(
  :movie_id,
  1,
  :actor_id,
  false,
  CQL::Query.new(Actor.schema).from(Actor.table)
)
```

## Instance Methods

### def clear

Clears all associated records from the parent record and the database

* **return** : \[] of T

**Example**

```crystal
movie.actors.create(name: "Carrie-Anne Moss")
movie.actors.reload
movie.actors.all => 1
movie.actors.clear
movie.actors.reload
movie.actors.all => []
```

### def create`(record : Target)`

Create a new record and associate it with the parent record

* **param** : attributes (Hash(Symbol, String | Int64))
* **return** : Array(Target)
* **raise** : CQL::Error

**Example**

```crystal
movie.actors.create!(name: "Hugo Weaving")
movie.actors.reload
movie.actors.all
=> [#<Actor:0x00007f8b3b1b3f00 @id=1, @name="Hugo Weaving">]
```

### def create

Create a new record and associate it with the parent record

* **param** : attributes (Hash(Symbol, String | Int64))
* **return** : Array(Target)
* **raise** : CQL::Error

**Example**

```crystal
movie.actors.create(name: "Carrie-Anne Moss")
movie.actors.reload
movie.actors.all
=> [#<Actor:0x00007f8b3b1b3f00 @id=1, @name="Carrie-Anne Moss">]
```

### def delete`(record : Target)`

Delete the associated record from the parent record if it exists

* **param** : record (Target)
* **return** : Bool

**Example**

```crystal
movie.actors.create(name: "Carrie-Anne Moss")
movie.actors.reload
movie.actors.all => 1

movie.actors.delete(Actor.find(1))
movie.actors.reload
movie.actors.all

=> [] of Actor
```

### def delete`(id : Pk)`

Delete the associated record from the parent record if it exists

* **param** : id (Pk)
* **return** : Bool

**Example**

```crystal
movie.actors.create(name: "Carrie-Anne Moss")
movie.actors.reload
movie.actors.all => 1
movie.actors.delete(1)
movie.actors.reload
movie.actors.all => []
```

### def ids=`(ids : Array(Int64))`

Associates the parent record with the records that match the primary keys provided

* **param** : ids (Array(Pk))
* **return** : Array(Target)

**Example**

```crystal
movie.actors.ids = [1, 2, 3]
movie.actors.reload
movie.actors.all => [
#<Actor:0x00007f8b3b1b3f00 @id=1, @name="Carrie-Anne Moss">,
   #<Actor:0x00007f8b3b1b3f00 @id=2, @name="Hugo Weaving">,
  #<Actor:0x00007f8b3b1b3f00 @id=3, @name="Laurence Fishburne">]
```
