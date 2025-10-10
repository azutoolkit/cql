---
icon: gear
---

# Installation

Complete setup guide for CQL with PostgreSQL, MySQL, and SQLite.

## Prerequisites

**Crystal Language:** Version 1.12.2 or higher

```bash
crystal --version
```

**Database Server:** Choose one or more:

- **SQLite** - Built into most systems (development/testing)
- **PostgreSQL** - `brew install postgresql` (production recommended)
- **MySQL** - `brew install mysql` (legacy support)

## Quick Start

### 1. Create Crystal Project

```bash
crystal init app myapp
cd myapp
```

### 2. Add Dependencies

```yaml
# shard.yml
dependencies:
  cql:
    github: azutoolkit/cql
    version: "~> 0.0.435"

  # Choose your database driver
  sqlite3:
    github: crystal-lang/crystal-sqlite3
  # OR
  pg:
    github: will/crystal-pg
  # OR
  mysql:
    github: crystal-lang/crystal-mysql
```

### 3. Install and Test

```bash
shards install
```

### 4. Basic Setup

```crystal
# src/myapp.cr
require "cql"
require "sqlite3"

MyDB = CQL::Schema.define(
  :myapp,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://./app.db"
) do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String
    column :email, String
    timestamps
  end
end

struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :users

  property id : Int64?
  property name : String
  property email : String
  property created_at : Time?
  property updated_at : Time?
end

MyDB.build
user = User.create!(name: "Alice", email: "alice@example.com")
puts "Created user: #{user.name}"
```

```bash
crystal run src/myapp.cr
```

## Database-Specific Setup

### PostgreSQL Configuration

```crystal
# Production setup
AppDB = CQL::Schema.define(
  :production_db,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]? || "postgresql://username:password@localhost:5432/myapp_production",
  pool_size: 20,
  checkout_timeout: 10.seconds
) do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String, size: 100, null: false
    column :email, String, size: 255, null: false
    column :active, Bool, default: true
    timestamps

    unique_constraint [:email]
    index [:active, :created_at]
  end
end
```

**Connection Examples:**

```crystal
# Production with SSL
"postgresql://user:pass@prod-server:5432/myapp_prod?sslmode=require"

# Development
"postgresql://user:pass@localhost:5432/myapp_dev"
```

### MySQL Configuration

```crystal
AppDB = CQL::Schema.define(
  :mysql_db,
  adapter: CQL::Adapter::MySql,
  uri: ENV["DATABASE_URL"]? || "mysql://username:password@localhost:3306/myapp_development",
  pool_size: 15,
  charset: "utf8mb4"
) do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String, size: 100
    column :email, String, size: 320
    timestamps

    index [:email], unique: true
  end
end
```

### SQLite Configuration

```crystal
# Multi-environment setup
database_url = case ENV["CRYSTAL_ENV"]?
when "test"        then "sqlite3://:memory:"
when "production"  then "sqlite3://#{ENV["DATA_PATH"]? || "./"}/production.db"
else                    "sqlite3://./db/development.db"
end

AppDB = CQL::Schema.define(
  :app_db,
  adapter: CQL::Adapter::SQLite,
  uri: database_url
) do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String
    column :email, String
    timestamps

    unique_constraint [:email]
  end
end
```

## Environment Configuration

### Multi-Environment Setup

```crystal
# config/database.cr
module DatabaseConfig
  ENV_NAME = ENV["CRYSTAL_ENV"]? || "development"

  DATABASE_URLS = {
    "development" => "sqlite3://./db/development.db",
    "test"        => "sqlite3://:memory:",
    "production"  => ENV["DATABASE_URL"]? || raise("DATABASE_URL required")
  }

  def self.adapter_for(url : String)
    case url
    when .starts_with?("postgresql://") then CQL::Adapter::Postgres
    when .starts_with?("mysql://")      then CQL::Adapter::MySql
    when .starts_with?("sqlite3://")    then CQL::Adapter::SQLite
    else raise "Unsupported database URL: #{url}"
    end
  end

  POOL_SIZES = {
    "development" => 5,
    "test"        => 1,
    "production"  => 25
  }
end

database_url = DatabaseConfig::DATABASE_URLS[DatabaseConfig::ENV_NAME]
adapter = DatabaseConfig.adapter_for(database_url)
pool_size = DatabaseConfig::POOL_SIZES[DatabaseConfig::ENV_NAME]

AppDB = CQL::Schema.define(
  :app_database,
  adapter: adapter,
  uri: database_url,
  pool_size: pool_size
)
```

### File Structure

```
src/
├── config/
│   ├── database.cr
│   └── environments/
│       ├── development.cr
│       ├── test.cr
│       └── production.cr
├── models/
│   ├── user.cr
│   └── post.cr
└── myapp.cr
```

## Connection Testing

```crystal
# test_connection.cr
require "./config/database"

puts "Testing database connection..."

begin
  AppDB.build
  puts "✅ Database connection successful"
  puts "Tables: #{AppDB.tables.keys}"

  if AppDB.tables.has_key?(:users)
    user = User.create!(name: "Test", email: "test@example.com")
    puts "✅ Created test user: #{user.name}"
    user.delete!
    puts "✅ CRUD operations working"
  end
rescue ex
  puts "❌ Connection failed: #{ex.message}"
  exit 1
end
```

## Docker Development

```yaml
# docker-compose.yml
version: "3.8"
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: password
      POSTGRES_DB: myapp_development
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: password
      MYSQL_DATABASE: myapp_development
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql

volumes:
  postgres_data:
  mysql_data:
```

```bash
docker-compose up -d postgres
# Use: postgresql://postgres:password@localhost:5432/myapp_development
```

## Troubleshooting

**Connection Issues:**

- Verify database server is running
- Check connection string format
- Confirm database exists
- Verify user permissions

**Dependencies:**

```bash
# Reinstall dependencies
rm -rf lib/ shard.lock
shards install
```

**Common Errors:**

- `Database not found` - Create database first
- `Permission denied` - Check user privileges
- `Connection refused` - Verify server is running

## Next Steps

- [Configuration Guide](guides/configuration.md) - Environment-specific setup
- [Getting Started](guides/getting-started.md) - Build your first app
- [Schema Design](core-concepts/schemas.md) - Design your database
