---
icon: arrow-right-to-arc
---

# Introduction

## Purpose of CQL

CQL (Crystal Query Language) is a powerful Object-Relational Mapping (ORM) library designed for developers working with the Crystal programming language. It provides a type-safe, high-performance interface for interacting with SQL databases, combining the flexibility of raw SQL with the safety and clarity of Crystal's static type system.

CQL follows the Active Record pattern while maintaining flexibility to support Repository and Data Mapper patterns. It leverages Crystal's compile-time optimizations and macro system to provide excellent performance without sacrificing developer experience.

### Key Features

- **Type-Safe ORM**: Leverages Crystal's static type system for compile-time safety
- **Macro-Powered DSL**: Uses Crystal macros for defining models, relationships, and validations
- **Multi-Database Support**: Works with PostgreSQL, MySQL, and SQLite through Crystal DB drivers
- **Active Record Pattern**: Provides an intuitive Active Record API with full CRUD operations
- **Advanced Relationships**: Support for `has_many`, `belongs_to`, `has_one`, and `many_to_many` associations with lazy loading and eager loading
- **Comprehensive Validations**: Built-in validation system with custom validator support
- **Lifecycle Callbacks**: Before/after hooks for validation, save, create, update, and destroy operations
- **Database Migrations**: Schema evolution tools for managing database changes
- **Query Builder**: Fluent interface for building complex SQL queries with joins and subqueries
- **Transactions**: Full transaction support with rollback capabilities
- **Optimistic Locking**: Built-in support for optimistic concurrency control
- **Scopes**: Reusable query scopes for common filtering patterns
- **Performance Optimized**: Compile-time optimizations for excellent runtime performance

### Supported Primary Key Types

CQL supports multiple primary key types for flexibility:

- **Int32** and **Int64**: Traditional integer primary keys
- **UUID**: For distributed systems requiring globally unique identifiers
- **ULID**: Universally Unique Lexicographically Sortable Identifiers
- **Custom Types**: Extensible to support custom primary key types

### Supported Databases

CQL is designed to work with major SQL databases:

- **PostgreSQL**: Full support with advanced features like JSONB, arrays, and custom types
- **MySQL**: Complete MySQL support with proper dialect handling
- **SQLite**: Lightweight database support perfect for development, testing, and embedded applications

Each database adapter includes proper dialect handling to ensure optimal SQL generation and feature support.

### Use Cases

CQL is ideal for:

- **Web Applications**: Building robust web APIs and applications with Crystal
- **Microservices**: Creating data-driven microservices with type safety
- **Enterprise Applications**: Large-scale applications requiring performance and reliability
- **Development & Testing**: SQLite support makes it perfect for development environments
- **Data-Intensive Applications**: Applications requiring complex queries and relationships

Whether you're building a small application or a large enterprise system, CQL provides the performance, type safety, and developer experience needed for successful Crystal applications.
