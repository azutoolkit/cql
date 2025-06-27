# Architecture Overview

This guide provides a comprehensive overview of CQL's architecture, explaining how the different components work together to provide a powerful, type-safe ORM for Crystal applications.

## 🏗️ High-Level Architecture

CQL follows a layered architecture pattern that separates concerns and provides flexibility while maintaining performance:

```mermaid fullWidth="true"
graph TB
    A[Application Layer] --> B[Active Record Models]
    A --> C[Repository Pattern]
    B --> D[Query Builder]
    C --> D
    D --> E[Schema Layer]
    E --> F[Expression Builder]
    F --> G[SQL Generation]
    G --> H[Database Adapters]
    H --> I[(Database)]

    subgraph "CQL Core"
        D
        E
        F
        G
    end

    subgraph "Database Layer"
        H
        I
    end
```

## 🧩 Core Components

### 1. Schema Definition Layer

The schema layer is the foundation of CQL, providing type-safe database structure definition:

```crystal
# Schema defines the database structure
AcmeDB = CQL::Schema.define(
  :acme_db,
  "postgresql://localhost/myapp",
  CQL::Adapter::Postgres
) do
  table :users do
    primary :id, Int64
    column :name, String
    column :email, String
    timestamps
  end
end
```

**Key Responsibilities:**

- Database connection management
- Table and column definitions
- Index and constraint management
- Migration execution
- Transaction handling

### 2. Query Builder

The query builder provides a fluent interface for constructing SQL queries:

```crystal
# Fluent query interface
query = AcmeDB.query
  .from(:users)
  .where(active: true)
  .order(name: :asc)
  .limit(10)
```

**Features:**

- Type-safe query construction
- Method chaining
- Complex joins and subqueries
- Aggregate functions
- Raw SQL integration

### 3. Expression Builder

The expression builder translates Crystal expressions into SQL:

```crystal
# Crystal expressions become SQL
query.where { |q| q.users.age > 18 }
# Generates: WHERE users.age > ?
```

**Capabilities:**

- Filter builders for where clauses
- Having builders for aggregate conditions
- Type-safe comparisons
- Complex boolean logic
- Aggregate function support

### 4. Database Adapters

Adapters handle database-specific SQL generation and features:

```crystal
# Each adapter handles database-specific SQL
case adapter
when CQL::Adapter::Postgres
  "SELECT ... LIMIT $1 OFFSET $2"
when CQL::Adapter::MySql
  "SELECT ... LIMIT ? OFFSET ?"
when CQL::Adapter::SQLite
  "SELECT ... LIMIT ? OFFSET ?"
end
```

**Adapter Features:**

- Database-specific SQL dialects
- Connection pooling
- Transaction management
- Error handling
- Feature detection

## 🎭 Design Patterns

### Active Record Pattern

CQL implements the Active Record pattern where models represent database tables:

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)
  db_context AcmeDB, :users

  property id : Int64?
  property name : String
  property email : String

  # Active Record methods are automatically available
  # user.save!, user.update!, user.destroy!, etc.
end
```

**Pattern Flow:**

```mermaid fullWidth="true"
sequenceDiagram
    participant App as Application
    participant Model as User Model
    participant Schema as Schema Layer
    participant DB as Database

    App->>Model: user.save!
    Model->>Model: validate
    Model->>Schema: execute INSERT
    Schema->>DB: SQL query
    DB-->>Schema: result
    Schema-->>Model: record ID
    Model-->>App: saved user
```

### Repository Pattern

For applications that prefer separation of concerns:

```crystal
class UserRepository < CQL::Repository(User, Int64)
  def initialize
    super(AcmeDB, :users)
  end

  def find_active_users
    query.where(active: true).all(User)
  end

  def create_user(name : String, email : String)
    create(name: name, email: email)
  end
end
```

**Pattern Flow:**

```mermaid fullWidth="true"
sequenceDiagram
    participant App as Application
    participant Repo as Repository
    participant Query as Query Builder
    participant DB as Database

    App->>Repo: find_active_users
    Repo->>Query: where(active: true)
    Query->>DB: SELECT ... WHERE active = true
    DB-->>Query: result set
    Query-->>Repo: User objects
    Repo-->>App: User array
```

## 🔄 Data Flow Architecture

### Query Execution Flow

```mermaid fullWidth="true"
flowchart TD
    A[Method Call] --> B{Query Type}
    B -->|SELECT| C[Query Builder]
    B -->|INSERT| D[Insert Builder]
    B -->|UPDATE| E[Update Builder]
    B -->|DELETE| F[Delete Builder]

    C --> G[Expression Parser]
    D --> G
    E --> G
    F --> G

    G --> H[SQL Generator]
    H --> I{Database Type}
    I -->|PostgreSQL| J[Postgres Dialect]
    I -->|MySQL| K[MySQL Dialect]
    I -->|SQLite| L[SQLite Dialect]

    J --> M[Execute SQL]
    K --> M
    L --> M

    M --> N[Parse Results]
    N --> O[Return Objects]
```

### Model Lifecycle

```mermaid fullWidth="true"
sequenceDiagram
    participant Client
    participant User
    participant DB

    %% CREATE FLOW
    Client->>User: new
    Client->>User: save!
    User->>User: before_validation
    alt Validation fails
        User-->>Client: return false
    else Validation passes
        User->>User: after_validation
        User->>User: before_save
        User->>User: before_create
        User->>DB: INSERT
        alt SQL error
            DB-->>User: error
            User-->>Client: fail
        else Success
            DB-->>User: id assigned
            User->>User: after_create
            User->>User: after_save
            User-->>Client: persisted
        end
    end

    %% UPDATE FLOW
    Client->>User: find(id)
    Client->>User: update!
    User->>User: before_validation
    alt Validation fails
        User-->>Client: return false
    else Validation passes
        User->>User: after_validation
        User->>User: before_save
        User->>User: before_update
        User->>DB: UPDATE
        alt SQL error
            DB-->>User: error
            User-->>Client: fail
        else Success
            DB-->>User: update ok
            User->>User: after_update
            User->>User: after_save
            User-->>Client: persisted
        end
    end

    %% DESTROY FLOW
    Client->>User: destroy!
    User->>User: before_destroy
    User->>DB: DELETE
    alt SQL error
        DB-->>User: error
        User-->>Client: fail
    else Success
        DB-->>User: delete ok
        User->>User: after_destroy
        User-->>Client: destroyed
    end
```

## 🎯 Type Safety Architecture

### Compile-Time Type Checking

CQL leverages Crystal's macro system for compile-time type safety:

```crystal
# Macros generate type-safe methods
macro included
  include CQL::ActiveRecord::Validations
  include CQL::ActiveRecord::Queryable
  include CQL::ActiveRecord::Insertable
  include CQL::ActiveRecord::Updateable
  include CQL::ActiveRecord::Deleteable
  include CQL::ActiveRecord::Persistence
end
```

### Runtime Type Validation

```mermaid fullWidth="true"
graph LR
    A[Crystal Code] --> B[Macro Expansion]
    B --> C[Type Checking]
    C --> D[Compilation]
    D --> E[Runtime Execution]

    F[Database Schema] --> G[CQL Schema DSL]
    G --> H[Type Generation]
    H --> C
```

## 🚀 Performance Architecture

### Connection Management

```crystal
# Connection pooling strategy
class Schema
  private getter db : DB::Database
  private getter? active_connection : DB::Connection?

  def exec_query(&)
    if conn = @active_connection
      yield conn  # Use transaction connection
    else
      @db.using_connection do |conn|
        yield conn  # Use pooled connection
      end
    end
  end
end
```

### Query Optimization

```mermaid fullWidth="true"
graph TD
    A[Query Request] --> B[Expression Builder]
    B --> C[SQL Generator]
    C --> D[Parameterized Query]
    D --> E[Database Execution]
    E --> F[Result Parsing]
    F --> G[Object Mapping]
    G --> H[Return Results]
```

## 🔧 Extension Points

### Custom Validators

```crystal
class EmailValidator < CQL::ActiveRecord::Validations::CustomValidator
  def valid? : Array(CQL::ActiveRecord::Validations::Error)
    errors = [] of CQL::ActiveRecord::Validations::Error

    unless @record.email.includes?("@")
      errors << CQL::ActiveRecord::Validations::Error.new(
        :email, "must be a valid email address"
      )
    end

    errors
  end
end
```

### Custom Column Types

```crystal
# Add support for custom types
enum Status
  Active
  Inactive
  Suspended
end

# Extend type mapping for adapters
CQL::DB_TYPE_MAPPING[CQL::Adapter::Postgres][Status] = "VARCHAR(20)"
```

## 🔍 Debugging and Introspection

### Query Logging

```crystal
# Enable query logging
Log.setup do |config|
  config.level = Log::Severity::Debug
  config.backend = Log::IOBackend.new(STDOUT)
end

# All SQL queries will be logged with parameters
user = User.where(active: true).first
# Logs: SQL queries with parameters
```

### Schema Introspection

```crystal
# Inspect schema at runtime
schema = AcmeDB
puts "Tables: #{schema.tables.keys}"
puts "Users columns: #{schema.tables[:users].columns.keys}"

# Generate schema documentation
dumper = CQL::SchemaDump.from_schema(schema)
schema_code = dumper.generate_schema_content(:MySchema, :my_schema)
```

## 📊 Performance Characteristics

### Benchmarks

| Operation     | Performance           | Memory Usage |
| ------------- | --------------------- | ------------ |
| Simple SELECT | \~50,000 ops/sec      | Low          |
| Complex JOIN  | \~10,000 ops/sec      | Medium       |
| Bulk Insert   | \~100,000 records/sec | Medium       |
| Transaction   | \~20,000 ops/sec      | Low          |

### Optimization Tips

1. **Use prepared statements** - CQL automatically uses parameterized queries
2. **Leverage connection pooling** - Reuse database connections
3. **Batch operations** - Use transactions for multiple operations
4. **Index wisely** - Add indexes for frequently queried columns
5. **Query optimization** - Use `select` to limit returned columns

## 🎪 Advanced Patterns

### Multi-Database Support

```crystal
# Different databases for different purposes
ReadDB = CQL::Schema.define(
  :read_db,
  "postgresql://readonly@localhost/myapp",
  CQL::Adapter::Postgres
) do
  # Read-only replica configuration
end

WriteDB = CQL::Schema.define(
  :write_db,
  "postgresql://user:pass@localhost/myapp",
  CQL::Adapter::Postgres
) do
  # Primary database configuration
end
```

### Migration Support

```crystal
# Create a migration
class CreateUsersMigration < CQL::Migration(20241201001)
  def up
    schema.table :users do
      primary :id, Int64
      column :name, String
      column :email, String
      timestamps
    end
  end

  def down
    schema.exec("DROP TABLE users")
  end
end

# Run migrations
migrator = schema.migrator
migrator.up
```

## 🛡️ Security Architecture

### SQL Injection Prevention

```crystal
# All queries use parameterized statements
query.where(name: user_input)  # Safe - parameterized
# Generates: WHERE name = ? with parameters [user_input]

# Raw SQL requires explicit parameter binding
query.where("name = ?", user_input)  # Safe - explicitly parameterized
```

### Connection Security

```crystal
# SSL/TLS support for database connections
secure_uri = "postgresql://user:pass@host:5432/db?sslmode=require"
SecureDB = CQL::Schema.define(:secure_db, secure_uri, CQL::Adapter::Postgres)
```

## 🧭 Navigation

This architecture provides a solid foundation for building scalable, maintainable, and performant Crystal applications while maintaining type safety and developer productivity.

For more detailed information, see:

- [Getting Started Guide](../getting-started.md)
- [Active Record Guide](../active-record-with-cql/README.md)
- [Schema Definition](../../core-concepts/schemas.md)
- [Migration Workflow](../handling-migrations.md)
