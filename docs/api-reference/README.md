---
description: >-
  Complete API reference for CQL - Active Record, Query Builder, Validations, Callbacks, and Relations.
---

# API Reference

This section provides comprehensive API documentation for all CQL components. Each reference guide contains detailed method signatures, parameters, return types, and usage examples.

## API Documentation Sections

### [Active Record API](./active-record-api.md)

Complete reference for CQL's Active Record implementation:

- Model definition and configuration
- CRUD operations (Create, Read, Update, Delete)
- Query interface methods
- Persistence and lifecycle methods
- Instance and class methods

### [Query Builder API](./query-builder-api.md)

Comprehensive reference for the CQL Query Builder:

- Query construction methods
- Filtering and condition building
- Joins and table operations
- Aggregation functions
- Execution methods
- Query optimization features

### [Validation API](./validation-api.md)

Complete reference for model validations:

- Built-in validators
- Custom validation methods
- Validation contexts
- Error handling and messages
- Validation lifecycle

### [Callback API](./callback-api.md)

Reference for model lifecycle callbacks:

- Available callback types
- Callback registration methods
- Callback execution order
- Conditional callbacks
- Callback chaining

### [Relation API](./relation-api.md)

Reference for model relationships:

- Association types (belongs_to, has_one, has_many, many_to_many)
- Association configuration options
- Query methods for associations
- Eager loading and N+1 prevention
- Association lifecycle methods

## API Organization

Each API reference follows a consistent structure:

### Method Documentation Format

````crystal
# Method name and signature
def method_name(param1 : Type1, param2 : Type2 = default) : ReturnType

# Description
# Brief description of what the method does and when to use it.

# Parameters
# - **param1** [Type1] Description of the parameter
# - **param2** [Type2] Description of the parameter (optional)

# Returns
# [ReturnType] Description of the return value

# Raises
# [ExceptionType] When and why this exception is raised

# Example
# ```crystal
# # Usage example
# result = object.method_name(value1, value2)
# ```
````

### Class/Module Documentation Format

````crystal
# Class/Module name
class ClassName < ParentClass
  # Description
  # Comprehensive description of the class/module purpose and functionality.

  # Features
  # - Key feature 1
  # - Key feature 2
  # - Key feature 3

  # Example
  # ```crystal
  # # Basic usage example
  # instance = ClassName.new
  # ```
end
````

## Type Definitions

Throughout the API documentation, you'll encounter these common types:

### CQL Types

- `CQL::Query` - The main query builder class
- `CQL::Schema` - Database schema definition
- `CQL::Table` - Table definition
- `CQL::Column` - Column definition
- `CQL::ActiveRecord::Model(Pk)` - Active Record model base

### Crystal Standard Types

- `DB::Any` - Database value type
- `DB::Serializable` - Serialization interface
- `Time` - Date/time values
- `UUID` - Unique identifiers
- `ULID` - Universally unique lexicographically sortable identifiers

### Generic Types

- `T` - Generic type parameter for models
- `Pk` - Primary key type parameter
- `R` - Return type parameter

## Usage Patterns

### Active Record Pattern

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context AcmeDB, :users

  # Model definition...
end

# Usage
user = User.create!(name: "John", email: "john@example.com")
users = User.where(active: true).all
```

### Query Builder Pattern

```crystal
schema = CQL::Schema.new
query = CQL::Query.new(schema)

# Usage
users = query.select(:name, :email)
             .from(:users)
             .where(active: true)
             .all(User)
```

### Validation Pattern

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)

  validates :email, presence: true, format: /@/
  validates :age, numericality: {greater_than: 0, less_than: 120}
end
```

### Callback Pattern

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)

  before_save :normalize_email
  after_create :send_welcome_email

  private def normalize_email
    @email = @email.downcase
  end
end
```

### Relation Pattern

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)

  has_many :posts, Post, foreign_key: :user_id
  belongs_to :profile, Profile, foreign_key: :profile_id
end
```

## Error Handling

CQL uses a consistent error handling approach:

### Common Exceptions

- `CQL::Error` - Base exception for CQL errors
- `CQL::ValidationError` - Validation failures
- `CQL::RecordNotFound` - Record not found errors
- `CQL::QueryError` - Query construction errors

### Error Handling Pattern

```crystal
begin
  user = User.find!(123)
rescue CQL::RecordNotFound
  puts "User not found"
rescue CQL::ValidationError => ex
  puts "Validation failed: #{ex.message}"
rescue CQL::Error => ex
  puts "CQL error: #{ex.message}"
end
```

## Performance Considerations

### Query Optimization

- Use specific column selection instead of `*`
- Add appropriate indexes for frequently queried columns
- Use query caching for repeated operations
- Implement pagination for large result sets

### Memory Management

- Use `each` for large datasets instead of `all`
- Implement batch processing for bulk operations
- Clear query caches when appropriate
- Monitor connection pool usage

## Database Compatibility

CQL supports multiple database systems with optimized features:

### PostgreSQL

- Full feature support
- JSONB column types
- Advanced indexing options
- Native UUID support

### MySQL

- Comprehensive feature support
- JSON column types
- Spatial data types
- Full-text search

### SQLite

- Lightweight support
- Embedded database operations
- File-based storage
- Development and testing

## Contributing to Documentation

When adding new features to CQL, please ensure:

1. **Method Documentation**: All public methods are documented with examples
2. **Type Safety**: Parameter and return types are clearly specified
3. **Error Handling**: Document all possible exceptions
4. **Examples**: Provide practical usage examples
5. **Performance Notes**: Include performance considerations where relevant

## Getting Help

If you need help with specific API usage:

1. Check the relevant API reference section
2. Review the [Guides](../guides/README.md) for practical examples
3. Consult the [Troubleshooting](../troubleshooting.md) section
4. Review the [FAQs](../faqs.md) for common questions

The API reference provides the definitive source for all CQL functionality. Use it alongside the guides for the best development experience.
