---
description: >-
  An overview of CQL's Active Record capabilities for defining models,
  interacting with your database, managing data integrity, and more.
---

# Active Record Overview

This guide provides a comprehensive overview of Crystal Query Language (CQL)'s Active Record implementation. Active Record is a design pattern that connects database tables to classes (or structs in Crystal), allowing you to interact with your data through objects and methods rather than raw SQL queries.

CQL's Active Record module offers a powerful and intuitive way to manage your database records, inspired by established ORMs while leveraging Crystal's type safety and performance.

***

## Core Concepts & Guides

This central README provides a high-level introduction. For in-depth information on specific aspects of CQL Active Record, please refer to the following guides:

* [**Setup and Prerequisites**](active-record-with-cql.md#prerequisites-and-setup): Initial configuration for using CQL and Active Record. (Covered below)
* [**Defining Models**](broken-reference): Learn how to define your Active Record models, map them to database tables, specify primary keys, and work with attributes.
* [**CRUD Operations**](crud-operations.md): Detailed guide on creating, reading, updating, and deleting records using Active Record methods.
* [**Querying**](../guides/active-record-with-cql/querying.md): Explore the powerful query interface, including direct finders, chainable queries, aggregations, and scopes.
* [**Transactions**](broken-reference): Ensure data integrity by using database transactions for multi-step operations.
* [**Persistence Details**](persistence-details.md): Understand how to check if a record is persisted and how to reload its data from the database.
* [**Validations**](validations.md): Ensure data integrity by defining and using model validations.
* [**Callbacks**](callbacks.md): Hook into the lifecycle of your models to trigger logic at specific events (e.g., before save, after create).
* [**Relations**](relations/): Define and use associations between models:
  * [`belongs_to`](relations/belongsto.md)
  * [`has_one`](relations/hasone.md)
  * [`has_many`](relations/hasmany.md)
  * [`many_to_many`](relations/manytomany.md) (covers `has_and_belongs_to_many`)
* [**Database Migrations**](broken-reference): Manage your database schema changes over time.
* [**Scopes**](scopes.md): Define reusable query constraints for cleaner and more readable code.

***

## Prerequisites and Setup

Before getting started, ensure you have the following:

* Crystal language installed (latest stable version recommended).
* A supported relational database (e.g., PostgreSQL, MySQL) set up and accessible.
* CQL added to your Crystal project.

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

***

## Quick Overview of Key Features

### Defining Models

Models are Crystal `structs` including `CQL::ActiveRecord::Model(PkType)` and use `db_context` to link to a table.

_See the full_ [_Defining Models Guide_](broken-reference) _for details on attributes, primary keys, and more._

### CRUD Operations

CQL provides intuitive methods for creating, reading, updating, and deleting records (e.g., `save`, `create!`, `find?`, `find_by!`, `update!`, `delete!`).

_Explore the_ [_CRUD Operations Guide_](crud-operations.md) _for comprehensive examples._

### Querying

Fetch records using direct finders or build complex queries with a chainable interface (`.where`, `.order`, `.limit`, etc.).

_Dive into the_ [_Querying Guide_](../guides/active-record-with-cql/querying.md) _for all query-building capabilities._

### Transactions

Maintain data integrity with ACID-compliant database transactions. CQL provides both model-level transaction support and a service objects pattern for complex operations.

```crystal
# Basic transaction usage
BankAccount.transaction do |tx|
  account = BankAccount.find(1)
  account.balance -= 100
  account.save!

  Transaction.create!(
    amount: 100,
    transaction_type: "withdrawal",
    from_account_id: account.id,
    created_at: Time.utc
  )

  # All operations succeed or fail together
end
```

_Learn more in the_ [_Transactions Guide_](broken-reference) _for maintaining data integrity across multiple operations._

### Validations

Ensure data integrity with built-in or custom validation rules triggered before saving records.

_Learn more in the_ [_Validations Guide_](validations.md)_._

### Callbacks

Execute custom logic at different points in a model's lifecycle (e.g., `before_save`, `after_create`).

_Consult the_ [_Callbacks Guide_](callbacks.md) _for usage details._

### Relations

Define associations like `belongs_to`, `has_many`, `has_one`, and `many_to_many` to manage relationships between models.

* [`belongs_to`](../guides/active-record-with-cql/relationships/belongsto.md)
* [`has_one`](../guides/active-record-with-cql/relationships/hasone.md)
* [`has_many`](../guides/active-record-with-cql/relationships/hasmany.md)
* [`many_to_many`](../guides/active-record-with-cql/relationships/manytomany.md)

### Migrations

Manage database schema changes systematically using Crystal-based migration files.

_See the_ [_Database Migrations Guide_](broken-reference) _for how to write and run migrations._

### Scopes

Create reusable query shortcuts to keep your code clean and expressive.

_Read the_ [_Scopes Guide_](scopes.md) _for defining and using scopes._
