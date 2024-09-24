# class CQL::Repository(T, Pk)

`Reference` < `Object`

The `CQL::Repository` class provides a high-level interface for interacting with a specific table in the database. It includes methods for querying, creating, updating, deleting records, as well as pagination and counting.

## Example: Creating a Repository

```crystal
class UserRepository < CQL::Repository(User)
  def initialize(@schema : Schema, @table : Symbol)
  end
end

user_repo = UserRepository.new(schema, :users)
user_repo.all
user_repo.find(1)
```

## Methods

### def all

Fetches all records from the table.

* **@return** \[Array(T)] The list of records.

**Example**:

```crystal
user_repo.all
```

### def find(id : Pk)

Finds a record by primary key.

* **@param** id \[Pk] The primary key value.
* **@return** \[T | Nil] The record if found, or `nil` otherwise.

**Example**:

```crystal
user_repo.find(1)
```

### def create(attrs : Hash(Symbol, DB::Any))

Creates a new record with the specified attributes.

* **@param** attrs \[Hash(Symbol, DB::Any)] The attributes of the record.
* **@return** \[PrimaryKey] The ID of the created record.

**Example**:

```crystal
user_repo.create(name: "Alice", email: " [email protected]")
```

### def update(id : Pk, attrs : Hash(Symbol, DB::Any))

Updates a record by its ID with the given attributes.

* **@param** id \[Pk] The primary key value of the record.
* **@param** attrs \[Hash(Symbol, DB::Any)] The updated attributes.
* **@return** \[Nil]

**Example**:

```crystal
user_repo.update(1, name: "Alice", active: true)
```

### def delete(id : Pk)

Deletes a record by its primary key.

* **@param** id \[Pk] The primary key value of the record.
* **@return** \[Nil]

**Example**:

```crystal
user_repo.delete(1)
```

### def count

Counts all records in the table.

* **@return** \[Int64] The number of records.

**Example**:

```crystal
user_repo.count
```

### def page(page\_number : Int32, per\_page = 10)

Fetches a paginated set of records.

* **@param** page\_number \[Int32] The page number to fetch.
* **@param** per\_page \[Int32] The number of records per page.
* **@return** \[Array(T)] The records for the requested page.

**Example**:

```crystal
user_repo.page(1, 10)
```
