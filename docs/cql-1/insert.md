---
title: Cql::Insert
---

# class Cql::Insert

`Reference` < `Object`

An insert statement builder class This class provides methods for building an insert statement It also provides methods for executing the statement

**Example** Inserting a record

```crystal
insert
  .into(:users)
  .values(name: "John", age: 30)
  .last_insert_id
```

**Example** Inserting multiple records

```crystal
insert
  .into(:users)
  .values(
    [
      {name: "John", age: 30},
      {name: "Jane", age: 25},
    ]
  ).commit
```

**Example** Inserting a record with a query

```crystal
insert
  .into(:users)
  .query(
    select.from(:users).where(id: 1)
  ).commit
```

details Table of Contents \[\[toc]]

## Constants

### Log

```crystal
::Log.for(self)
```

## Constructors

### def new`(schema : Schema)`

## Instance Methods

### def back`(*columns : Symbol)`

Set the columns to return

* **@param** columns \[Symbol\*] The columns to return
* **@return** \[Insert] The insert object
* **@raise** \[Exception] If the column does not exist

**Example** Inserting a record

```crystal
insert.into(:users).values(name: "John", age: 30).back(:id).commit
```

### def build

Build the insert statement object **@return** \[Expression::Insert] The insert statement

**Example** Building the insert statement

```crystal
insert.into(:users).values(name: "John", age: 30).commit
```

### def commit

Executes the insert statement and returns the result

* **@return** \[Int64] The last inserted ID

**Example** Inserting a record

```crystal
insert
  .into(:users)
  .values(name: "John", age: 30)
  .commit

=> 1
```

### def into`(table : Symbol)`

Set the table to insert into

* **@param** table \[Symbol] The table to insert into
* **@return** \[Insert] The insert object

**Example** Inserting a record

```crystal
insert
  .into(:users)
  .values(name: "John", age: 30)
  .commit
```

### def last\_insert\_id`(as type : PrimaryKeyType = Int64)`

Inserts and gets the last inserted ID from the database Works with SQLite, PostgreSQL and MySQL.

* **@return** \[Int64] The last inserted ID

**Example** Getting the last inserted ID

```crystal
insert.into(:users).values(name: "John", age: 30).last_insert_id
```

### def query`(query : Query)`

Set the query to use for the insert

* **@param** query \[Query] The query to use
* **@return** \[Insert] The insert object

**Example** Inserting a record with a query

```crystal
insert.into(:users).query(select.from(:users).where(id: 1)).commit
```

### def to\_sql`(gen = @schema.gen)`

Convert the insert object to a SQL query

* **@param** gen \[Generator] The generator to use
* **@return** \[{String, Array(DB::Any)}] The query and parameters
* **@raise** \[Exception] If the table does not exist

**Example** Generating a SQL query

```crystal
insert.into(:users).values(name: "John", age: 30).to_sql
```

### def values`(values : Array(Hash(Symbol, DB::Any)))`

Set the columns to insert

* **@param** columns \[Array(Symbol)] The columns to insert
* **@return** \[Insert] The insert object

**Example** Inserting a record

```crystal
insert
  .into(:users)
  .columns(:name, :age)
  .values("John", 30)
  .commit
```

### def values`(hash : Hash(Symbol, DB::Any))`

Set the values to insert

* **@param** hash \[Hash(Symbol, DB::Any)] The values to insert
* **@return** \[Insert] The insert object

**Example** Inserting a record

```crystal
insert.into(:users).values(name: "John", age: 30).commit
```

### def values

Set the values to insert

* **@param** fields \[Hash(Symbol, DB::Any)] The values to insert
* **@return** \[Insert] The insert object

**Example** Inserting a record

```crystal
insert.into(:users).values(name: "John", age: 30).commit
```
