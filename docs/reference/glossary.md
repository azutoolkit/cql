# Glossary

Common terms and definitions used in CQL documentation.

## A

### Active Record
A design pattern where objects carry both data and behavior. In CQL, models that include `CQL::ActiveRecord::Model` follow this pattern.

### Adapter
The database-specific driver that CQL uses to communicate with different database systems. CQL supports PostgreSQL, MySQL, SQLite and CockroachDB adapters.

### Association
A relationship between two models. See: belongs_to, has_one, has_many, many_to_many.

## B

### Belongs To
A relationship where a model references another model via a foreign key. The model with `belongs_to` holds the foreign key.

## C

### Callback
A method that is automatically called at specific points during a model's lifecycle (e.g., before_save, after_create). Registered by method name, e.g. `before_save :normalize_email`; returning `false` halts the operation.

### Column
A single field in a database table, represented as a property in a CQL model.

### CRUD
Create, Read, Update, Delete - the four basic operations for persistent storage.

## D

### Database Context
The connection between a model and its database table, defined using `db_context`.

### Down Migration
The reverse operation of a migration, typically used to rollback changes.

## F

### Foreign Key
A column that references the primary key of another table, establishing a relationship between tables.

## H

### Has Many
A relationship where a model has multiple related records in another table.

### Has One
A relationship where a model has exactly one related record in another table.

## I

### Index
A database structure that improves query performance on specific columns.

## J

### Join Model
A model for the join table of a many-to-many relationship, passed as `join_through:` to `many_to_many`.

## M

### Migration
A versioned change to the database schema, allowing incremental updates to the database structure.

### Model
A Crystal struct or class that represents a database table and provides methods for interacting with its data.

## O

### Optimistic Locking
A concurrency control strategy that detects conflicts when saving records by checking a version column.

### ORM
Object-Relational Mapping - a technique for converting data between incompatible type systems (objects and relational databases).

## P

### Persistence
The process of saving data to a database so it survives beyond the application's runtime.

### Preload
Loading a `has_many`, `belongs_to` or `has_one` association for many records with one extra query instead of one query per record (`User.preload(:posts)`, `Post.preload(:user)`).

### Primary Key
A unique identifier for each record in a table, typically named `id`.

### Property
A Crystal attribute that maps to a database column.

## Q

### Query Builder
A fluent interface for constructing SQL queries programmatically (`CQL::Query`, and `QueryBuilder(T)` for model queries).

## R

### Relationship
A connection between two database tables, represented in CQL using belongs_to, has_one, has_many, or many_to_many.

### Rollback
Reverting a database migration to its previous state.

## S

### Schema
The structure of a database, including its tables, columns, indexes, and relationships.

### Scope
A reusable, chainable query defined on a model with the `scope` macro (`scope :published, -> { where(published: true) }`).

### Soft Delete
A technique where records are marked as deleted (using a `deleted_at` timestamp) rather than being removed from the database. In CQL, include `CQL::ActiveRecord::SoftDeletable`.

## T

### Table
A collection of related data organized in rows and columns within a database.

### Telemetry
`CQL::Telemetry`, the event stream CQL publishes for every statement and transaction, used for logging, metrics and tracing.

### Timestamps
Columns that track when records are created (`created_at`) and updated (`updated_at`). `save` fills them in automatically.

### Transaction
A sequence of database operations that are executed as a single unit, ensuring all operations succeed or all are rolled back.

## U

### Up Migration
The forward operation of a migration that applies changes to the database.

### UUID
Universally Unique Identifier - a 128-bit identifier that can be used as a primary key.

## V

### Validation
Rules that ensure data meets certain criteria before being saved to the database.

### Version Column
A column used for optimistic locking that increments with each update.
