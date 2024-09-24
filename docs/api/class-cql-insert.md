# class CQL::Insert

`Reference` < `Object`

The `CQL::Insert` class is responsible for building SQL `INSERT` statements. It provides methods to construct and execute these statements, allowing for both single and multiple record inserts.

## Example: Inserting a Single Record

```crystal
insert
  .into(:users)
  .values(name: "John", age: 30)
  .last_insert_id
```

## Example: Inserting Multiple Records

```crystal
insert
  .into(:users)
  .values([
    {name: "John", age: 30},
    {name: "Jane", age: 25}
  ])
```

## Methods

### def into(table : Symbol)

Specifies the table to insert the records into.

* **@param** table \[Symbol] The name of the table.
* **@return** \[Insert] The insert statement.

### def values(data : Hash(Symbol, DB::Any))

Specifies the data to insert into the table.

* **@param** data \[Hash(Symbol, DB::Any)] A hash of column names and values.
* **@return** \[Insert] The insert statement.

### def last\_insert\_id

Retrieves the last inserted record's ID.

* **@return** \[Int64] The ID of the last inserted record.

**Example**:

```crystal
id = insert.into(:users).values(name: "John").last_insert_id
```
