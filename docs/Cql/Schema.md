---
title: "Cql::Schema"
---

# class Cql::Schema

`Reference` < `Object`

The `Schema` class represents a database schema.

This class provides methods to build and manage a database schema, including
creating tables, executing SQL statements, and generating queries.

**Example** Creating a new schema

```crystal
schema = Cql::Schema.define(:northwind, "sqlite3://db.sqlite3") do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String
    column :email, String
  end
end
```

**Example** Executing a SQL statement

```crystal
schema.exec("CREATE TABLE products (id INTEGER PRIMARY KEY, name TEXT)")
```

**Example** Creating a new query

```crystal
query = schema.query
```

The `Schema` class represents a database schema.

## Constants

### Log

```crystal
::Log.for(self)
```

## Constructors

### def new`(name : Symbol, uri : String, adapter : Adapter = Adapter::Sqlite, version : String = "1.0")`

Initializes a new schema.

- **@param** name [Symbol] the name of the schema
- **@param** uri [String] the URI of the database
- **@param** adapter [Adapter] the database adapter (default: `Adapter::Sqlite`)
- **@param** version [String] the version of the schema (default: "1.0")

**Example** Initializing a new schema

```crystal
schema = Cql::Schema.new(:northwind, "sqlite3://db.sqlite3")
```

## Class Methods

### def db_context`(name : Symbol, uri : String, adapter : Adapter = Adapter::Sqlite, version : String = "1.0", &)`

Builds a new schema.

- **@param** name [Symbol] the name of the schema
- **@param** uri [String] the URI of the database
- **@param** adapter [Adapter] the database adapter (default: `Adapter::Sqlite`)
- **@param** version [String] the version of the schema (default: "1.0")
- **@yield** [Schema] the schema being built
- **@return** [Schema] the built schema

**Example**

```crystal
schema = Cql::Schema.db_context(:northwind, "sqlite3://db.sqlite3") do |s|
  s.create_table :users do
    primary :id, Int64, auto_increment: true
    column :name, String
    column :email, String
  end
end
```

## Instance Methods

### def adapter

- **@return** [Adapter] the database adapter (default: `Adapter::Sqlite`)

### def alter`(table_name : Symbol, &)`

Alter a table in the schema.

- **@param** table_name [Symbol] the name of the table
- **@yield** [AlterTable] the table being altered
  **Example**

```crystal
schema.alter(:users) do |t|
  t.add_column :age, Int32
end
```

**Example**

```crystal
schema.alter(:users) do |t|
  t.drop_column :age
end
```

### def db

- **@return** [DB::Connection] the database connection

### def delete

Creates a new delete query for the schema.

- **@return** [Delete] the new delete query
  **Example**

```crystal
delete = schema.delete
```

### def exec`(sql : String)`

Executes a SQL statement.

- **@param** sql [String] the SQL statement to execute

**Example**

```crystal
schema.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
```

### def gen

- **@return** [Expression::Generator] the expression generator

### def insert

Creates a new insert query for the schema.

- **@return** [Insert] the new insert query
  **Example**

```crystal
insert = schema.insert
```

### def migrator

Creates a new migrator for the schema.

- **@return** [Migrator] the new migrator
  **Example**

```crystal
migrator = schema.migrator
```

### def name

- **@return** [Symbol] the name of the schema

### def query

Creates a new query for the schema.

- **@return** [Query] the new query

**Example**

```crystal
query = schema.query
```

### def table`(name : Symbol, as as_name = nil, &)`

Creates a new table in the schema.

- **@param** name [Symbol] the name of the table
- **@param** as_name [Symbol] the alias of the table
- **@yield** [Table] the table being created
- **@return** [Table] the created table
  **Example**

```crystal
schema.create_table :users do
  primary :id, Int64, auto_increment: true
  column :name, String
  column :email, String
end
```

### def tables

- **@return** [Hash(Symbol, Table)] the tables in the schema

### def update

Creates a new update query for the schema.

- **@return** [Update] the new update query
  **Example**

```crystal
update = schema.update
```

### def uri

- **@return** [String] the URI of the database

### def version

- **@return** [String] the version of the schema

## Macros

### macro method_missing`(call)`
