# Getting Started with CQL Active Record

Welcome to CQL Active Record! This guide will help you set up CQL in your Crystal project, connect to a database, define your first model, and perform basic CRUD, and first query. Use idiomatic Crystal and CQL, and provide clear, step-by-step examples.

---

## 1. Installation

Add CQL to your `shard.yml`:

```yaml
dependencies:
  cql:
    github: your-org/cql
    version: ~> 1.0
```

Then install dependencies:

```shell
shards install
```

---

## 2. Database Setup

Configure your database connection. For example, to use PostgreSQL:

```crystal
require "cql"
require "cql/pg"

# Define a database context
AcmeDB = CQL::DBContext.new(
  CQL::PG::Driver.new(
    host: "localhost",
    user: "postgres",
    password: "password",
    database: "acme_db"
  )
)
```

---

## 3. Defining a Model

Create a model that maps to a table:

```crystal
struct User
  include CQL::ActiveRecord::Model(Int32)
  db_context AcmeDB, :users

  property id : Int32?
  property name : String
  property email : String
  property active : Bool = false
  property created_at : Time?
  property updated_at : Time?
end
```

---

## 4. Running Migrations

Create your tables using migrations (optional but recommended):

```crystal
class CreateUsers < CQL::Migration
  self.version = 1_i64

  def up
    schema.create :users do
      primary_key :id, :serial
      column :name, :string
      column :email, :string
      column :active, :bool, default: false
      column :created_at, :timestamp
      column :updated_at, :timestamp
    end
  end

  def down
    schema.drop :users
  end
end
```

Run your migrations using your preferred migration runner.

---

## 5. Basic CRUD Operations

### Create

```crystal
user = User.new(name: "Alice", email: "alice@example.com")
user.save
```

### Read

```crystal
user = User.query.where(name: "Alice").first(User)
puts user.try(&.email)
```

### Update

```crystal
user = User.query.where(name: "Alice").first(User)
if user
  user.active = true
  user.save
end
```

### Delete

```crystal
user = User.query.where(name: "Alice").first(User)
user.try(&.delete)
```

---

## 6. Your First Query

```crystal
# Find all active users
active_users = User.query.where(active: true).all(User)
active_users.each { |u| puts u.name }
```

---

## Next Steps

- [Defining Models](./active-record-with-cql/defining-models.md)
- [Querying](./active-record-with-cql/querying.md)
- [Complex Queries](./complex-queries.md)
- [Validations, Callbacks, and More](./active-record-with-cql/)
