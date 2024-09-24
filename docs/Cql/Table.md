# class CQL::Table

`Reference` < `Object`

The `CQL::Table` class represents a table in the database and is responsible for handling table creation, modification, and deletion.

## Example: Creating a Table

```crystal
table = Table.new(:users, schema)
table.column(:id, Int64, primary: true)
table.column(:name, String)
table.create_sql
# => "CREATE TABLE users (id BIGINT PRIMARY KEY, name TEXT);"
```

## Methods

### def new(name : Symbol, schema : Schema)

Initializes a new table with the specified name and schema.

- **@param** name \[Symbol] The name of the table.
- **@param** schema \[Schema] The schema to which the table belongs.
- **@return** \[Table] The created table object.

**Example**:

```crystal
table = Table.new(:users, schema)
```

### def column(name : Symbol, type : Type, primary : Bool = false)

Defines a column for the table.

- **@param** name \[Symbol] The name of the column.
- **@param** type \[Type] The data type of the column.
- **@param** primary \[Bool] Whether the column is the primary key (default: `false`).
- **@return** \[Table] The updated table object.

**Example**:

```crystal
table.column(:id, Int64, primary: true)
table.column(:name, String)
```

### def create_sql

Generates the SQL statement to create the table.

- **@return** \[String] The SQL `CREATE TABLE` statement.

**Example**:

```crystal
table.create_sql
# => "CREATE TABLE users (id BIGINT PRIMARY KEY, name TEXT);"
```

### def drop

Drops the table from the database.

- **@return** \[String] The SQL `DROP TABLE` statement.

**Example**:

```crystal
table.drop
# => "DROP TABLE users;"
```
