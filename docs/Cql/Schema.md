
---
title: "Cql::Schema"
---

# class Cql::Schema

`Reference` < `Object`

The `Cql::Schema` class represents a database schema. It provides methods to build and manage database schemas, including creating tables, executing SQL statements, and generating queries.

## Example: Creating a New Schema

```crystal
schema = Cql::Schema.define(:northwind, "sqlite3://db.sqlite3") do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String
    column :email, String
  end
end
```

## Methods

### def define(name : Symbol, uri : String, &block)

Defines a new schema.

- **@param** name \[Symbol] The name of the schema.
- **@param** uri \[String] The URI of the database.
- **@yield** \[Schema] The schema being defined.
- **@return** \[Schema] The defined schema.

### def table(name : Symbol, &block)

Creates a new table in the schema.

- **@param** name \[Symbol] The name of the table.
- **@yield** \[Table] The table being created.
- **@return** \[Table] The created table.

**Example**:

```crystal
schema.table :users do
  primary :id, Int64, auto_increment: true
  column :name, String
  column :email, String
end
```

### def exec(sql : String)

Executes a raw SQL statement.

- **@param** sql \[String] The SQL statement to execute.
- **@return** \[Nil]

**Example**:

```crystal
schema.exec("CREATE TABLE products (id INTEGER PRIMARY KEY, name TEXT)")
```
