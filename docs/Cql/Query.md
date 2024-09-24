---
title: "CQL::Query"
---

# class CQL::Query

`Reference` < `Object`

The `CQL::Query` class is responsible for building and executing SQL queries. It allows you to construct queries with methods for selecting columns, specifying tables, applying conditions, and executing the queries.

## Example: Creating a Query

```crystal
schema = CQL::Schema.new

query = CQL::Query.new(schema)
query.select(:name, :age).from(:users).where(name: "John").all(User)
# => [{"name" => "John", "age" => 30}]
```

## Methods

### def select(\*columns : Symbol)

Specifies the columns to select in the query.

- **@param** columns \[Symbol] The names of the columns to select.
- **@return** \[Query] The query object.

### def from(table : Symbol)

Specifies the table to query.

- **@param** table \[Symbol] The name of the table.
- **@return** \[Query] The query object.

**Example**:

```crystal
query.from(:users)
```

### def where(conditions : Hash(Symbol, DB::Any))

Adds a `WHERE` clause to the query.

- **@param** conditions \[Hash(Symbol, DB::Any)] A hash of conditions to apply.
- **@return** \[Query] The query object.

**Example**:

```crystal
query.where(name: "John", active: true)
```

### def execute

Executes the query and returns the results.

- **@return** \[Array(DB::ResultSet)] The result set from the query.

**Example**:

```crystal
results = query.execute
```
