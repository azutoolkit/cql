---
title: Cql::Delete
---

# class Cql::Delete

`Reference` < `Object`

A delete query This class represents a delete query It provides methods for building a delete query It also provides methods for executing the query

**Example** Deleting a record

```crystal
delete.from(:users).where(id: 1).commit
```

details Table of Contents \[\[toc]]

## Constructors

### def new`(schema : Schema)`

Initialize the delete query

* **@param** schema \[Schema] The schema to use
* **@return** \[Delete] The delete query object

**Example** Deleting a record

```crystal
delete = Cql::Delete.new(schema)
  .from(:users)
  .where(id: 1)
  .commit
```

## Instance Methods

### def back`(*columns : Symbol)`

Sets the columns to return after the delete

* **@param** columns \[Symbol\*] The columns to return
* **@return** \[self] The current instance
* **@raise** \[Exception] If the column does not exist

**Example** Setting the columns to return

```crystal
delete = Cql::Delete.new(schema)
  .from(:users)
  .back(:name, :age)
```

### def build

Builds the delete expression

* **@return** \[Expression::Delete] The delete expression
* **@raise** \[Exception] If the table is not set
* **@raise** \[Exception] If the where clause is not set

**Example** Building the delete expression

```crystal
delete = Cql::Delete.new(schema)
  .from(:users)
  .where(id: 1)
  .commit
```

### def commit

Executes the delete query and returns the result

* **@return** \[DB::Result] The result of the query

**Example** Deleting a record

```crystal
delete = Cql::Delete.new(schema)
  .from(:users)
  .where(id: 1)
  .commit
```

### def from`(table : Symbol)`

Sets the table to delete from

* **@param** table \[Symbol] The name of the table
* **@return** \[self] The current instance
* **@raise** \[Exception] If the table does not exist

**Example** Setting the table

```crystal
delete = Cql::Delete.new(schema)
  .from(:users)
```

### def to\_sql`(gen = @schema.gen)`

Generates the SQL query and parameters

* **@param** gen \[Expression::Generator] The generator to use
* **@return** \[{String, Array(DB::Any)}] The query and parameters

**Example** Generating a delete query

```crystal
delete = Cql::Delete.new(schema)
  .from(:users)
  .where(id: 1)
  .to_sql
```

### def using`(table : Symbol)`

Sets the table to use in the using clause

* **@param** table \[Symbol] The name of the table
* **@return** \[self] The current instance
* **@raise** \[Exception] If the table does not exist

**Example** Setting the using table

```crystal
delete = Cql::Delete.new(schema)
  .from(:users)
  .using(:posts)
```

### def where

Sets the columns to return

* **@param** columns \[Symbol\*] The columns to return
* **@return** \[self] The current instance
* **@raise** \[Exception] If the column does not exist

**Example** Setting the columns to return

```crystal
delete = Cql::Delete.new(schema)
  .from(:users)
  .back(:name, :age)
```

### def where`(attr : Hash(Symbol, DB::Any))`

Where clause using a hash of conditions to match against

* **@param** attr \[Hash(Symbol, DB::Any)] The conditions to match against
* **@return** \[self] The current instance

**Example** Setting the where clause

```crystal
delete = Cql::Delete.new(schema)
  .from(:users)
  .where(id: 1)
```

### def where

Sets the columns to return

* **@param** columns \[Symbol\*] The columns to return
* **@return** \[self] The current instance
* **@raise** \[Exception] If the column does not exist

**Example** Setting the columns to return

```crystal
delete = Cql::Delete.new(schema)
  .from(:users)
  .back(:name, :age)
```
