---
description: >-
  An overview of CQL's Active Record capabilities for defining models, interacting with your database, managing data integrity, and more.
---

# Active Record with CQL

This guide provides a comprehensive overview of Crystal Query Language (CQL)'s Active Record implementation. Active Record is a design pattern that connects database tables to classes (or structs in Crystal), allowing you to interact with your data through objects and methods rather than raw SQL queries.

CQL's Active Record module offers a powerful and intuitive way to manage your database records, inspired by established ORMs while leveraging Crystal's type safety and performance.

---

## Core Concepts & Guides

This central README provides a high-level introduction. For in-depth information on specific aspects of CQL Active Record, please refer to the following guides:

- **[Setup and Prerequisites](./README.md#prerequisites-and-setup)**: Initial configuration for using CQL and Active Record. (Covered below)
- **[Defining Models](./defining-models.md)**: Learn how to define your Active Record models, map them to database tables, specify primary keys, and work with attributes.
- **[CRUD Operations](./crud-operations.md)**: Detailed guide on creating, reading, updating, and deleting records using Active Record methods.
- **[Querying](./querying.md)**: Explore the powerful query interface, including direct finders, chainable queries, aggregations, and scopes.
- **[Persistence Details](./persistence-details.md)**: Understand how to check if a record is persisted and how to reload its data from the database.
- **[Validations](./validations.md)**: Ensure data integrity by defining and using model validations.
- **[Callbacks](./callbacks.md)**: Hook into the lifecycle of your models to trigger logic at specific events (e.g., before save, after create).
- **[Relations](#relations)**: Define and use associations between models:
  - [`belongs_to`](./relationships/belongsto.md)
  - [`has_one`](./relationships/hasone.md)
  - [`has_many`](./relationships/hasmany.md)
  - [`many_to_many`](./relationships/manytomany.md) (covers `has_and_belongs_to_many`)
- **[Database Migrations](./migrations.md)**: Manage your database schema changes over time.
- **[Scopes](./scopes.md)**: Define reusable query constraints for cleaner and more readable code.
- **[Pagination](./pagination.md)**: Easily paginate query results.

---

## Prerequisites and Setup

Before getting started, ensure you have the following:

- Crystal language installed (latest stable version recommended).
- A supported relational database (e.g., PostgreSQL, MySQL) set up and accessible.
- CQL added to your Crystal project.

### Adding CQL to Your Project

Include CQL in your project's `shard.yml`:

```yaml
dependencies:
  cql:
    github: azutoolkit/cql # Or the appropriate source for your CQL version
    version: "~> x.y.z" # Specify the version you are using
```

Then, run `shards install` to download and install the dependency.

### Database Connection Setup

You need to configure CQL to connect to your database. This is typically done by setting a database URL and opening a connection. You might also define a database context for your application.

```crystal
require "cql"

# Example: Define your database connection URL (replace with your actual credentials)
# For PostgreSQL:
ENV_DB_URL = ENV["DATABASE_URL"]? || "postgres://username:password@localhost:5432/myapp_development"

# Define a database context. This is often a class or module that your models will reference.
# The name `AcmeDB` is used as a placeholder in these guides.
module AcmeDB
  # Establishes and memoizes the database connection.
  def self.db
    @@db ||= DB.open(ENV_DB_URL)
  end

  # Optional: A method to close the connection if needed during shutdown or testing.
  def self.close_db
    @@db.try(&.close)
    @@db = nil
  end
end

# Ensure your models can reference this context, e.g.:
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context AcmeDB, :users
  # ...
end
```

**Note:** The exact mechanism for defining your database context (`AcmeDB` in the example) and making it accessible to your models should align with CQL's specific API and your application structure. Refer to CQL's core documentation for advanced database connection management, pooling, and context configuration.

---

## Quick Overview of Key Features

### Defining Models

Models are Crystal `structs` including `CQL::ActiveRecord::Model(PkType)` and use `db_context` to link to a table.

_See the full [Defining Models Guide](./defining-models.md) for details on attributes, primary keys, and more._

### CRUD Operations

CQL provides intuitive methods for creating, reading, updating, and deleting records (e.g., `save`, `create!`, `find?`, `find_by!`, `update!`, `delete!`).

_Explore the [CRUD Operations Guide](./crud-operations.md) for comprehensive examples._

### Querying

Fetch records using direct finders or build complex queries with a chainable interface (`.where`, `.order`, `.limit`, etc.).

_Dive into the [Querying Guide](./querying.md) for all query-building capabilities._

### Validations

Ensure data integrity with built-in or custom validation rules triggered before saving records.

_Learn more in the [Validations Guide](./validations.md)._

### Callbacks

Execute custom logic at different points in a model's lifecycle (e.g., `before_save`, `after_create`).

_Consult the [Callbacks Guide](./callbacks.md) for usage details._

### Relations

Define associations like `belongs_to`, `has_many`, `has_one`, and `many_to_many` to manage relationships between models.

- [`belongs_to`](./relationships/belongsto.md)
- [`has_one`](./relationships/hasone.md)
- [`has_many`](./relationships/hasmany.md)
- [`many_to_many`](./relationships/manytomany.md)

### Migrations

Manage database schema changes systematically using Crystal-based migration files.

_See the [Database Migrations Guide](./migrations.md) for how to write and run migrations._

### Scopes

Create reusable query shortcuts to keep your code clean and expressive.

_Read the [Scopes Guide](./scopes.md) for defining and using scopes._

---

This revised `README.md` now serves as a central hub, providing a brief overview and directing users to specialized guides for detailed information on each aspect of CQL Active Record.
