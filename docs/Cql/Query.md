---
title: "Cql::Query"
---

::: v-pre
# class Cql::Query
`Reference` < `Object`

The `Query` class is responsible for building SQL queries in a structured manner.
It holds various components like selected columns, tables, conditions, and more.
It provides methods to execute the query and return results.

**Example** Creating a new query

```crystal
schema = Cql::Schema.new

Cql::Query.new(schema)
query.select(:name, :age).from(:users).where(name: "John").all(User)
=> [{"name" => "John", "age" => 30}]
```

**Example** Executing a query and iterating over results

```crystal
schema = Cql::Schema.new
query = Cql::Query.new(schema)
query.select(:name, :age).from(:users).where(name: "John").each(User) do |user|
  puts user.name
end

=> John
```
::: details Table of Contents
[[toc]]
:::



## Constructors


### def new`(schema : Schema)`

Initializes the `Query` object with the provided schema.
- **@param** schema [Schema] The schema object to use for the query
- **@return** [Query] The query object

**Example** Creating a new query
```crystal
schema = Cql::Schema.new
query = Cql::Query.new(schema)

=> #<Cql::Query:0x00007f8b1b0b3b00>
```



## Instance Methods


### def aggr_columns






### def all`(as as_kind)`

Executes the query and returns all records.
- **@param** as [Type] The type to cast the results to
- **@return** [Array(Type)] The results of the query

**Example**

```crystal
schema = Cql::Schema.new
query = Cql::Query.new(schema)
query.select(:name, :age).from(:users).all(User)

=> [<User:0x00007f8b1b0b3b00 @name="John", @age=30>, <User:0x00007f8b1b0b3b00 @name="Jane", @age=25>]
```




### def all!`(as as_kind)`

- **@param** as [Type] The type to cast the results to
- **@return** [Array(Type)] The results of the query

**Example**

```crystal
schema = Cql::Schema.new
query = Cql::Query.new(schema)
query.select(:name, :age).from(:users).all!(User)

=> [<User:0x00007f8b1b0b3b00 @name="John", @age=30>, <User:0x00007f8b1b0b3b00 @name="Jane", @age=25>]
```




### def avg`(column : Symbol)`

Adds an AVG aggregate function to the query.
- **@param** column [Symbol] The column to average
- **@return** [Query] The query object

**Example**

```crystal
query.avg(:rating)
=> "SELECT AVG(rating) FROM users"
```




### def build

Builds the final query expression.
- **@return** [Expression::Query] The query expression

**Example**

```crystal
query.build
=> #<Expression::Query:0x00007f8b1b0b3b00>
```




### def columns






### def count`(column : Symbol = :*)`

Adds a COUNT aggregate function to the query.
- **@param** column [Symbol] The column to count
- **@return** [Query] The query object

**Example**

```crystal
query.count(:id)
=> "SELECT COUNT(id) FROM users"
```




### def distinct

Sets the distinct flag to true.
- **@return** [Query] The query object

**Example**
```crystal
query.from(:users).distinct
=> "SELECT DISTINCT * FROM users"
```




### def distinct?






### def each`(as as_kind, &)`

Iterates over each result and yields it to the provided block.
Example:
```crystal
query.each(User) do |user|
  puts user.name
end

=> John
```




### def first`(as as_kind)`

Executes the query and returns the first record.
- **@param** as [Type] The type to cast the result to
- **@return** [Type] The first result of the query

**Example**

```crystal
schema = Cql::Schema.new
query = Cql::Query.new(schema)
query.select(:name, :age).from(:users).first(User)

=> <User:0x00007f8b1b0b3b00 @name="John", @age=30>
```




### def first!`(as as_kind)`

- **@param** as [Type] The type to cast the result to
- **@return** [Type] The first result of the query

**Example**

```crystal
schema = Cql::Schema.new
query = Cql::Query.new(schema)
query.select(:name, :age).from(:users).first!(User)

=> <User:0x00007f8b1b0b3b00 @name="John", @age=30>
```




### def from`(*tbls : Symbol)`

Specifies the tables to select from.
- **@param** tbls [Symbol*] The tables to select from
- **@return** [Query] The query object

**Example**

```crystal
query.from(:users, :orders)
=> "SELECT * FROM users, orders"
```




### def get`(as as_kind)`

Executes the query and returns a scalar value.
- **@param** as [Type] The type to cast the result to
- **@return** [Type] The scalar result of the query
Example: `query.get(Int64)`
```crystal
schema = Cql::Schema.new
query = Cql::Query.new(schema)
query.select(:count).from(:users).get(Int64)

=> 10
```




### def group`(*columns)`

Specifies the columns to group by.
- **@param** columns [Symbol*] The columns to group by
- **@return** [Query] The query object

**Example**

```crystal
query.from(:products).group(:category)
=> "SELECT * FROM products GROUP BY category"
```




### def group_by






### def having






### def having

Adds a HAVING condition to the grouped results.
- **@param** block [Block] The block to evaluate the having condition
- **@return** [Query] The query object

**Example**

```crystal
query.from(:products).group(:category).having { avg(:price) > 100 }
=> "SELECT * FROM products GROUP BY category HAVING AVG(price) > 100"
```




### def inner`(table : Symbol, on : Hash(Cql::BaseColumn, Cql::BaseColumn | DB::Any))`

Adds an INNER JOIN to the query.
- **@param** table [Symbol] The table to join
- **@param** on [Hash(Cql::BaseColumn, Cql::BaseColumn | DB::Any)] The join condition
- **@return** [Query] The query object

**Example**

```crystal
query.inner(:orders, on: { users.id => orders.user_id })
=> "SELECT * FROM users INNER JOIN orders ON users.id = orders.user_id"
```




### def inner`(table : Symbol, &)`

Adds an INNER JOIN to the query.
- **@param** table [Symbol] The table to join
- **@yield** [FilterBuilder] The block to build the conditions
- **@return** [Query] The query object
- **@raise** [Exception] if the block is not provided
- **@raise** [Exception] if the block does not return an expression
- **@raise** [Exception] if the column does not exist

**Example**

```crystal
query.inner(:orders) { |w| w.users.id == orders.user_id }
=> "SELECT * FROM users INNER JOIN orders ON users.id = orders.user_id"
```




### def joins






### def left`(table : Symbol, on : Hash(Cql::BaseColumn, Cql::BaseColumn | DB::Any))`

Adds a LEFT JOIN to the query.
- **@param** table [Symbol] The table to join
- **@param** on [Hash(Cql::BaseColumn, Cql::BaseColumn | DB::Any)] The join condition

**Example**

```crystal
query.left(:orders, on: { users.id => orders.user_id })
=> "SELECT * FROM users LEFT JOIN orders ON users.id = orders.user_id"
```




### def left`(table : Symbol, &)`

Adds a LEFT JOIN to the query using a block.
- **@param** table [Symbol] The table to join
- **@yield** [FilterBuilder] The block to build the conditions
- **@return** [Query] The query object
- **@raise** [Exception] if the block is not provided
- **@raise** [Exception] if the block does not return an expression
- **@raise** [Exception] if the column does not exist

**Example**

```crystal
query.left(:orders) { |w| w.users.id == orders.user_id }
=> "SELECT * FROM users LEFT JOIN orders ON users.id = orders.user_id"
```




### def limit`(value : Int32)`

Sets the limit for the number of records to return.
- **@param** value [Int32] The limit value
- **@return** [Query] The query object

**Example**

```crystal
query.from(:users).limit(10)
=> "SELECT * FROM users LIMIT 10"
```




### def limit






### def max`(column : Symbol)`

Adds a MAX aggregate function to the query.
- **@param** column [Symbol] The column to find the maximum value of
- **@return** [Query] The query object

**Example**

```crystal
query.from(:users).max(:price)
=> "SELECT MAX(price) FROM users"
```




### def min`(column : Symbol)`

Adds a MIN aggregate function to the query.
- **@param** column [Symbol] The column to find the minimum value of
- **@return** [Query] The query object

**Example**

```crystal
query.min(:price)
=> "SELECT MIN(price) FROM users"
```




### def offset`(value : Int32)`

Sets the offset for the query.
- **@param** value [Int32] The offset value
- **@return** [Query] The query object

**Example**

```crystal
query.from(:users).limit(10).offset(20)
=> "SELECT * FROM users LIMIT 10 OFFSET 20"
```




### def offset






### def order`(*fields)`

Specifies the columns to order by.
- **@param** fields [Symbol*] The columns to order by
- **@return** [Query] The query object

**Example**

```crystal
query.order(:name, :age)
=> "SELECT * FROM users ORDER BY name, age"
```




### def order

Specifies the columns to order by.
- **@param** fields [Hash(Symbol, Symbol)] The columns to order by and their direction
- **@return** [Query] The query object

**Example**

```crystal
query.order(name: :asc, age: :desc)
=> "SELECT * FROM users ORDER BY name ASC, age DESC"
```




### def order_by






### def right`(table : Symbol, on : Hash(Cql::BaseColumn, Cql::BaseColumn | DB::Any))`

Adds a RIGHT JOIN to the query.
- **@param** table [Symbol] The table to join
- **@param** on [Hash(Cql::BaseColumn, Cql::BaseColumn | DB::Any)] The join condition
- **@return** [Query] The query object

**Example**

```crystal
query.right(:orders, on: { users.id => orders.user_id })
=> "SELECT * FROM users RIGHT JOIN orders ON users.id = orders.user_id"
```




### def right`(table : Symbol, &)`

Adds a RIGHT JOIN to the query using a block.
- **@param** table [Symbol] The table to join
- **@yield** [FilterBuilder] The block to build the conditions
- **@return** [Query] The query object
- **@raise** [Exception] if the block is not provided
- **@raise** [Exception] if the block does not return an expression
- **@raise** [Exception] if the column does not exist
- **@raise** [Exception] if the value is invalid

**Example**

```crystal
query.right(:orders) { |w| w.users.id == orders.user_id }
=> "SELECT * FROM users RIGHT JOIN orders ON users.id = orders.user_id"
```




### def select`(*columns : Symbol)`

Specifies the columns to select.
- **@param** columns [Symbol*] The columns to select
- **@return** [Query] The query object

**Example**

```crystal
query.select(:name, :age)
=> "SELECT name, age FROM users"
```




### def select

Specifies the columns to select.
- **@param** columns [Array(Symbol)] The columns to select
- **@return** [Query] The query object


**Example**
```crystal
query.from(:users, :address).select(users: [:name, :age], address: [:city, :state])
=> "SELECT users.name, users.age, address.city, address.state FROM users, address"
```




### def sum`(column : Symbol)`

Adds a SUM aggregate function to the query.
- **@param** column [Symbol] The column to sum
- **@return** [Query] The query object

**Example**

```crystal
query.sum(:total_amount)
=> "SELECT SUM(total_amount) FROM users"
```




### def tables






### def to_sql`(gen = @schema.gen)`

Converts the query into an SQL string and its corresponding parameters.
- **@param** gen [Generator] The generator to use for converting the query
- **@return** [Tuple(String, Array(DB::Any))] The SQL query and its parameters

**Example**

```crystal
query.to_sql
=> {"SELECT * FROM users WHERE name = ? AND age = ?", ["John", 30]}
```




### def where`(hash : Hash(Symbol, DB::Any))`

Adds a WHERE condition with a hash of column-value pairs.
- **@param** hash [Hash(Symbol, DB::Any)] The hash of column-value pairs
- **@return** [Query] The query object

**Example**

```crystal
query.from(:users).where(name: "John", age: 30)
=> "SELECT * FROM users WHERE name = 'John' AND age = 30"
```




### def where






### def where

Adds a WHERE condition with a block.
- **@fields** [FilterBuilder] The block to build the conditions
- **@return** [Query] The query object
- **@raise** [Exception] if the column does not exist
- **@raise** [Exception] if the value is invalid
- **@raise** [Exception] if the value is not of the correct type

**Example**

```crystal
query.from(:users).where(name: "John")
=> "SELECT * FROM users WHERE name = 'John'"
```




### def where

Adds WHERE conditions using a block.
- **@yield** [FilterBuilder] The block to build the conditions
- **@return** [Query] The query object
- **@raise** [Exception] if the block is not provided
- **@raise** [Exception] if the block does not return an expression
- **@raise** [Exception] if the column does not exist

**Example**

```crystal
query.from(:users).where { |w| w.name == "John" }
=> "SELECT * FROM users WHERE name = 'John'"
```


## Macros


### macro method_missing`(call)`




:::