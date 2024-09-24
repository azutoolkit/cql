# enum CQL::Adapter

`Enum` < `Comparable` < `Value` < `Object`

The `CQL::Adapter` enum represents different database adapters such as SQLite, MySQL, and PostgreSQL.

## Constants

### Sqlite

Represents the SQLite adapter.

```crystal
CQL::Adapter::Sqlite
```

### MySql

Represents the MySQL adapter.

```crystal
CQL::Adapter::MySql
```

### Postgres

Represents the PostgreSQL adapter.

```crystal
CQL::Adapter::Postgres
```

## Methods

### def sql\_type(type : Type)

Returns the SQL type for the given data type.

* **@param** type \[Type] The data type.
* **@return** \[String] The SQL type as a string.

**Example**:

```crystal
CQL::Adapter::Sqlite.sql_type(String)
# => "TEXT"
```

### def my\_sql?

Checks if the adapter is MySQL.

* **@return** \[Bool] `true` if the adapter is MySQL, `false` otherwise.

### def postgres?

Checks if the adapter is PostgreSQL.

* **@return** \[Bool] `true` if the adapter is PostgreSQL, `false` otherwise.
