---
title: "Cql::Repository(T, Pk)"
---

::: v-pre
# class Cql::Repository(T, Pk)
`Reference` < `Object`

A repository for a specific table
This class provides a high-level interface for interacting with a table
It provides methods for querying, creating, updating, and deleting records
It also provides methods for pagination and counting records

**Example** Creating a new repository

```crystal
class UserRepository < Cql::Repository(User)
 def initialize(@schema : Schema, @table : Symbol)
end

user_repo = UserRepository.new(schema, :users)
user_repo.all
user_repo.find(1)
```
::: details Table of Contents
[[toc]]
:::



## Constructors


### def new`(schema : Schema, table : Symbol)`

Initialize the repository with a schema and table name

- **@param** schema [Schema] The schema to use
- **@param** table [Symbol] The name of the table
- **@return** [Repository] The repository object

**Example** Creating a new repository

```crystal
class UserRepository < Cql::Repository(User)
end

user_repo = UserRepository.new(schema, :users
```



## Instance Methods


### def all

Fetch all records of type T
- **@return** [Array(T)] The records

**Example** Fetching all records

```crystal
user_repo.all
```




### def build`(attrs : Hash(Symbol, DB::Any))`

Build a new object of type T with the given attributes
- **@param** attrs [Hash(Symbol, DB::Any)] The attributes to use
- **@return** [T] The new object

**Example** Building a new user object

```crystal
user_repo.build(name: "Alice", email: " [email protected]")
```




### def count

Count all records in the table
- **@return** [Int64] The number of records

**Example** Counting all records

```crystal
user_repo.count
```




### def create`(attrs : Hash(Symbol, DB::Any))`

Create a new record with given attributes
- **@param** attrs [Hash(Symbol, DB::Any)] The attributes to use
- **@return** [PrimaryKey] The ID of the new record
**Example** Creating a new record
```crystal
user_repo.create(name: "Alice", email: " [email protected]")
```




### def create






### def delete`(id : Pk)`

Delete a record by ID
- **@param** id [PrimaryKey] The ID of the record

**Example** Deleting a record by ID

```crystal
user_repo.delete(1)
```




### def delete






### def delete_all

Delete all records in the table

**Example** Deleting all records

```crystal
user_repo.delete_all
```




### def delete_by

Delete records matching specific fields
- **@param** fields [Hash(Symbol, DB::Any)] The fields to match

**Example** Deleting records by email

```crystal
user_repo.delete_by(email: " [email protected]")
```




### def exists?

Check if records exist matching specific fields
- **@param** fields [Hash(Symbol, DB::Any)] The fields to match
- **@return** [Bool] True if records exist, false otherwise

**Example** Checking if a record exists by email

```crystal
user_repo.exists?(email: " [email protected]")
```




### def find`(id : Pk)`

Find a record by ID, return nil if not found
- **@param** id [PrimaryKey] The ID of the record
- **@return** [T?] The record, or nil if not found

**Example** Fetching a record by ID

```crystal
user_repo.find(1)
```




### def find!`(id : Pk)`

Find a record by ID, raise an error if not found
- **@param** id [PrimaryKey] The ID of the record
- **@return** [T] The record

**Example** Fetching a record by ID

```crystal
user_repo.find!(1)
```




### def find_all_by

Find all records matching specific fields
- **@param** fields [Hash(Symbol, DB::Any)] The fields to match
- **@return** [Array(T)] The records

**Example** Fetching all active users

```crystal
user_repo.find_all_by(active: true)
```




### def find_by

Find a record by specific fields
- **@param** fields [Hash(Symbol, DB::Any)] The fields to match
- **@return** [T?] The record, or nil if not found

**Example** Fetching a record by email

```crystal
user_repo.find_by(email: " [email protected]")
```




### def first

Fetch the first record in the table
- **@return** [T?] The first record, or nil if the table is empty

**Example** Fetching the first record

```crystal
user_repo.first
```




### def insert






### def last

Fetch the last record in the table
- **@return** [T?] The last record, or nil if the table is empty

**Example** Fetching the last record

```crystal
user_repo.last
```




### def page`(page_number, per_page = 10)`

Paginate results based on page number and items per page
- **@param** page_number [Int32] The page number to fetch
- **@param** per_page [Int32] The number of items per page
- **@return** [Array(T)] The records for the page

**Example** Paginating results

```crystal
user_repo.page(1, 10)
```




### def per_page`(per_page)`

Limit the number of results per page
- **@param** per_page [Int32] The number of items per page
- **@return** [Array(T)] The records for the page

**Example** Limiting results per page

```crystal
user_repo.per_page(10)
```




### def query






### def update`(id : Pk, attrs : Hash(Symbol, DB::Any))`

Update a record by ID with given attributes
- **@param** id [PrimaryKey] The ID of the record
- **@param** attrs [Hash(Symbol, DB::Any)] The attributes to update

**Example** Updating a record by ID

```crystal
user_repo.update(1, active: true)
```




### def update`(id : Pk, **fields)`

Update a record by ID with given fields
- **@param** id [PrimaryKey] The ID of the record
- **@param** fields [Hash(Symbol, DB::Any)] The fields to update

**Example** Updating a record by ID

```crystal
user_repo.update(1, active: true)
```




### def update






### def update_all`(attrs : Hash(Symbol, DB::Any))`

Update all records with given attributes
- **@param** attrs [Hash(Symbol, DB::Any)] The attributes to update

**Example** Updating all records

```crystal
user_repo.update_all(active: true)
```




### def update_by`(where_attrs : Hash(Symbol, DB::Any), update_attrs : Hash(Symbol, DB::Any))`

Update records matching where attributes with update attributes
- **@param** where_attrs [Hash(Symbol, DB::Any)] The attributes to match
- **@param** update_attrs [Hash(Symbol, DB::Any)] The attributes to update

**Example** Updating records by email

```crystal
user_repo.update_by(email: " [email protected]", active: true)
```



:::