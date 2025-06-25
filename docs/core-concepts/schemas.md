# DB Schema

## Accelerating Database Iteration

Defining the schema first is a fundamental approach in CQL, helping developers quickly structure their database while keeping their application's data model in sync with real-world entities. By defining your schema upfront, you can rapidly iterate over your database tables, making it easy to adjust data structures as your application evolves. This method ensures that your schema is the single source of truth, giving you a clear view of how your data is organized and how relationships between different tables are modeled.

```mermaid fullWidth="true"
erDiagram
    MOVIES ||--o{ SCREENPLAYS : "has many"
    MOVIES ||--o{ DIRECTORS : "has many"
    MOVIES ||--o{ MOVIES_ACTORS : "has many"
    ACTORS ||--o{ MOVIES_ACTORS : "has many"

    MOVIES {
        int64 id PK "Primary Key, Auto Increment"
        text title "Movie Title"
    }

    SCREENPLAYS {
        int64 id PK "Primary Key, Auto Increment"
        bigint movie_id FK "Foreign Key to movies.id"
        text content "Screenplay Content"
    }

    ACTORS {
        int64 id PK "Primary Key, Auto Increment"
        text name "Actor Name"
    }

    DIRECTORS {
        int64 id PK "Primary Key, Auto Increment"
        bigint movie_id FK "Foreign Key to movies.id"
        text name "Director Name"
    }

    MOVIES_ACTORS {
        int64 id PK "Primary Key, Auto Increment"
        bigint movie_id FK "Foreign Key to movies.id"
        bigint actor_id FK "Foreign Key to actors.id"
    }
```

## Benefits of Defining the Schema First

1. **Faster Prototyping**: With schemas defined at the outset, you can rapidly experiment with different table structures and relationships, making it easier to adjust your application's data model without writing complex migrations from scratch.
2. **Clear Data Structure**: When your schema is predefined, the application's data structure becomes clearer, allowing developers to conceptualize how data is organized and interact with tables more easily.
3. **Consistency**: Ensuring the schema matches the database at all times removes ambiguity when writing queries, handling relationships, or performing migrations.
4. **Automatic Data Validation**: CQL schemas enforce data types and constraints, such as `primary`, `auto_increment`, and `text`, ensuring data integrity.
5. **Simplified Query Building**: Since the schema is explicit, writing queries becomes easier as you can reference schema objects directly in queries, avoiding mistakes or typos in table or column names.

## **Difference from Other ORM Libraries**

Unlike traditional ORM libraries (e.g., Active Record in Rails or Ecto in Elixir), which often allow defining database models alongside the code and handling schema evolution through migrations, CQL encourages defining the database schema as the first step.

This "schema-first" approach differs from the "code-first" or "migration-based" methodologies in that it avoids relying on automatic migrations or conventions to infer the structure of the database. CQL enforces an explicit and structured approach to schema creation, ensuring the database schema reflects the actual architecture of your application.

## **Example Schema Definition**

Here's a basic example of how to define a schema in CQL for a movie-related database:

```crystal
AcmeDB2 = CQL::Schema.build(
  :acme_db,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]) do

  table :movies do
    primary :id, Int64, auto_increment: true
    text :title
  end

  table :screenplays do
    primary :id, Int64, auto_increment: true
    bigint :movie_id
    text :content
  end

  table :actors do
    primary :id, Int64, auto_increment: true
    text :name
  end

  table :directors do
    primary :id, Int64, auto_increment: true
    bigint :movie_id
    text :name
  end

  table :movies_actors do
    primary :id, Int64, auto_increment: true
    bigint :movie_id
    bigint :actor_id
  end
end
```

## Explanation of Schema Definition

- **Database name**: `:acme_db` defines the schema name.
- **Adapter**: `CQL::Adapter::Postgres` specifies the database adapter (in this case, PostgreSQL).
- **Connection URL**: The `uri: ENV["DATABASE_URL"]` specifies the database connection using environment variables.

Each table is explicitly defined with its columns, such as:

- `:movies` table has `id` as the primary key and `title` as a `text` column.
- `:screenplays`, `:actors`, and `:directors` define relationships between movies and associated records.

This example shows how easy it is to define tables and manage relationships within the schema, leading to a more organized and coherent database structure that aligns with the application's needs.

---

## Table Operations

CQL provides comprehensive table operations for managing your database tables. These operations allow you to create, modify, and manage tables programmatically.

### Table Creation

You can create tables using the `create!` method:

```crystal
table = schema.table(:customers) do
  primary :id, Int32
  column :name, String
  column :city, String
  column :email, String
  column :balance, Int32
  timestamps
end

# Create the table in the database
table.create!
```

### Table Validation

CQL validates table names to ensure they follow proper naming conventions:

```crystal
# Valid table name
table = schema.table(:customers) do
  primary :id, Int32
end

# Invalid table names will raise errors
expect_raises(CQL::Error, "Table name cannot be empty") do
  schema.table(:"") do
    primary :id, Int32
  end
end

expect_raises(CQL::Error, "Table name cannot contain spaces") do
  schema.table(:"my table") do
    primary :id, Int32
  end
end

expect_raises(CQL::Error, "Table name cannot start with a number") do
  schema.table(:"1users") do
    primary :id, Int32
  end
end
```

### Column Operations

#### Primary Key Columns

```crystal
table = schema.table(:customers) do
  primary :id, Int64
end

primary = table.primary(:id, Int64)
primary.should be_a(CQL::PrimaryKey(Int64))
primary.name.should eq :id
primary.as(CQL::PrimaryKey(Int64)).auto_increment?.should be_true
primary.as(CQL::PrimaryKey(Int64)).unique?.should be_true
```

#### Regular Columns

```crystal
table = schema.table(:customers) do
  column :name, String
end

column = table.column(:name, String)
column.should be_a(CQL::Column(String))
column.name.should eq :name
column.null?.should be_false
```

#### Indexed Columns

```crystal
table = schema.table(:customers) do
  column :email, String, index: true, unique: true
end

column = table.column(:email, String, index: true, unique: true)
column.should be_a(CQL::Column(String))
column.index?.should_not be_nil
column.index?.not_nil!.unique?.should be_true
```

#### Timestamps

```crystal
table = schema.table(:customers) do
  timestamps
end

table.timestamps
table.columns[:created_at]?.should_not be_nil
table.columns[:updated_at]?.should_not be_nil
```

### Table Management Operations

#### Truncating Tables

Remove all data from a table while keeping the table structure:

```crystal
table = schema.table(:customers) do
  primary :id, Int32
  column :name, String
  column :city, String
  column :email, String
  column :balance, Int32
  timestamps
end

table.create!

# Insert some data
schema.insert.into(:customers).values([
  {name: "John", city: "New York", email: "john@example.com", balance: 100},
  {name: "Jane", city: "New York", email: "jane@example.com", balance: 200}
]).commit

# Verify data exists
count = schema.query.from(:customers).count.get(Int64)
count.should eq 2

# Truncate the table
table.truncate!

# Verify table is empty
count = schema.query.from(:customers).count.get(Int32)
count.should eq 0
```

#### Dropping Tables

Remove a table completely from the database:

```crystal
table = schema.table(:customers) do
  primary :id, Int32
  column :name, String
  column :city, String
  column :email, String
  column :balance, Int32
  timestamps
end

table.create!

# Drop the table
table.drop!

# Verify table no longer exists
expect_raises(DB::NoResultsError) do
  schema.exec_query(&.query_one("SELECT name FROM sqlite_master WHERE type='table' AND name='customers'", as: String))
end
```

### SQL Generation

CQL can generate SQL statements for table operations:

#### Create Table SQL

```crystal
table = schema.table(:customers) do
  primary :id, Int32, auto_increment: false
  column :name, String
  column :city, String
  column :balance, Int32
end

sql = table.create_sql
sql.should contain("CREATE TABLE IF NOT EXISTS customers")
sql.should contain("id INTEGER PRIMARY KEY")
sql.should contain("name TEXT NOT NULL")
sql.should contain("city TEXT NOT NULL")
sql.should contain("balance INTEGER NOT NULL")
```

#### Drop Table SQL

```crystal
table = schema.table(:customers) do
  primary :id, Int32
  column :name, String
  column :city, String
  column :balance, Int32
end

sql = table.drop_sql
sql.should eq("DROP TABLE IF EXISTS customers")
```

#### Truncate Table SQL

```crystal
table = schema.table(:customers) do
  primary :id, Int32
  column :name, String
  column :city, String
  column :balance, Int32
end

sql = table.truncate_sql
sql.should eq("DELETE FROM customers")
```

### Table Aliases

You can define table aliases for use in queries:

```crystal
schema = CQL::Schema.define(:test_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://#{db_file}") do
  table :users, as: :u do
    primary :id, Int32
    column :name, String
  end
end

table = schema.tables[:users]
table.as_name.should eq "u"
```

### Best Practices

1. **Always validate table names**: Use descriptive, valid table names that follow naming conventions.

2. **Use appropriate data types**: Choose the right data types for your columns to ensure data integrity and performance.

3. **Include timestamps**: Use the `timestamps` method to automatically add `created_at` and `updated_at` columns.

4. **Add indexes for performance**: Use indexes on columns that are frequently queried or used in joins.

5. **Test table operations**: Always test table creation, modification, and deletion operations in a development environment.

6. **Backup before destructive operations**: Always backup your data before performing truncate or drop operations.

---

#### **Multiple Schemas: Flexibility and Easy Switching**

One significant advantage of CQL is the ability to define and manage multiple schemas within the same application. This is particularly useful in scenarios like multi-tenant applications, where each tenant or environment has a separate database schema. CQL makes switching between schemas seamless, enabling developers to organize different parts of the application independently while maintaining the same connection configuration.

This approach offers the following benefits:

- **Clear Separation of Data**: Each schema can encapsulate its own set of tables and relationships, allowing better isolation and separation of concerns within the application. For example, you might have a `main` schema for core business data and a separate `analytics` schema for reporting.
- **Simple Switching**: Switching between schemas is as simple as referring to the schema name, thanks to CQL's structured definition of schemas. This allows dynamic switching at runtime, improving scalability in multi-tenant applications.

#### **Example: Managing Multiple Schemas**

```crystal
MainDB = CQL::Schema.build(:main, adapter: CQL::Adapter::Postgres, uri: ENV["MAIN_DB_URL"]) do
  # Define main schema tables
end

AnalyticsDB = CQL::Schema.build(:analytics, adapter: CQL::Adapter::Postgres, uri: ENV["ANALYTICS_DB_URL"]) do
  # Define analytics schema tables
end
```

In this example, you define multiple schemas, and the application can easily switch between `MainDB` and `AnalyticsDB` depending on which database needs to be queried.

#### **Benefits of Multiple Schemas**

- **Improved Organization**: Separate business logic data from other concerns like reporting, testing, or archiving.
- **Scalability**: Ideal for multi-tenant applications, allowing each tenant to have its schema without interference.

By using CQL's schema system, you gain not only speed and clarity in your database structure but also flexibility in scaling and organizing your application.

# Schema Definition in CQL

CQL uses a declarative DSL for defining database schemas that map directly to your application's data models. The schema system supports multiple database adapters and provides type-safe column definitions with automatic SQL generation.

---

## Basic Schema Definition

Schemas are defined using the `CQL::Schema.define` method with a block containing table definitions:

```crystal
# Define a schema with database connection details
UserDB = CQL::Schema.define(
  :user_database,                          # Schema name
  adapter: CQL::Adapter::SQLite,           # Database adapter
  uri: "sqlite3://path/to/database.db"     # Connection URI
) do
  # Table definitions go here
  table :users do
    primary :id, Int32                     # Primary key
    column :name, String, null: true       # Nullable column
    column :email, String                  # Required column
    column :age, Int32                     # Integer column
    timestamps                             # created_at/updated_at columns
  end
end
```

---

## Supported Database Adapters

CQL supports three major database systems with proper dialect handling:

### SQLite

```crystal
AppDB = CQL::Schema.define(
  :app_database,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://db/app.db"
) do
  # Table definitions...
end
```

### PostgreSQL

```crystal
ProductionDB = CQL::Schema.define(
  :production_database,
  adapter: CQL::Adapter::Postgres,
  uri: "postgresql://user:password@localhost:5432/mydb"
) do
  # Table definitions...
end
```

### MySQL

```crystal
LegacyDB = CQL::Schema.define(
  :legacy_database,
  adapter: CQL::Adapter::MySql,
  uri: "mysql://user:password@localhost:3306/legacy_db"
) do
  # Table definitions...
end
```

---

## Primary Keys

Define primary keys using the `primary` method with the column name and type:

### Auto-incrementing Integer Primary Keys

```crystal
table :users do
  primary :id, Int32        # 32-bit integer primary key
  # or
  primary :id, Int64        # 64-bit integer primary key
end
```

### UUID Primary Keys

```crystal
table :sessions do
  primary :id, UUID         # UUID primary key
  column :user_id, Int32
  column :token, String
end
```

### ULID Primary Keys

```crystal
table :events do
  primary :id, ULID         # ULID primary key (sortable UUIDs)
  column :event_type, String
  column :payload, JSON::Any
end
```

---

## Column Definitions

Define table columns using the `column` method with name, type, and optional constraints:

### Basic Column Types

```crystal
table :products do
  primary :id, Int32
  column :name, String                    # VARCHAR/TEXT
  column :price, Float64                  # DOUBLE/REAL
  column :quantity, Int32                 # INTEGER
  column :active, Bool                    # BOOLEAN
  column :created_at, Time                # TIMESTAMP/DATETIME
  column :metadata, JSON::Any             # JSON/JSONB
  column :image_data, Slice(UInt8)        # BLOB/BYTEA
end
```

### Nullable Columns

```crystal
table :users do
  primary :id, Int32
  column :name, String                    # NOT NULL (default)
  column :bio, String, null: true         # NULL allowed
  column :last_login, Time, null: true    # NULL allowed
end
```

### Column Size and Precision

```crystal
table :financial_records do
  primary :id, Int32
  column :account_number, String, size: 20    # VARCHAR(20)
  column :amount, Float64, precision: 10, scale: 2  # DECIMAL(10,2)
  column :description, String, size: 500      # VARCHAR(500)
end
```

---

## Foreign Keys

Define foreign key relationships between tables:

### Basic Foreign Key

```crystal
table :posts do
  primary :id, Int32
  column :title, String
  column :body, String
  column :user_id, Int32, null: true

  # Define foreign key constraint
  foreign_key [:user_id], references: :users, references_columns: [:id]
end
```

### Composite Foreign Keys

```crystal
table :order_items do
  primary :id, Int32
  column :order_id, Int32
  column :product_id, Int32
  column :quantity, Int32

  # Foreign key to orders table
  foreign_key [:order_id], references: :orders, references_columns: [:id]
  # Foreign key to products table
  foreign_key [:product_id], references: :products, references_columns: [:id]
end
```

### Many-to-Many Join Tables

```crystal
table :movies_actors do
  primary :id, Int32
  column :movie_id, Int32
  column :actor_id, Int32

  # Foreign keys for many-to-many relationship
  foreign_key [:movie_id], references: :movies, references_columns: [:id]
  foreign_key [:actor_id], references: :actors, references_columns: [:id]
end
```

---

## Timestamps

Add automatic timestamp columns using the `timestamps` helper:

```crystal
table :articles do
  primary :id, Int32
  column :title, String
  column :content, String

  # Adds created_at and updated_at columns
  timestamps
end
```

This is equivalent to:

```crystal
table :articles do
  primary :id, Int32
  column :title, String
  column :content, String
  column :created_at, Time, null: true
  column :updated_at, Time, null: true
end
```

---

## Indexes

Define database indexes for improved query performance:

### Single Column Index

```crystal
table :users do
  primary :id, Int32
  column :email, String
  column :username, String

  # Create index on email column
  index :email
  # Create unique index on username
  index :username, unique: true
end
```

### Composite Index

```crystal
table :log_entries do
  primary :id, Int32
  column :user_id, Int32
  column :action, String
  column :created_at, Time

  # Create composite index on multiple columns
  index [:user_id, :created_at]
  index [:action, :created_at], name: "idx_action_timestamp"
end
```

---

## Complete Schema Example

Here's a comprehensive example showing a complete schema definition:

```crystal
# Define the main application database schema
AppDB = CQL::Schema.define(
  :app_database,
  adapter: CQL::Adapter::PostgreSQL,
  uri: ENV["DATABASE_URL"]
) do

  # Users table
  table :users do
    primary :id, Int32
    column :name, String
    column :email, String
    column :password_hash, String
    column :role, String, default: "user"
    column :active, Bool, default: true
    column :last_login, Time, null: true
    timestamps

    # Indexes
    index :email, unique: true
    index :active
  end

  # Posts table
  table :posts do
    primary :id, Int32
    column :title, String
    column :body, String
    column :published, Bool, default: false
    column :user_id, Int32, null: true
    timestamps

    # Foreign key to users
    foreign_key [:user_id], references: :users, references_columns: [:id]

    # Indexes
    index :user_id
    index :published
    index [:user_id, :published]
  end

  # Comments table
  table :comments do
    primary :id, Int32
    column :content, String
    column :post_id, Int32
    column :user_id, Int32, null: true
    timestamps

    # Foreign keys
    foreign_key [:post_id], references: :posts, references_columns: [:id]
    foreign_key [:user_id], references: :users, references_columns: [:id]

    # Indexes
    index :post_id
    index :user_id
  end

  # Tags table for many-to-many with posts
  table :tags do
    primary :id, Int32
    column :name, String
    timestamps

    index :name, unique: true
  end

  # Join table for posts and tags
  table :posts_tags do
    primary :id, Int32
    column :post_id, Int32
    column :tag_id, Int32

    foreign_key [:post_id], references: :posts, references_columns: [:id]
    foreign_key [:tag_id], references: :tags, references_columns: [:id]

    # Prevent duplicate associations
    index [:post_id, :tag_id], unique: true
  end
end
```

---

## Schema Operations

### Creating Tables

```crystal
# Create all tables defined in the schema
AppDB.create_tables!

# Create specific table
AppDB.users.create!
```

### Dropping Tables

```crystal
# Drop all tables
AppDB.drop_tables!

# Drop specific table
AppDB.users.drop!
```

### Checking Table Existence

```crystal
# Check if table exists
if AppDB.users.exists?
  puts "Users table exists"
end
```

---

## Environment-Specific Schemas

Define different schemas for different environments:

```crystal
# Development schema (SQLite)
DevelopmentDB = CQL::Schema.define(
  :development,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://db/development.db"
) do
  # Table definitions...
end

# Test schema (in-memory SQLite)
TestDB = CQL::Schema.define(
  :test,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://:memory:"
) do
  # Same table definitions as development...
end

# Production schema (PostgreSQL)
ProductionDB = CQL::Schema.define(
  :production,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
) do
  # Same table definitions with production optimizations...
end
```

---

## Best Practices

### Naming Conventions

- **Schema names**: Use descriptive names like `:user_database`, `:analytics_db`
- **Table names**: Use plural nouns (`users`, `posts`, `order_items`)
- **Column names**: Use snake_case (`user_id`, `created_at`, `full_name`)
- **Foreign keys**: Follow pattern `{table_name}_id` (`user_id`, `post_id`)

### Performance Considerations

- **Add indexes** on frequently queried columns
- **Use appropriate data types** (Int32 vs Int64, String sizes)
- **Consider composite indexes** for multi-column queries
- **Use foreign keys** for referential integrity

### Schema Organization

- **Group related tables** together in the schema definition
- **Define base tables first**, then tables with foreign keys
- **Use consistent column ordering** (id, business columns, timestamps)
- **Document complex relationships** with comments

### Environment Management

- **Use environment variables** for database URIs
- **Keep schema definitions** consistent across environments
- **Use migrations** for schema changes in production

---

The CQL schema system provides a powerful, type-safe way to define your database structure with automatic SQL generation and comprehensive relationship management.
