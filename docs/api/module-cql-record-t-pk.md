# module CQL::Record(Pk)

Write documentation for Record module

**Example** Using the Record module

```crystal
AcmeDB = CQL::Schema.define(:acme_db, adapter: CQL::Adapter::Postgres,
  uri: "postgresql://example:example@localhost:5432/example") do
  table :posts do
    primary :id, Int64, auto_increment: true
    text :title
    text :body
    timestamp :published_at
  end

  table :comments do
    primary
    bigint :post_id
    text :body
  end
end

struct Post < CQL::Record(Int64)

  db_context AcmeDB, :posts

  getter id : Int64?
  getter title : String
  getter body : String
  getter published_at : Time

  def initialize(@title : String, @body : String, @published_at : Time = Time.utc)
  end
end

struct Comment < CQL::Record(Int64)
  db_context AcmeDB, :comments

  getter id : Int64?
  getter post_id : Int64
  getter body : String

  def initialize(@post_id : Int64, @body : String)
  end
end
```

## Instance Methods

### def attributes`(attrs : Hash(Symbol, DB::Any))`

Set the record's attributes from a hash

* **@param** attrs \[Hash(Symbol, DB::Any)] The attributes to set
* **@return** \[Nil]

**Example** Setting the record's attributes

```crystal
user.attributes = {name: "Alice", email: "[email protected]"}
```

### def attributes

Define instance-level methods for querying and manipulating data Fetch the record's ID or raise an error if it's nil

* **@return** \[PrimaryKey] The ID

**Example** Fetching the record's ID

```crystal
user.attributes
-> { id: 1, name: "Alice", email: " [email protected]" }
```

### def delete

Delete the record from the database

* **@return** \[Nil]

**Example** Deleting the record

```crystal
user.delete
```

### def id

Identity method for the record ID

* **@return** \[PrimaryKey] The ID

**Example** Fetching the record's ID

```crystal
user.id
```

### def id=`(id : Pk)`

Set the record's ID

* **@param** id \[PrimaryKey] The ID

**Example** Setting the record's ID

```crystal
user.id = 1
```

### def persisted?

Check if the record has been persisted to the database

* **@return** \[Bool] True if the record has an ID, false otherwise

**Example** Checking if the record is persisted

```crystal
user.persisted?
```

### def reload!

Define instance-level methods for querying and manipulating data Fetch the record's ID or raise an error if it's nil

* **@return** \[PrimaryKey] The ID

**Example** Fetching the record's ID

```crystal
user.reload!
```

### def save

Define instance-level methods for saving and deleting records Save the record to the database or update it if it already exists

* **@return** \[Nil]

**Example** Saving the record

```crystal
user.save
```

### def update`(fields : Hash(Symbol, DB::Any))`

Delete the record from the database if it exists

* **@return** \[Nil]

**Example** Deleting the record

```crystal
user.delete
```

### def update

Update the record with the given record object

**Example** Updating the record

```crystal
bob = User.new(name: "Bob", email: " [email protected]")
id = bob.save

bob.reload!
bon.name = "Juan"

bob.update
```

### def update

Update the record with the given fields

* **@param** fields \[Hash(Symbol, DB::Any)] The fields to update
* **@return** \[Nil]

**Example** Updating the record

```crystal
user.update(name: "Alice", email: " [email protected]")
```
