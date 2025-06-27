---
icon: arrow-right-to-arc
---

# Introduction

**Crystal Query Language (CQL)** is a type-safe ORM for Crystal that combines compile-time safety with high performance.

## What is CQL?

CQL provides:

- **Type Safety** - Compile-time error detection
- **Performance** - Zero-cost abstractions with macro-generated code
- **Flexibility** - Active Record, Repository, and Data Mapper patterns
- **Multi-Database** - PostgreSQL, MySQL, SQLite support

```crystal
# Type-safe model definition
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context UserDB, :users

  property id : Int64?
  property name : String
  property email : String
  property active : Bool = true

  validates :email, presence: true, format: EMAIL_REGEX
  has_many :posts, Post
end

# Compile-time safe queries
active_users = User
  .where(active: true)
  .where { age >= 18 }
  .order(created_at: :desc)
  .limit(10)
  .all
```

## Key Features

### Type-Safe ORM

Crystal's static type system eliminates runtime database errors:

```crystal
user = User.where(nam: "Alice")  # Compile error: no column 'nam'
user.age.class  # => Int32 (guaranteed)
```

### Multi-Database Support

Single codebase works across databases:

```crystal
# PostgreSQL
ProductionDB = CQL::Schema.define(
  :production,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
)

# SQLite
DevelopmentDB = CQL::Schema.define(
  :development,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://./db/development.db"
)
```

### Multiple Patterns

**Active Record:**

```crystal
user = User.create!(name: "Alice")
user.posts.create!(title: "Hello World")
```

**Repository:**

```crystal
users = CQL::Repository(User, Int64).new(MyDB, :users)
user_id = users.create(name: "Alice", email: "alice@example.com")
```

## Quick Setup

Add to `shard.yml`:

```yaml
dependencies:
  cql:
    github: azutoolkit/cql
    version: "~> 1.0"
```

Basic example:

```crystal
require "cql"

UserDB = CQL::Schema.define(
  :userdb,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://./users.db"
) do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String
    column :email, String
    timestamps
  end
end

struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context UserDB, :users

  property id : Int64?
  property name : String
  property email : String
  property created_at : Time?
  property updated_at : Time?
end

UserDB.build
user = User.create!(name: "Alice", email: "alice@example.com")
```

## Next Steps

- **[Installation](installation.md)** - Setup CQL in your project
- **[Getting Started](guides/getting-started.md)** - Build your first app
- **[Active Record Guide](guides/active-record-with-cql/README.md)** - Learn the patterns

***

> Built for Crystal developers, by Crystal developers - CQL brings together the performance and safety of Crystal with the power and flexibility of modern ORM design.

Ready to build something amazing? Let's get started!
