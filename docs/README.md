---
icon: database
---

# README

**CQL (Crystal Query Language)** - A type-safe ORM for Crystal with Active Record, Repository, and Data Mapper patterns.

## Quick Start

**New to CQL?**

1. [Installation](installation.md) - Setup and configuration
2. [Getting Started](guides/getting-started.md) - First application
3. [Active Record Guide](guides/active-record-with-cql/) - Most common pattern

**Migration from another ORM?**

1. [Feature Comparison](guides/feature-comparison.md)
2. [Migration Guide](guides/migration-guide.md)

## Core Documentation

### Foundation

* [Installation](installation.md) - Setup for PostgreSQL, MySQL, SQLite
* [Configuration](guides/configuration.md) - Database and environment setup
* [Core Concepts](core-concepts/) - Schemas, tables, relationships

### Active Record Pattern

* [Models & CRUD](guides/active-record-with-cql/defining-models.md)
* [Querying & Scopes](guides/active-record-with-cql/queryable.md)
* [Relationships](guides/active-record-with-cql/relations/)
* [Validations](guides/active-record-with-cql/validations.md)
* [Callbacks](guides/active-record-with-cql/callbacks.md)
* [Migrations](guides/active-record-with-cql/migrations.md)

### Advanced Topics

* [Performance Optimization](guides/performance-optimization.md)
* [Security Guide](guides/security-guide.md)
* [Testing Strategies](guides/testing-strategies.md)
* [Best Practices](guides/best-practices.md)

### Reference

* [Examples](examples/) - Working code examples
* [Troubleshooting](troubleshooting.md) - Common issues and solutions
* [FAQ](faqs.md) - Frequently asked questions

## Quick Reference

| Task           | Documentation                                                                                                                             |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| **Setup**      | [Installation](installation.md) → [Configuration](guides/configuration.md)                                                                |
| **Models**     | [Defining Models](guides/active-record-with-cql/defining-models.md) → [CRUD Operations](guides/active-record-with-cql/crud-operations.md) |
| **Queries**    | [Queryable](guides/active-record-with-cql/queryable.md) → [Performance](guides/performance-optimization.md)                               |
| **Database**   | [Migrations](guides/active-record-with-cql/migrations.md) → [Schema](core-concepts/schemas.md)                                            |
| **Production** | [Security](guides/security-guide.md) → [Testing](guides/testing-strategies.md)                                                            |

***

All examples are tested with the latest CQL version.
