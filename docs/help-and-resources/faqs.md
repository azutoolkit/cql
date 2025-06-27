---
icon: comments-question
---

# Frequently Asked Questions

This page answers common questions about Crystal Query Language (CQL) and its Active Record implementation.

***

## General CQL Questions

**Q: What is CQL (Crystal Query Language)?**

A: CQL is an Object-Relational Mapping (ORM) library for the Crystal programming language. It provides an abstraction over SQL databases, enabling developers to define and interact with relational data using Crystal objects and a type-safe query builder, rather than writing raw SQL queries directly for most operations.

**Q: What are the key features of CQL?**

A: Key features typically include:

* Type-safe query building leveraging Crystal's static type system.
* A macro-powered DSL for defining models and their mappings.
* Support for multiple database adapters (e.g., PostgreSQL, MySQL, SQLite).
* Migrations system for managing database schema changes.
* An Active Record pattern implementation for model interaction (and flexibility for other patterns).

**Q: How do I install CQL?**

A: You can install CQL by adding it to your project's `shard.yml` file:

```yaml
dependencies:
  cql:
    github: azutoolkit/cql # Or the appropriate source for your CQL version
    version: "~> x.y.z" # Specify the version you are using
```

Then, run `shards install` in your terminal to download and install the dependency.\
For more setup details, see the [Active Record Setup Guide](../active-record-with-cql/active-record-with-cql.md#prerequisites-and-setup).

**Q: Which databases does CQL support?**

A: CQL is designed to support major relational databases through Crystal DB drivers. Commonly supported databases include PostgreSQL, MySQL, and SQLite. Check the specific CQL version documentation for the most up-to-date list and any driver requirements.

***

## Active Record Specific Questions

**Q: What is the Active Record pattern in CQL?**

A: The Active Record pattern maps database tables to Crystal structs (models). Each instance of a model corresponds to a row in the table. This pattern provides methods directly on the model and its instances for database interaction (CRUD operations, queries, etc.).

* For a conceptual overview, see [Active Record Pattern Concept](../../core-concepts/patterns/active-record.md).
* For a detailed guide on using it with CQL, see [Active Record with CQL Guide](../active-record-with-cql/active-record-with-cql.md).

**Q: How do I define an Active Record model in CQL?**

A: You define a model by creating a Crystal `struct`, including `CQL::ActiveRecord::Model(PrimaryKeyType)`, and using the `db_context` macro to link it to a database table and context.

* Learn more in the [Defining Models Guide](../active-record-with-cql/defining-models.md).

**Q: How do I perform basic Create, Read, Update, and Delete (CRUD) operations?**

A: CQL Active Record provides intuitive methods like `new`/`save`, `create!`, `find?`, `find_by!`, `update!`, and `delete!` directly on your models and their instances.

* For comprehensive examples, see the [CRUD Operations Guide](../active-record-with-cql/crud-operations.md).

**Q: How can I build more complex queries?**

A: CQL offers a chainable query interface. You can start with `Model.query` or methods like `Model.where(...)` and then chain further conditions like `.order()`, `.limit()`, `.join()`, etc.

* Explore the [Queryable Guide](../active-record-with-cql/queryable.md) for detailed information.

**Q: How do I handle database relationships (e.g., `has_many`, `belongs_to`)?**

A: CQL Active Record uses macros like `has_many`, `belongs_to`, `has_one`, and `many_to_many` to define associations between models.

* See the [Relations section in the main Active Record guide](../active-record-with-cql/active-record-with-cql.md#relations) for links to detailed guides on each relationship type:
  * [`belongs_to`](../active-record-with-cql/relations/belongsto.md)
  * [`has_one`](../active-record-with-cql/relations/hasone.md)
  * [`has_many`](../active-record-with-cql/relations/hasmany.md)
  * [`many_to_many`](../active-record-with-cql/relations/manytomany.md)

**Q: How are validations handled in CQL Active Record?**

A: You can define validations in your model to ensure data integrity (e.g., presence, length, format). Invalid records will not be saved, and errors can be inspected on the model instance.

* Refer to the [Validations Guide](../active-record-with-cql/validations.md).

**Q: What are callbacks and how do I use them?**

A: Callbacks are methods that get triggered at specific points in a model's lifecycle (e.g., `before_save`, `after_create`). They allow you to run custom logic automatically.

* Learn how to use them in the [Callbacks Guide](../active-record-with-cql/callbacks.md).

**Q: What's the difference between `save` and `save!` (or `create` and `create!`)?**

A: Methods ending with `!` (bang methods) typically raise an exception if the operation fails (e.g., a validation error occurs or the record isn't found). Methods without `!` usually return `false` or `nil` on failure, allowing you to handle errors programmatically without a `begin/rescue` block for common cases.

* Example: `user.save` returns `true` or `false`. `user.save!` returns `true` or raises an exception (e.g., `CQL::Errors::RecordInvalid`).

**Q: How does CQL handle database migrations for Active Record models?**

A: CQL includes a migration system where you define schema changes in Crystal classes (e.g., creating tables, adding columns). These migrations can be run to update your database schema in a version-controlled manner.

* For details, see the [Database Migrations Guide for Active Record](../database-management/migrations.md).
* For a general overview of migrations in CQL, see [Core Concepts: Migrations](../../core-concepts/migrations.md).

**Q: Does CQL Active Record support database transactions?**

A: Yes, database transactions are crucial for ensuring data consistency, especially when multiple database operations need to succeed or fail together. CQL typically provides a way to manage transactions.

* See the [Transactions Guide](../active-record-with-cql/transactions.md) for more details on how to use transactions with Active Record models.

***

## Troubleshooting and Further Information

**Q: Where can I find more detailed documentation on Active Record features?**

A: The primary resource is the [Active Record with CQL main guide](../active-record-with-cql/active-record-with-cql.md), which links to all specialized guides covering different aspects of the Active Record implementation.

**Q: I think I found a bug or want to suggest a feature. How do I proceed?**

A: Typically, you would report issues or suggest features via the GitHub repository for CQL (e.g., `azutoolkit/cql` or the specific fork/version you are using). Look for an "Issues" tab to see if similar issues exist or to create a new one. Contributions via Pull Requests are also often welcome after discussing the proposed changes.

**Q: Is there a community or forum for CQL users?**

A: Check the official CQL repository or related Crystal community channels (like the Crystal forum, Discord, or Gitter) for discussions, help, and community support related to CQL.

***

If your question isn't answered here, please check the other documentation sections or consider reaching out to the CQL community.
