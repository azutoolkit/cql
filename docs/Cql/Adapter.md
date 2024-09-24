
---
title: "Cql::Adapter"
---

# enum Cql::Adapter

`Enum` < `Comparable` < `Value` < `Object`

The `Cql::Adapter` enum represents different database adapters such as SQLite, MySQL, and PostgreSQL.

## Constants

### Sqlite

Represents the SQLite adapter.

```crystal
Cql::Adapter::Sqlite
```

### MySql

Represents the MySQL adapter.

```crystal
Cql::Adapter::MySql
```

### Postgres

Represents the PostgreSQL adapter.

```crystal
Cql::Adapter::Postgres
```

## Methods

### def sql_type(type : Type)

Returns the SQL type for the given data type.

- **@param** type \[Type] The data type.
- **@return** \[String] The SQL type as a string.

**Example**:

```crystal
Cql::Adapter::Sqlite.sql_type(String)
# => "TEXT"
```

### def my_sql?

Checks if the adapter is MySQL.

- **@return** \[Bool] `true` if the adapter is MySQL, `false` otherwise.

### def postgres?

Checks if the adapter is PostgreSQL.

- **@return** \[Bool] `true` if the adapter is PostgreSQL, `false` otherwise.
