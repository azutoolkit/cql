# Getting Started with CQL

Welcome to CQL (Crystal Query Language)! This guide will walk you through setting up CQL in your Crystal project, connecting to a database, defining your first model, and performing basic operations.

CQL is a powerful Object-Relational Mapping (ORM) library that provides type-safe database interactions, migrations, and Active Record patterns for Crystal applications.

---

## Prerequisites

Before getting started, ensure you have:

- **Crystal** (latest stable version recommended)
- **A supported database**: PostgreSQL, MySQL, or SQLite
- **Database driver shards**: Depending on your database choice

---

## 1. Installation

Add CQL and your database driver to your `shard.yml`:

```yaml
dependencies:
  cql:
    github: azutoolkit/cql
    version: ~> 0.0.266

  # Choose your database driver:
  pg: # For PostgreSQL
    github: will/crystal-pg
    version: "~> 0.26.0"

  # OR
  mysql: # For MySQL
    github: crystal-lang/crystal-mysql
    version: "~> 0.14.0"

  # OR
  sqlite3: # For SQLite
    github: crystal-lang/crystal-sqlite3
    version: "~> 0.18.0"
```

Then install dependencies:

```shell
shards install
```

---

## 2. Database Setup

### PostgreSQL Example

```crystal
require "cql"
require "pg"

# Define your database connection
DATABASE_URL = ENV["DATABASE_URL"]? || "postgres://username:password@localhost:5432/myapp_development"

# Create your schema definition (initially empty - will be built via migrations)
AcmeDB = CQL::Schema.define(
  :acme_db,
  adapter: CQL::Adapter::Postgres,
  uri: DATABASE_URL
) do
  # Tables will be defined through migrations
end
```

### SQLite Example

```crystal
require "cql"
require "sqlite3"

# For SQLite (great for development and testing)
AcmeDB = CQL::Schema.define(
  :acme_db,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://./db/development.db"
) do
  # Tables will be defined through migrations
end
```

### MySQL Example

```crystal
require "cql"
require "mysql"

# For MySQL
AcmeDB = CQL::Schema.define(
  :acme_db,
  adapter: CQL::Adapter::MySql,
  uri: "mysql://username:password@localhost:3306/myapp_development"
) do
  # Tables will be defined through migrations
end
```

---

## 3. Creating Your First Migration

Create a migration to set up your database schema:

```crystal
# migrations/001_create_users.cr
class CreateUsers < CQL::Migration(1)
  def up
    schema.create :users do
      primary :id, Int64, auto_increment: true
      text :name, null: false
      text :email, null: false
      boolean :active, default: false
      timestamps  # Creates created_at and updated_at columns
    end

    # Add indexes for better performance
    schema.alter :users do
      create_index :idx_users_email, [:email], unique: true
    end
  end

  def down
    schema.drop :users
  end
end
```

---

## 4. Defining Your First Model

Create a model that represents your users table:

```crystal
# src/models/user.cr
struct User
  include CQL::ActiveRecord::Model(Int64)

  # Connect to the database and table
  db_context AcmeDB, :users

  # Define your model attributes
  property id : Int64?
  property name : String
  property email : String
  property active : Bool = false
  property created_at : Time?
  property updated_at : Time?

  # Constructor for creating new instances
  def initialize(@name : String, @email : String, @active : Bool = false)
  end
end
```

---

## 5. Initialize Database and Run Migrations

Set up automatic schema synchronization and run your migrations:

```mermaid
flowchart TD
    A[Application Start] --> B[Load CQL & Dependencies]
    B --> C[Define Schema Connection]
    C --> D[Initialize Database]
    D --> E[Configure Migrator]
    E --> F[Check Migration Status]
    F --> G{Pending Migrations?}
    G -->|Yes| H[Run Migrations]
    G -->|No| I[Schema Ready]
    H --> J[Update Schema File]
    J --> K[Application Ready]
    I --> K

    style D fill:#e8f5e8
    style H fill:#fff3e0
    style K fill:#e8f5e8
```

```crystal
# src/database.cr
require "cql"
require "./models/*"
require "../migrations/*"

# Configure automatic schema file synchronization
config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/acme_schema.cr",
  schema_name: :AcmeSchema,
  auto_sync: true
)

# Initialize the database
AcmeDB.init

# Create migrator and apply migrations
migrator = AcmeDB.migrator(config)
migrator.up

puts "✅ Database initialized with #{migrator.applied_migrations.size} migrations"
```

---

## 6. Basic CRUD Operations

Now you can start working with your data:

```mermaid
stateDiagram-v2
    [*] --> NewRecord : User.new()
    NewRecord --> Persisted : save() / create()
    NewRecord --> [*] : validation fails

    Persisted --> Modified : attribute=()
    Modified --> Persisted : save() / update()
    Modified --> [*] : validation fails

    Persisted --> [*] : delete()

    note right of NewRecord
        new_record? = true
        persisted? = false
        id = nil
    end note

    note right of Persisted
        new_record? = false
        persisted? = true
        id = assigned
    end note

    note right of Modified
        changed? = true
        has pending changes
    end note
```

### Create Records

```crystal
# Create and save a new user
user = User.new(name: "Alice Johnson", email: "alice@example.com", active: true)

if user.save
  puts "✅ User created with ID: #{user.id}"
else
  puts "❌ Failed to create user"
end

# Or create and save in one step
user = User.create!(
  name: "Bob Smith",
  email: "bob@example.com",
  active: true
)
puts "✅ User created: #{user.name}"
```

### Read Records

```crystal
# Find by primary key
user = User.find(1)
if user
  puts "Found user: #{user.name}"
else
  puts "User not found"
end

# Find by attributes
user = User.find_by(email: "alice@example.com")
puts "User: #{user.try(&.name)}"

# Query with conditions
active_users = User.where(active: true).all
puts "Active users: #{active_users.size}"

# Complex queries
recent_users = User.where { created_at > 1.week.ago }
                  .order(name: :asc)
                  .limit(10)
                  .all
puts "Recent users: #{recent_users.map(&.name).join(", ")}"
```

### Update Records

```crystal
# Update a single record
user = User.find(1)
if user
  user.active = false
  user.save
  puts "✅ User updated"
end

# Update with attributes method
user.try(&.update!(active: false, name: "Alice Smith"))

# Bulk updates
User.where(active: false).update!(active: true)
puts "✅ All inactive users activated"
```

### Delete Records

```crystal
# Delete a single record
user = User.find(1)
user.try(&.delete!)
puts "✅ User deleted"

# Bulk deletes
User.where(active: false).delete!
puts "✅ All inactive users deleted"
```

---

## 7. Working with Associations

Let's add posts to demonstrate relationships:

### Create Posts Migration

```crystal
# migrations/002_create_posts.cr
class CreatePosts < CQL::Migration(2)
  def up
    schema.create :posts do
      primary :id, Int64, auto_increment: true
      text :title, null: false
      text :body, null: false
      bigint :user_id, null: false
      timestamps

      foreign_key [:user_id], references: :users, references_columns: [:id], on_delete: "CASCADE"
    end

    schema.alter :posts do
      create_index :idx_posts_user_id, [:user_id]
    end
  end

  def down
    schema.drop :posts
  end
end
```

### Define Post Model

```crystal
# src/models/post.cr
struct Post
  include CQL::ActiveRecord::Model(Int64)

  db_context AcmeDB, :posts

  property id : Int64?
  property title : String
  property body : String
  property user_id : Int64
  property created_at : Time?
  property updated_at : Time?

  # Associations
  belongs_to :user, key: user_id, ref: id

  def initialize(@title : String, @body : String, @user_id : Int64)
  end
end
```

### Update User Model with Association

```crystal
# Add to your User model
struct User
  # ... existing properties ...

  # Associations
  has_many :posts, key: id, ref: user_id
end
```

### Work with Associations

```crystal
# Create user and posts
user = User.create!(name: "Alice", email: "alice@example.com")

post1 = Post.create!(
  title: "My First Post",
  body: "This is my first blog post!",
  user_id: user.id.not_nil!
)

post2 = Post.create!(
  title: "Another Post",
  body: "More content here",
  user_id: user.id.not_nil!
)

# Access associated records
user_posts = user.posts.all
puts "#{user.name} has #{user_posts.size} posts"

# Access parent record
post = Post.find(1)
if post
  post_author = post.user
  puts "Post '#{post.title}' by #{post_author.try(&.name)}"
end
```

---

## 8. Using Validations

Add validations to ensure data integrity:

```mermaid
flowchart TD
    A[user.save called] --> B[Run Validations]
    B --> C[Presence Validations]
    C --> D[Format Validations]
    D --> E[Custom Validations]
    E --> F{All Valid?}
    F -->|Yes| G[Save to Database]
    F -->|No| H[Populate Errors]
    G --> I[Return true]
    H --> J[Return false]

    subgraph "Validation Types"
        C1[presence: true]
        D1[match: /@/]
        E1[validate_email_uniqueness]
    end

    C -.-> C1
    D -.-> D1
    E -.-> E1

    style G fill:#e8f5e8
    style I fill:#e8f5e8
    style H fill:#ffebee
    style J fill:#ffebee
```

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)

  db_context AcmeDB, :users

  # ... properties ...

  # Add validations
  validate :name, presence: true, size: (1..100)
  validate :email, presence: true, match: /@/

  private def validate_email_uniqueness
    existing = User.where(email: @email).where { id != @id }.first
    if existing
      errors.add(:email, "has already been taken")
    end
  end
end
```

---

## 9. Using Transactions

Ensure data consistency with transactions:

```crystal
# Wrap multiple operations in a transaction
User.transaction do |tx|
  user = User.create!(name: "Charlie", email: "charlie@example.com")

  post = Post.create!(
    title: "Welcome Post",
    body: "Thanks for joining!",
    user_id: user.id.not_nil!
  )

  # If any operation fails, everything is rolled back
  puts "✅ User and welcome post created successfully"
end
```

---

## 10. Next Steps

Congratulations! You now have a working CQL application. Here's what to explore next:

### Essential Guides

- **[Defining Models](active-record-with-cql/defining-models.md)** - Learn advanced model features
- **[Complex Queries](active-record-with-cql/complex-queries.md)** - Master the query interface
- **[Validations](active-record-with-cql/validations.md)** - Ensure data integrity
- **[Relationships](active-record-with-cql/relations/README.md)** - Work with associations
- **[Migrations](active-record-with-cql/migrations.md)** - Manage schema changes

### Advanced Topics

- **[Transactions](active-record-with-cql/transactions.md)** - Maintain data consistency
- **[Callbacks](active-record-with-cql/callbacks.md)** - Hook into model lifecycle
- **[Scopes](active-record-with-cql/scopes.md)** - Create reusable query methods
- **[Performance Optimization](performance-optimization.md)** - Scale your application

### Patterns and Best Practices

- **[Repository Pattern](../core-concepts/patterns/repository.md)** - Alternative to Active Record
- **[Testing Strategies](testing-strategies.md)** - Test your database code
- **[Deployment Guide](deployment-guide.md)** - Deploy to production

---

## Common Issues and Solutions

### Database Connection Issues

```crystal
# Test your connection
begin
  AcmeDB.init
  puts "✅ Database connection successful"
rescue ex
  puts "❌ Database connection failed: #{ex.message}"
end
```

### Migration Issues

```crystal
# Check migration status
migrator = AcmeDB.migrator(config)
puts "Applied migrations: #{migrator.applied_migrations.size}"
puts "Pending migrations: #{migrator.pending_migrations.size}"

# Reset database (development only)
migrator.down_to(0)  # Rollback all
migrator.up          # Reapply all
```

### Schema Synchronization Issues

```crystal
# Check if schema file is in sync
if migrator.verify_schema_consistency
  puts "✅ Schema is synchronized"
else
  puts "⚠️  Schema out of sync - updating..."
  migrator.update_schema_file
end
```

---

## Example Application Structure

```shell
myapp/
├── shard.yml
├── src/
│   ├── myapp.cr           # Main application
│   ├── database.cr        # Database configuration
│   ├── models/
│   │   ├── user.cr        # User model
│   │   └── post.cr        # Post model
│   └── schemas/
│       └── acme_schema.cr # Auto-generated schema
├── migrations/
│   ├── 001_create_users.cr
│   └── 002_create_posts.cr
└── db/
    └── development.db     # SQLite database file
```

---

Welcome to CQL! You're now ready to build powerful, type-safe database applications with Crystal. 🎉
