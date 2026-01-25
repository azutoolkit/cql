# Repository Pattern

The Repository pattern provides an alternative to Active Record by separating data persistence from domain objects. While CQL primarily uses Active Record, you can implement Repository patterns for specific use cases.

## What is the Repository Pattern?

In the Repository pattern:
- Domain objects (entities) hold data and business logic
- Repositories handle all database operations
- The domain layer doesn't know about persistence

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Domain     │────>│  Repository  │────>│   Database   │
│   Objects    │<────│              │<────│              │
└──────────────┘     └──────────────┘     └──────────────┘
```

## Why Use Repository Pattern?

### Separation of Concerns

Domain objects focus on business logic, not database operations:

```crystal
# Entity - no database knowledge
struct User
  property id : Int64?
  property name : String
  property email : String

  def full_name
    name.split.map(&.capitalize).join(" ")
  end
end

# Repository - handles persistence
class UserRepository
  def find(id : Int64) : User?
    # Database query
  end

  def save(user : User) : Bool
    # Insert or update
  end
end
```

### Testability

Easily mock repositories for testing:

```crystal
class MockUserRepository
  def find(id : Int64) : User?
    User.new("Test User", "test@example.com")
  end
end

# In tests
service = UserService.new(MockUserRepository.new)
```

### Flexibility

Switch data sources without changing domain logic:

```crystal
abstract class UserRepository
  abstract def find(id : Int64) : User?
  abstract def save(user : User) : Bool
end

class PostgresUserRepository < UserRepository
  # PostgreSQL implementation
end

class ApiUserRepository < UserRepository
  # REST API implementation
end
```

## Implementing Repository with CQL

### Step 1: Define Your Entity

```crystal
struct User
  property id : Int64?
  property name : String
  property email : String
  property created_at : Time?

  def initialize(@name : String, @email : String)
  end

  def valid? : Bool
    !name.empty? && email.includes?("@")
  end
end
```

### Step 2: Create a CQL Model (Internal)

```crystal
# This is internal to the repository
struct UserRecord
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :users

  property id : Int64?
  property name : String
  property email : String
  property created_at : Time?

  def initialize(@name : String, @email : String)
  end

  def to_entity : User
    user = User.new(@name, @email)
    user.id = @id
    user.created_at = @created_at
    user
  end

  def self.from_entity(user : User) : UserRecord
    record = new(user.name, user.email)
    record.id = user.id
    record
  end
end
```

### Step 3: Implement the Repository

```crystal
class UserRepository
  def find(id : Int64) : User?
    record = UserRecord.find(id)
    record.try(&.to_entity)
  end

  def find_by_email(email : String) : User?
    record = UserRecord.find_by(email: email)
    record.try(&.to_entity)
  end

  def all : Array(User)
    UserRecord.all.map(&.to_entity)
  end

  def save(user : User) : Bool
    record = UserRecord.from_entity(user)
    if record.save
      user.id = record.id
      true
    else
      false
    end
  end

  def delete(user : User) : Bool
    return false unless user.id
    record = UserRecord.find(user.id.not_nil!)
    record.try(&.delete!) || false
  end

  def active_users : Array(User)
    UserRecord.where(active: true).all.map(&.to_entity)
  end
end
```

### Step 4: Use the Repository

```crystal
repo = UserRepository.new

# Create
user = User.new("John", "john@example.com")
repo.save(user)

# Find
found = repo.find(user.id.not_nil!)

# Query
active = repo.active_users

# Delete
repo.delete(user)
```

## When to Use Repository Pattern

### Good Use Cases

1. **Complex domain logic** - Keep business rules separate from persistence
2. **Multiple data sources** - Same domain, different storage
3. **Heavy testing** - Easy to mock repositories
4. **Large teams** - Clear boundaries between concerns

### Not Ideal For

1. **Simple CRUD apps** - Overkill for basic operations
2. **Rapid prototyping** - Slows initial development
3. **Small projects** - Adds unnecessary complexity

## Comparison: Active Record vs Repository

```crystal
# Active Record
user = User.find(1)
user.name = "Updated"
user.save

# Repository
user = user_repo.find(1)
user.name = "Updated"
user_repo.save(user)
```

The difference is subtle in simple cases but significant for complex domains.

## Hybrid Approach

You can mix both patterns:

```crystal
# Simple entities use Active Record directly
post = Post.find(1)
post.title = "Updated"
post.save

# Complex domain uses Repository
order = order_repo.find(1)
order.add_item(product, quantity)
order_repo.save(order)
```

This gives you the best of both worlds: simplicity for CRUD and separation for complex logic.
