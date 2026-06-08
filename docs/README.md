# CQL (Crystal Query Language)

A high-performance, type-safe ORM for Crystal applications.

Build fast, reliable database applications with compile-time safety and exceptional performance.

## Quick Navigation

| **I want to...** | **Go to...** |
|------------------|--------------|
| Learn CQL from scratch | [Tutorials](tutorials/README.md) |
| Accomplish a specific task | [How-to Guides](how-to/README.md) |
| Look up API details | [Reference](reference/README.md) |
| Understand concepts | [Explanation](explanation/README.md) |

## Installation

Add CQL to your `shard.yml`:

```yaml
dependencies:
  cql:
    github: azutoolkit/cql
    version: ~> 0.0.435

  # Choose your database driver:
  pg:  # PostgreSQL
    github: will/crystal-pg
    version: "~> 0.26.0"
```

Then run:

```shell
shards install
```

[Full installation guide](installation.md)

## Quick Start

```crystal
require "cql"
require "pg"

# Define your database
MyDB = CQL::Schema.define(
  :my_db,
  adapter: CQL::Adapter::Postgres,
  uri: "postgres://localhost/myapp"
) do
end

# Define a model
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :users

  property id : Int64?
  property name : String
  property email : String

  def initialize(@name : String, @email : String)
  end
end

# Use it
MyDB.init
user = User.create!(name: "Alice", email: "alice@example.com")
puts "Created user #{user.id}: #{user.name}"
```

## Documentation Structure

### Tutorials

**Learning-oriented** - Step-by-step guides for beginners

- [Your First CQL App](tutorials/getting-started/your-first-cql-app.md) - Build your first application
- [Building a Blog](tutorials/building-a-blog/01-project-setup.md) - Complete multi-part tutorial

### How-to Guides

**Task-oriented** - Practical steps to accomplish specific goals

- [Models](how-to/models/define-model.md) - Define, validate, and enhance models
- [Relationships](how-to/relationships/belongs-to.md) - Set up associations
- [Querying](how-to/querying/find-records.md) - Find and filter data
- [Migrations](how-to/migrations/create-migration.md) - Manage schema changes

### Reference

**Information-oriented** - Technical descriptions and specifications

- [Quick Reference](reference/quick-reference.md) - Common patterns at a glance
- [Glossary](reference/glossary.md) - Terminology definitions
- [Error Codes](reference/error-codes.md) - Error messages explained

### Explanation

**Understanding-oriented** - Conceptual discussions

- [What is an ORM?](explanation/concepts/what-is-orm.md) - ORM fundamentals
- [Active Record Pattern](explanation/design-patterns/active-record.md) - Design pattern overview

## Key Features

- **Type Safety** - Catch errors at compile time
- **Relationship Integrity** - Validate `belongs_to` and `has_many` foreign-key/primary-key types during compilation
- **Schema Mapping Checks** - Opt-in boot validation for model getter types against schema columns
- **Multiple Databases** - PostgreSQL, MySQL, SQLite
- **Active Record** - Familiar patterns for rapid development
- **Migrations** - Version-controlled schema changes
- **Validations** - Built-in data integrity
- **Relationships** - belongs_to, has_one, has_many, many-to-many
- **Soft Deletes** - Mark records as deleted
- **Optimistic Locking** - Prevent concurrent update conflicts

## Getting Help

- [FAQ](resources/faq.md) - Frequently asked questions
- [Troubleshooting](how-to/troubleshooting/connection-errors.md) - Common issues
- [Community](resources/community.md) - Get support
- [GitHub Issues](https://github.com/azutoolkit/cql/issues) - Report bugs

## License

CQL is available under the MIT license.
