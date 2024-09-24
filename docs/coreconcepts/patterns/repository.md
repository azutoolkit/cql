# Core Concept: Repository Pattern in CQL

The **Repository Pattern** is a design pattern that provides an abstraction layer between the data access logic and the business logic in an application. In CQL, the `Cql::Repository(T, Pk)` class implements the repository pattern, allowing you to interact with your database models in a clean and maintainable way.

## Benefits of the Repository Pattern

- **Separation of Concerns**: It abstracts the database operations, so business logic remains unaware of how data is fetched or stored.
- **Maintainability**: With a repository, changes to the underlying database structure can be made without affecting business logic.
- **Testability**: It becomes easier to write unit tests for your business logic because the repository can be mocked or stubbed.

## Repository Basics in CQL

In CQL, a `Repository` is tied to a specific table in the database. It provides an interface for CRUD (Create, Read, Update, Delete) operations, along with support for more advanced functionalities like pagination and counting records.

### Example: Defining a Repository

To define a repository, create a class that inherits from `Cql::Repository(T, Pk)` where:

- `T` is the type of the model or struct that represents the table.
- `Pk` is the primary key type of the table (e.g., `Int64`, `UUID`).

```crystal
class UserRepository < Cql::Repository(User, Int64)
  def initialize(@schema : Cql::Schema, @table : Symbol)
  end
end
```

This creates a repository for the `users` table with a primary key of type `Int64`.

### CRUD Operations with a Repository

Once a repository is defined, you can perform common database operations using its built-in methods.

#### Create a New Record

```crystal
user_repo = UserRepository.new(schema, :users)
user_repo.create(name: "Alice", email: " [email protected]")
```

#### Fetch All Records

```crystal
users = user_repo.all
```

#### Find a Record by Primary Key

```crystal
user = user_repo.find(1)
```

#### Update a Record

```crystal
user_repo.update(1, name: "Alice Updated")
```

#### Delete a Record

```crystal
user_repo.delete(1)
```

## Advanced Features

### Pagination

The repository provides built-in support for paginated queries:

```crystal
page_1_users = user_repo.page(1, per_page: 10)
```

### Counting Records

To count all records in a table, use the `count` method:

```crystal
user_count = user_repo.count
```

### Query Customization

You can extend the repository to support custom queries by adding methods:

```crystal
class UserRepository < Cql::Repository(User, Int64)
  def find_by_email(email : String)
    query.from(:users).where(email: email).first!(as: User)
  end
end
```

This allows you to keep the database logic encapsulated within the repository class, maintaining clean separation between data access and application logic.

## When to Use the Repository Pattern

- **Large Applications**: For applications with complex data access logic, the repository pattern helps organize the codebase.
- **Testing**: By abstracting the database access, the repository pattern makes it easier to mock or stub database operations in tests.
- **Scalability**: As your application grows, repositories allow you to manage data access logic more effectively by keeping it separate from business logic.
