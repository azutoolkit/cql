# Repository Pattern

The Repository pattern is a design pattern that mediates between the domain and data mapping layers using a collection-like interface for accessing domain objects. It centralizes data access logic, promoting a cleaner separation of concerns and making the application easier to test and maintain.

In **CQL (Crystal Query Language)**, while the Active Record pattern is a prominent feature, CQL's design is flexible enough to support the Repository pattern. This allows developers to abstract the underlying data persistence mechanisms further and work with domain objects in a more decoupled manner.

## Key Concepts of the Repository Pattern

1.  **Abstraction of Data Access**: The repository provides an abstraction layer over data storage. Consumers of the repository work with domain objects and are unaware of how those objects are persisted or retrieved.
2.  **Collection-Like Interface**: Repositories often expose methods that resemble collection operations, such as `add`, `remove`, `find`, `all`, etc.
3.  **Centralized Query Logic**: Queries related to a specific aggregate root or entity are encapsulated within its repository.
4.  **Decoupling**: It decouples the domain model from the data access concerns, improving testability and maintainability.
5.  **Unit of Work (Optional but Common)**: Repositories are often used in conjunction with a Unit of Work pattern to manage transactions and track changes to objects.

## Implementing the Repository Pattern with CQL

CQL provides a generic `CQL::Repository(T, Pk)` class that can be used as a base for creating specific repositories for your domain entities.

### 1. Define a Model (Entity)

First, you need a model (often a plain Crystal struct or class) that represents your domain entity. Unlike Active Record models, these entities typically don't include persistence logic themselves.

```crystal
# Example: A simple User entity
struct User
  property id : Int32?
  property name : String
  property email : String

  def initialize(@name : String, @email : String, @id : Int32? = nil)
  end
end
```

### 2. Create a Specific Repository

You create a repository for your entity by inheriting from `CQL::Repository(T, Pk)`, where `T` is your entity type and `Pk` is the type of its primary key.

```crystal
require "cql"

# Define your schema (database connection)
MySchema = CQL::Schema.define(
  :my_app_db,
  adapter: CQL::Adapter::Postgres, # or any other supported adapter
  uri: ENV["DATABASE_URL"]? || "postgres://localhost:5432/my_app_dev"
)

# Define the User entity (as above)
struct User
  property id : Int32?
  property name : String
  property email : String

  def initialize(@name : String, @email : String, @id : Int32? = nil)
  end

  # Constructor to map from a Hash, often useful with database results
  def self.new(attrs : Hash(Symbol, DB::Any))
    new(
      name: attrs[:name].as(String),
      email: attrs[:email].as(String),
      id: attrs[:id]?.as?(Int32)
    )
  end
end

# UserRepository inheriting from CQL::Repository
class UserRepository < CQL::Repository(User, Int32)
  # The constructor takes the schema instance and the table name
  def initialize(schema : CQL::Schema = MySchema, table_name : Symbol = :users)
    super(schema, table_name)
  end

  # You can add custom query methods here
  def find_active_users
    query.where { active == true }.all(User)
  end

  def find_by_email_domain(domain : String)
    query.where { email.like("%@#{domain}") }.all(User)
  end
end
```

**Explanation:**

- `UserRepository < CQL::Repository(User, Int32)`: Defines a repository for `User` entities where the primary key is `Int32`.
- `initialize(schema : CQL::Schema = MySchema, table_name : Symbol = :users)`: The constructor expects a `CQL::Schema` instance and the symbol representing the database table name (e.g., `:users`).
- `super(schema, table_name)`: Calls the constructor of the base `CQL::Repository` class.
- `find_active_users`, `find_by_email_domain`: Custom methods that encapsulate specific query logic using CQL's query builder (`query.where(...)`). The `query` method is provided by the base `CQL::Repository`.

### 3. Using the Repository

Once defined, you can use the repository to interact with your data:

```crystal
# Initialize the repository
user_repo = UserRepository.new

# Create a new user
# The `create` method in the base Repository expects a Hash of attributes
new_user_id = user_repo.create({name: "Alice Wonderland", email: "alice@example.com"})
puts "Created user with ID: #{new_user_id}"

# Find a user by ID
alice = user_repo.find(new_user_id.as(Int32))
if alice
  puts "Found user: #{alice.name}"
else
  puts "User not found."
end

# Fetch all users
all_users = user_repo.all
puts "All users:"
all_users.each do |user|
  puts "- #{user.name} (#{user.email})"
end

# Update a user
if alice
  user_repo.update(alice.id.not_nil!, {email: "alice.wonderland@newdomain.com"})
  updated_alice = user_repo.find(alice.id.not_nil!)
  puts "Updated email: #{updated_alice.try &.email}"
end

# Use custom repository methods
active_users = user_repo.find_active_users # Assuming an 'active' column and logic
puts "Active users: #{active_users.size}"

# Delete a user
if alice
  user_repo.delete(alice.id.not_nil!)
  puts "Deleted user #{alice.name}"
end
```

## Methods Provided by `CQL::Repository(T, Pk)`

The base `CQL::Repository` class provides several convenient methods for common data operations:

- **`query`**: Returns a new `CQL::Query` instance scoped to the repository's table.
- **`insert`**: Returns a new `CQL::Insert` instance scoped to the repository's table.
- **`update`**: Returns a new `CQL::Update` instance scoped to the repository's table.
- **`delete`**: Returns a new `CQL::Delete` instance scoped to the repository's table.
- **`build(attrs : Hash(Symbol, DB::Any)) : T`**: Instantiates a new entity `T` with the given attributes (does not persist).
- **`all : Array(T)`**: Fetches all records.
- **`find(id : Pk) : T?`**: Finds a record by its primary key, returns `nil` if not found.
- **`find!(id : Pk) : T`**: Finds a record by its primary key, raises `DB::NoResultsError` if not found.
- **`find_by(**fields) : T?`\*\*: Finds the first record matching the given field-value pairs.
- **`find_all_by(**fields) : Array(T)`\*\*: Finds all records matching the given field-value pairs.
- **`create(attrs : Hash(Symbol, DB::Any)) : Pk`**: Creates a new record with the given attributes and returns its primary key.
- **`create(**fields) : Pk`\*\*: Creates a new record with the given attributes (using named arguments) and returns its primary key.
- **`update(id : Pk, attrs : Hash(Symbol, DB::Any))`**: Updates the record with the given `id` using the provided attributes.
- **`update(id : Pk, **fields)`**: Updates the record with the given `id` using the provided attributes (named arguments).
- **`update_by(where_attrs : Hash(Symbol, DB::Any), update_attrs : Hash(Symbol, DB::Any))`**: Updates records matching `where_attrs` with `update_attrs`.
- **`update_all(attrs : Hash(Symbol, DB::Any))`**: Updates all records in the table with the given attributes.
- **`delete(id : Pk)`**: Deletes the record with the given primary key.
- **`delete_by(**fields)`\*\*: Deletes records matching the given field-value pairs.
- **`delete_all`**: Deletes all records in the table.
- **`count : Int64`**: Returns the total number of records in the table.
- **`exists?(**fields) : Bool`\*\*: Checks if any records exist matching the given field-value pairs.

## Advantages of Using the Repository Pattern with CQL

- **Improved Testability**: You can easily mock repositories in your tests, isolating your domain logic from the database.
- **Centralized Data Access Logic**: Keeps data access concerns separate from your domain entities and application services.
- **Flexibility**: While `CQL::Repository` provides a good starting point, you can customize it or even write your own repository implementations if needed, without altering your domain models significantly.
- **Clearer Intent**: Queries are named and reside within the repository, making their purpose more explicit.

## When to Use the Repository Pattern

- In larger applications where a clear separation between domain logic and data access is crucial.
- When you need to support multiple data sources or switch data storage technologies with minimal impact on the domain layer.
- When your querying logic becomes complex and you want to encapsulate it.
- To improve the testability of your application by allowing easier mocking of data access.

While Active Record can be simpler for straightforward CRUD operations, the Repository pattern offers more structure and decoupling for complex applications, and CQL provides the tools to implement it effectively.
