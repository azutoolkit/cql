---
title: "Cql::Update"
---

::: v-pre
# class Cql::Update
`Reference` < `Object`


The `Cql::Update` class represents an SQL UPDATE statement.

**Example**

```crystal
update = Cql::Update.new(schema)
  .table(:users)
  .set(name: "John", age: 30)
  .where { |w| w.id == 1 }
  .commit
```

## Usage

- `initialize(schema : Schema)` - Initializes a new instance of `Cql::Update` with the given schema.
- `commit : DB::Result` - Executes the update query and returns the result.
- `to_sql(gen = @schema.gen) : {String, Array(DB::Any)}` - Generates the SQL query and parameters.
- `table(table : Symbol) : self` - Sets the table to update.
- `set(setters : Hash(Symbol, DB::Any)) : self` - Sets the column values to update using a hash.
- `set(**fields) : self` - Sets the column values to update using keyword arguments.
- `where(&block) : self` - Sets the WHERE clause using a block.
- `where(**fields) : self` - Sets the WHERE clause using keyword arguments.
- `back(*columns : Symbol) : self` - Sets the columns to return after the update.
- `build : Expression::Update` - Builds the `Expression::Update` object.
::: details Table of Contents
[[toc]]
:::



## Constructors


### def new`(schema : Schema)`





## Instance Methods


### def back`(*columns : Symbol)`

Sets the columns to return after the update.
- **@param** columns [Array(Symbol)] the columns to return
- **@return** [self] the current instance

**Example**
```crystal
update = Cql::Update.new(schema)
  .table(:users)
  .set(name: "John", age: 30)
  .where { |w| w.id == 1 }
  .back(:name, :age)
  .commit

=> {"UPDATE users SET name = $1, age = $2 WHERE id = $3 RETURNING name, age", ["John", 30, 1]}
```




### def build

Builds the `Expression::Update` object.
- **@return** [Expression::Update] the update expression
- **@raise** [Exception] if the table is not set

**Example**
```crystal
update = Cql::Update.new(schema)
  .table(:users)
  .set(name: "John", age: 30)
  .where { |w| w.id == 1 }
  .commit

=> {"UPDATE users SET name = $1, age = $2 WHERE id = $3", ["John", 30, 1]}
```




### def commit

Executes the update query and returns the result.
- **@return** [DB::Result] the result of the query

**Example**
```crystal
update = Cql::Update.new(schema)
  .table(:users)
  .set(name: "John", age: 30)
  .where { |w| w.id == 1 }
  .commit

=> {"UPDATE users SET name = $1, age = $2 WHERE id = $3", ["John", 30, 1]}
```




### def set`(setters : Hash(Symbol, DB::Any))`

Sets the column values to update using a hash.
- **@param** setters [Hash(Symbol, DB::Any)] the column values to update
- **@return** [self] the current instance

**Example**
```crystal
update = Cql::Update.new(schema)
  .table(:users)
  .set(name: "John", age: 30)
  .where { |w| w.id == 1 }
  .commit

=> {"UPDATE users SET name = $1, age = $2 WHERE id = $3", ["John", 30, 1]}
```




### def set

Sets the column values to update using keyword arguments.
- **@param** fields [Hash(Symbol, DB::Any)] the column values to update
- **@return** [self] the current instance

**Example**
```crystal
update = Cql::Update.new(schema)
  .table(:users)
  .set(name: "John", age: 30)
  .where { |w| w.id == 1 }
  .commit

=> {"UPDATE users SET name = $1, age = $2 WHERE id = $3", ["John", 30, 1]}
```




### def table`(table : Symbol)`

Sets the table to update.
- **@param** table [Symbol] the name of the table
- **@return** [self] the current instance
- **@raise** [Exception] if the table does not exist

**Example**
```crystal
update = Cql::Update.new(schema)
  .table(:users)
  .set(name: "John", age: 30)
  .where { |w| w.id == 1 }
  .commit

=> {"UPDATE users SET name = $1, age = $2 WHERE id = $3", ["John", 30, 1]}
```




### def to_sql`(gen = @schema.gen)`

Generates the SQL query and parameters.
- **@param** gen [Expression::Generator] the generator to use
- **@return** [{String, Array(DB::Any)}] the query and parameters

**Example**
```crystal
update = Cql::Update.new(schema)
  .table(:users)
  .set(name: "John", age: 30)
  .where { |w| w.id == 1 }
  .to_sql

=> {"UPDATE users SET name = $1, age = $2 WHERE id = $3", ["John", 30, 1]}
```




### def where

Sets the WHERE clause using a block.
- **@block**  w [Expression::FilterBuilder] the filter builder
- **@return** [self] the current instance
- **@raise** [Exception] if the block is not provided
- **@raise** [Exception] if the block does not return an expression

**Example**
```crystal
update = Cql::Update.new(schema)
  .table(:users)
  .set(name: "John", age: 30)
  .where { |w| w.id == 1 }
  .commit

=> {"UPDATE users SET name = $1, age = $2 WHERE id = $3", ["John", 30, 1]}
```




### def where`(attr : Hash(Symbol, DB::Any))`

Sets the columns to return after the update.
- **@param** columns [Array(Symbol)] the columns to return
- **@return** [self] the current instance
- **@raise** [Exception] if the column does not exist
- **@raise** [Exception] if the column is not part of the table

**Example**

```crystal
update = Cql::Update.new(schema)
  .table(:users)
  .set(name: "John", age: 30)
  .where { |w| w.id == 1 }
  .back(:name, :age)
  .commit
```




### def where

Sets the WHERE clause using keyword arguments.
- **@param** fields [Hash(Symbol, DB::Any)] the conditions
- **@return** [self] the current instance
- **@raise** [Exception] if the column does not exist
- **@raise** [Exception] if the value is invalid

**Example**
```crystal
update = Cql::Update.new(schema)
  .table(:users)
  .set(name: "John", age: 30)
  .where(id: 1)
  .commit

=> {"UPDATE users SET name = $1, age = $2 WHERE id = $3", ["John", 30, 1]}
```



:::