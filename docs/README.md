---
title: Cql
---

# Cql

CQL is a powerful library designed to simplify and enhance the management and execution of SQL queries in the Crystal programming language. It provides utilities for building, validating, and executing SQL statements, ensuring better performance and code maintainability.

## Features

* **Query Builder**: Programmatically create complex SQL queries.
* **Insert, Update, Delete Operations**: Perform CRUD operations with ease.
* **Repository Pattern**: Manage your data more effectively using `Cql::Repository(T)`.
* **Active Record Pattern**: Work with your data models using `Cql::Record(T)`.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  cql:
    github: azutoolkit/cql
```

Then, run the following command to install the dependencies:

```bash
shards install
```

## Getting Started

### 1. Define a Schema

Define the schema for your database tables:

```crystal
AcmeDB2 = Cql::Schema.build(
  :acme_db,
  adapter: Cql::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]) do
  table :movies do
    primary :id, Int64, auto_increment: true
    text :title
  end

  table :screenplays do
    primary :id, Int64, auto_increment: true
    bigint :movie_id
    text :content
  end

  table :actors do
    primary :id, Int64, auto_increment: true
    text :name
  end

  table :directors do
    primary :id, Int64, auto_increment: true
    bigint :movie_id
    text :name
  end

  table :movies_actors do
    primary :id, Int64, auto_increment: true
    bigint :movie_id
    bigint :actor_id
  end
end
```

### 2. Executing Queries

With the schema in place, you can start executing queries:

```crystal
q = AcmeDB.query
user = q.from(:users).where(id: 1).first!(as: User)
puts user.name
```

### 3. Inserting Data

Insert new records into the database:

```crystal
q = Cql::Query.new(schema)
q.insert
  .into(:users)
  .values(name: "Jane Doe", email: "jane@example.com")
  .last_insert_id
```

### 4. Updating Data

Update existing records:

```crystal
u = AcmeDB.update
u.table(:users)
  .set(name: "Jane Smith")
  .where(id: 1)
  .commit
```

### 5. Deleting Data

Delete records from the database:

```crystal
d = AcmeDB.delete
d.from(:users).where(id: 1).commit
```

### 6. Using the Repository Pattern

Utilize the repository pattern for organized data management:

```crystal
user_repository = Cql::Repository(User, Int64).new(schema, :users)

# Create a new user
user_repository.create(name: "Jane Doe", email: "jane@example.com")

# Fetch all users
users = user_repository.all
users.each { |user| puts user.name }

# Find a user by ID
user = user_repository.find!(1)
puts user.name

# Update a user by ID
user_repository.update(1, name: "Jane Smith")
```

### 7. Active Record Pattern

Work with your data using the Active Record pattern:

```crystal
A
struct Actor
  include Cql::Record(Actor, Int64)
  include Cql::Relations

  define AcmeDB2, :actors

  getter id : Int64?
  getter name : String

  def initialize(@name : String)
  end
end

struct Movie
  include Cql::Record(Movie, Int64)
  include Cql::Relations

  define AcmeDB2, :movies

  has_one :screenplay, Screenplay
  many_to_many :actors, Actor, join_through: :movies_actors
  has_many :directors, Director, foreign_key: :movie_id

  getter id : Int64?
  getter title : String

  def initialize(@title : String)
  end
end

struct Director
  include Cql::Record(Director, Int64)
  include Cql::Relations

  define AcmeDB2, :directors

  getter id : Int64?
  getter name : String
  belongs_to :movie, foreign_key: :movie_id

  def initialize(@name : String)
  end
end

struct Screenplay
  include Cql::Record(Screenplay, Int64)
  include Cql::Relations

  define AcmeDB2, :screenplays

  belongs_to :movie, foreign_key: :movie_id

  getter id : Int64?
  getter content : String

  def initialize(@movie_id : Int64, @content : String)
  end
end

struct MoviesActors
  include Cql::Record(MoviesActors, Int64)

  define AcmeDB2, :movies_actors

  getter id : Int64?
  getter movie_id : Int64
  getter actor_id : Int64

  # has_many :actors, Actor, :actor_id

  def initialize(@movie_id : Int64, @actor_id : Int64)
  end
end
```
