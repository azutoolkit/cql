# class CQL::Delete

`Reference` < `Object`

The `CQL::Delete` class represents a SQL `DELETE` query. It provides methods to construct and execute delete queries.

## Example: Deleting a Record

```crystal
delete.from(:users).where(id: 1).commit
```

## Constructors

### def new(schema : Schema)

Initializes a new delete query.

- **@param** schema \[Schema] The schema to use.
- **@return** \[Delete] The delete query object.

**Example**:

```crystal
delete = CQL::Delete.new(schema)
```

## Methods

### def from(table : Symbol)

Specifies the table to delete from.

- **@param** table \[Symbol] The name of the table.
- **@return** \[Delete] The delete query object.

**Example**:

```crystal
delete.from(:users)
```

### def where(conditions : Hash(Symbol, DB::Any))

Adds a `WHERE` clause to the delete query.

- **@param** conditions \[Hash(Symbol, DB::Any)] A hash of conditions for the delete operation.
- **@return** \[Delete] The delete query object.

**Example**:

```crystal
delete.where(id: 1)
```

### def commit

Executes the delete query.

- **@return** \[Nil]

**Example**:

```crystal
delete.from(:users).where(id: 1).commit
```
