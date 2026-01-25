# Your First CQL App

This tutorial walks you through building your first application with CQL from scratch. By the end, you'll have a working Crystal application that connects to a database, creates tables through migrations, and performs CRUD operations.

## What You'll Learn

- Installing CQL and database drivers
- Configuring a database connection
- Creating and running migrations
- Defining Active Record models
- Performing basic CRUD operations
- Working with associations
- Adding validations
- Using transactions

## Prerequisites

Before starting, ensure you have:

- **Crystal** (latest stable version recommended)
- **A supported database**: PostgreSQL, MySQL, or SQLite
- Basic familiarity with Crystal syntax

## Step 1: Create Your Project

Create a new Crystal project:

```shell
crystal init app myapp
cd myapp
```

## Step 2: Add Dependencies

Add CQL and your database driver to `shard.yml`:

```yaml
dependencies:
  cql:
    github: azutoolkit/cql
    version: ~> 0.0.435

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

Install the dependencies:

```shell
shards install
```

## Step 3: Set Up Database Connection

Create a file to configure your database connection. The setup varies slightly by database.

### PostgreSQL

```crystal
# src/database.cr
require "cql"
require "pg"

DATABASE_URL = ENV["DATABASE_URL"]? || "postgres://username:password@localhost:5432/myapp_development"

AcmeDB = CQL::Schema.define(
  :acme_db,
  adapter: CQL::Adapter::Postgres,
  uri: DATABASE_URL
) do
  # Tables will be defined through migrations
end
```

### SQLite

```crystal
# src/database.cr
require "cql"
require "sqlite3"

AcmeDB = CQL::Schema.define(
  :acme_db,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://./db/development.db"
) do
  # Tables will be defined through migrations
end
```

### MySQL

```crystal
# src/database.cr
require "cql"
require "mysql"

AcmeDB = CQL::Schema.define(
  :acme_db,
  adapter: CQL::Adapter::MySql,
  uri: "mysql://username:password@localhost:3306/myapp_development"
) do
  # Tables will be defined through migrations
end
```

## Step 4: Create Your First Migration

Create a migrations directory and your first migration file:

```shell
mkdir -p migrations
```

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

## Step 5: Define Your First Model

Create a model that maps to your users table:

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

## Step 6: Initialize the Database and Run Migrations

Create a setup script to initialize everything:

```crystal
# src/setup.cr
require "./database"
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

puts "Database initialized with #{migrator.applied_migrations.size} migrations"
```

Run the setup:

```shell
crystal src/setup.cr
```

## Step 7: Perform CRUD Operations

Now you can interact with your data. Create a main application file:

```crystal
# src/myapp.cr
require "./database"
require "./models/*"

AcmeDB.init

# CREATE: Add new users
user = User.new(name: "Alice Johnson", email: "alice@example.com", active: true)

if user.save
  puts "User created with ID: #{user.id}"
else
  puts "Failed to create user"
end

# Or create and save in one step
bob = User.create!(
  name: "Bob Smith",
  email: "bob@example.com",
  active: true
)
puts "Created user: #{bob.name}"

# READ: Find users
found_user = User.find(1)
if found_user
  puts "Found user: #{found_user.name}"
end

# Find by attributes
alice = User.find_by(email: "alice@example.com")
puts "User: #{alice.try(&.name)}"

# Query with conditions
active_users = User.where(active: true).all
puts "Active users: #{active_users.size}"

# UPDATE: Modify users
if found_user
  found_user.active = false
  found_user.save
  puts "User updated"
end

# DELETE: Remove users
inactive = User.where(active: false).first
inactive.try(&.delete!)
puts "Inactive user deleted"
```

Run your application:

```shell
crystal src/myapp.cr
```

## Step 8: Add a Related Model

Let's add posts to demonstrate relationships. First, create the migration:

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

Create the Post model:

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
  belongs_to :user, User, foreign_key: :user_id

  def initialize(@title : String, @body : String, @user_id : Int64)
  end
end
```

Update the User model to include the association:

```crystal
# src/models/user.cr (updated)
struct User
  include CQL::ActiveRecord::Model(Int64)

  db_context AcmeDB, :users

  property id : Int64?
  property name : String
  property email : String
  property active : Bool = false
  property created_at : Time?
  property updated_at : Time?

  # Associations
  has_many :posts, foreign_key: :user_id

  def initialize(@name : String, @email : String, @active : Bool = false)
  end
end
```

Run migrations and test:

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
  author = post.user
  puts "Post '#{post.title}' by #{author.try(&.name)}"
end
```

## Step 9: Add Validations

Enhance your User model with validations:

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)

  db_context AcmeDB, :users

  property id : Int64?
  property name : String
  property email : String
  property active : Bool = false
  property created_at : Time?
  property updated_at : Time?

  has_many :posts, foreign_key: :user_id

  # Add validations
  validate :name, presence: true, size: (1..100)
  validate :email, presence: true, match: /@/

  def initialize(@name : String, @email : String, @active : Bool = false)
  end
end
```

## Step 10: Use Transactions

Ensure data consistency with transactions:

```crystal
User.transaction do |tx|
  user = User.create!(name: "Charlie", email: "charlie@example.com")

  post = Post.create!(
    title: "Welcome Post",
    body: "Thanks for joining!",
    user_id: user.id.not_nil!
  )

  # If any operation fails, everything is rolled back
  puts "User and welcome post created successfully"
end
```

## Project Structure

Your completed project should look like this:

```
myapp/
├── shard.yml
├── src/
│   ├── myapp.cr           # Main application
│   ├── database.cr        # Database configuration
│   ├── setup.cr           # Migration runner
│   ├── models/
│   │   ├── user.cr        # User model
│   │   └── post.cr        # Post model
│   └── schemas/
│       └── acme_schema.cr # Auto-generated schema
├── migrations/
│   ├── 001_create_users.cr
│   └── 002_create_posts.cr
└── db/
    └── development.db     # SQLite database file (if using SQLite)
```

## Troubleshooting

### Database Connection Issues

```crystal
begin
  AcmeDB.init
  puts "Database connection successful"
rescue ex
  puts "Database connection failed: #{ex.message}"
end
```

### Migration Issues

```crystal
migrator = AcmeDB.migrator(config)
puts "Applied migrations: #{migrator.applied_migrations.size}"
puts "Pending migrations: #{migrator.pending_migrations.size}"

# Reset database (development only)
migrator.down_to(0)  # Rollback all
migrator.up          # Reapply all
```

## Next Steps

Congratulations! You've built your first CQL application. Continue learning with:

- [Building a Blog](../building-a-blog/01-project-setup.md) - A comprehensive multi-part tutorial
- [Define a Model](../../how-to/models/define-model.md) - Learn advanced model features
- [Build Complex Queries](../../how-to/querying/complex-queries.md) - Master the query interface
- [Add Validations](../../how-to/models/add-validations.md) - Ensure data integrity
