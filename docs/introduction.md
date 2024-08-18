# Introduction

## Purpose of CQL

CQL (Crystal Query Language) is a powerful tool designed for developers working with the Crystal programming language. It provides a streamlined interface for interacting with SQL databases, combining the flexibility of raw SQL with the safety and clarity of Crystal’s type system. CQL simplifies complex database operations, making it easier to perform CRUD (Create, Read, Update, Delete) operations, manage database schemas, and execute advanced queries.

### Key Features

* **Database-agnostic**: CQL supports multiple databases, ensuring flexibility in project development.
* **Active Record Pattern**: Integrates seamlessly with Crystal structs, allowing developers to work with database records as native Crystal objects.
* **Query Builder**: Provides an intuitive API for constructing complex SQL queries, including joins, subqueries, and transactions.
* **Associations**: CQL supports defining relationships between tables (`has_many`, `belongs_to`, `many_to_many`), making it easy to navigate related data.
* **Migrations**: Facilitates schema evolution by allowing developers to create and manage database migrations.

### Supported Databases

CQL is designed to work with a range of SQL databases, including:

* **PostgreSQL**: Full support with advanced features like JSONB, arrays, and full-text search.
* **MySQL**: Support for common MySQL operations, though more advanced features may be limited.
* **SQLite**: Lightweight database support for development and testing environments.

### Use Cases

CQL is ideal for developers looking to integrate Crystal with SQL databases, providing a robust toolset for building data-driven applications. Whether you are developing a small-scale application or a large enterprise system, CQL offers the performance and scalability needed to manage your database operations efficiently.
