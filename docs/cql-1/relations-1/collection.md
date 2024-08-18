---
title: Cql::Relations::Collection(Target, Pk)
---

# class Cql::Relations::Collection(Target, Pk)

`Reference` < `Object`

A collection of records for a one to many relationship This class is used to manage the relationship between two tables through a foreign key column in the target table and provide methods to manage the association between the two tables and query records in the associated table based on the foreign key value of the parent record.

* **param** : Target (Cql::Model) - The target model
* **param** : Pk (Int64) - The primary key type
* **return** : Nil

**Example**

```crystal
class User
  include Cql::Model(User, Int64)
  property id : Int64
  property name : String
  has_many :posts, Post, foreign_key: :user_id
end
```

details Table of Contents \[\[toc]]

## Constructors

### def new`(key : Symbol, id : Pk, cascade : Bool = false, query : Cql::Query = (Cql::Query.new(Target.schema)).from(Target.table))`

Initialize the many-to-many association collection class

* **param** : key (Symbol) - The key for the parent record
* **param** : id (Pk) - The id value for the parent record
* **param** : target\_key (Symbol) - The key for the associated record
* **param** : cascade (Bool) - Delete associated records
* **param** : query (Cql::Query) - Query object
* **return** : ManyCollection

**Example**

```crystal
ManyCollection.new(
  :movie_id,
  1,
  :actor_id,
  false,
  Cql::Query.new(Actor.schema).from(Actor.table)
)
```

## Instance Methods

### def <<`(record : Target)`

Create a new record and associate it with the parent record if it doesn't exist

* **param** : record (Target)
* **return** : Array(Target)

**Example**

```crystal
movie.actors << Actor.new(name: "Laurence Fishburne")
movie.actors.reload
movie.actors.all
=> [#<Actor:0x00007f8b3b1b3f00 @id=1, @name="Laurence Fishburne">]
```

### def all

Create a new record and associate it with the parent record

* **return** : Array(Target)

**Example**

```crystal
movie.actors.all
movie.actors.create(name: "Carrie-Anne Moss")
movie.actors.reload

=> [#<Actor:0x00007f8b3b1b3f00 @id=1, @name="Carrie-Anne Moss">]
```

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
* **raise** : Cql::Error

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
* **raise** : Cql::Error

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

### def empty?

Check if the association is empty or not

* **return** : Bool

**Example**

```crystal
movie.actors.empty?
=> true
```

### def exists?

Check if the association exists or not based on the attributes provided

* **param** : attributes (Hash(Symbol, String | Int64))
* **return** : Bool

**Example**

```crystal
movie.actors.exists?(name: "Keanu Reeves")
=> true
```

### def find

Find associated records based on the attributes provided for the parent record

* **param** : attributes (Hash(Symbol, String | Int64))
* **return** : Array(Target)

**Example**

```crystal
movie.actors.find(name: "Keanu Reeves")
=> [#<Actor:0x00007f8b3b1b3f00 @id=1, @name="Keanu Reeves">]
```

### def ids

Returns a list if primary keys for the associated records

* **return** : Array(Pk)

**Example**

```crystal
movie.actors.ids
=> [1, 2, 3]
```

### def ids=`(ids : Array(Pk))`

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

### def reload

Reload the association records from the database and return them

* **return** : Array(Target)

**Example**

```crystal
movie.actors.reload
=> [#<Actor:0x00007f8b3b1b3f00 @id=1, @name="Carrie-Anne Moss">]
```

### def size

Returns the number of associated records for the parent record

* **return** : Int64

**Example**

```crystal
movie.actors.size
=> 1
```

## Macros

### macro method\_missing`(call)`
