# Part 1: Project Setup

This is the first part of a five-part tutorial series where you'll build a complete blog engine with CQL. In this part, you'll set up your project structure, configure CQL, and prepare the foundation for your blog application.

## What You'll Learn

- Setting up a Crystal project for CQL
- Configuring CQL for different environments
- Understanding the project structure
- Preparing for database migrations

## Prerequisites

- Crystal 1.0+ installed
- Basic understanding of Crystal syntax
- Familiarity with database concepts
- Completed [Your First CQL App](../getting-started/your-first-cql-app.md) tutorial (recommended)

## The Blog Engine Architecture

Before we start coding, let's understand what we're building:

```
Blog Engine
├── Users (authors and commenters)
├── Categories (post organization)
├── Posts (blog content)
└── Comments (reader engagement)
```

The relationships:
- A User has many Posts and Comments
- A Category has many Posts
- A Post belongs to a User and a Category, and has many Comments
- A Comment belongs to a Post and optionally a User

## Step 1: Create the Project

```shell
crystal init app blog_engine
cd blog_engine
```

## Step 2: Configure Dependencies

Edit your `shard.yml`:

```yaml
name: blog_engine
version: 0.1.0

dependencies:
  cql:
    github: azutoolkit/cql
    version: ~> 0.0.435
  sqlite3:
    github: crystal-lang/crystal-sqlite3
    version: "~> 0.18.0"

targets:
  blog_engine:
    main: src/blog_engine.cr
```

Install dependencies:

```shell
shards install
```

## Step 3: Set Up Project Structure

Create the necessary directories:

```shell
mkdir -p src/models
mkdir -p src/schemas
mkdir -p migrations
mkdir -p db
```

Your project structure should look like:

```
blog_engine/
├── shard.yml
├── src/
│   ├── blog_engine.cr      # Main entry point
│   ├── database.cr         # Database configuration
│   ├── models/             # Active Record models
│   └── schemas/            # Auto-generated schemas
├── migrations/             # Database migrations
└── db/                     # SQLite database files
```

## Step 4: Configure the Database

Create the database configuration file:

```crystal
# src/database.cr
require "cql"
require "sqlite3"

# Database connection URL - easily switchable via environment
DATABASE_URL = ENV["DATABASE_URL"]? || "sqlite3://./db/blog_development.db"

# Define the schema connection
BlogDB = CQL::Schema.define(
  :blog_db,
  adapter: CQL::Adapter::SQLite,
  uri: DATABASE_URL
) do
  # Tables will be defined through migrations
end

# Migration configuration
MIGRATOR_CONFIG = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/blog_schema.cr",
  schema_name: :BlogSchema,
  auto_sync: true
)
```

## Step 5: Create the Main Entry Point

```crystal
# src/blog_engine.cr
require "./database"
require "./models/*"

module BlogEngine
  VERSION = "0.1.0"

  def self.setup
    # Initialize database connection
    BlogDB.init
    puts "Database connected"
  end

  def self.migrate
    require "../migrations/*"

    migrator = BlogDB.migrator(MIGRATOR_CONFIG)
    pending = migrator.pending_migrations.size

    if pending > 0
      puts "Running #{pending} pending migration(s)..."
      migrator.up
      puts "Migrations complete"
    else
      puts "Database is up to date"
    end
  end
end

# Run setup when executed directly
if PROGRAM_NAME.includes?("blog_engine")
  BlogEngine.setup
end
```

## Step 6: Create a Setup Script

Create a script for initializing and migrating the database:

```crystal
# src/setup.cr
require "./blog_engine"

puts "Setting up Blog Engine..."
puts "========================="

BlogEngine.setup
BlogEngine.migrate

puts ""
puts "Setup complete!"
```

## Step 7: Verify the Setup

Create a simple verification script:

```crystal
# src/verify.cr
require "./database"

begin
  BlogDB.init
  puts "Database connection: OK"
rescue ex
  puts "Database connection: FAILED"
  puts "Error: #{ex.message}"
  exit 1
end
```

Run the verification:

```shell
crystal src/verify.cr
```

You should see: `Database connection: OK`

## Understanding CQL Configuration Options

The configuration we created uses sensible defaults, but CQL offers many options:

| Option | Description | Our Choice |
|--------|-------------|------------|
| `adapter` | Database type | SQLite for simplicity |
| `uri` | Connection string | Local file-based database |
| `schema_file_path` | Auto-generated schema location | `src/schemas/blog_schema.cr` |
| `auto_sync` | Automatically update schema file | Enabled for development |

For production, you might use PostgreSQL:

```crystal
# Production configuration example
BlogDB = CQL::Schema.define(
  :blog_db,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
) do
end
```

## Summary

In this part, you:

1. Created a new Crystal project
2. Added CQL and database driver dependencies
3. Set up the project directory structure
4. Configured the database connection
5. Created main entry point and setup scripts
6. Verified the database connection works

## Next Steps

In [Part 2: Database Schema](02-database-schema.md), you'll design and create the database tables for users, categories, posts, and comments using CQL migrations.

---

**Tutorial Navigation:**
- Part 1: Project Setup (current)
- [Part 2: Database Schema](02-database-schema.md)
- [Part 3: Models and Relationships](03-models-and-relationships.md)
- [Part 4: CRUD Operations](04-crud-operations.md)
- [Part 5: Adding Features](05-adding-features.md)
