---
icon: gear
---

# ⚙️ Installation Guide

> **Get CQL up and running** - Complete setup guide for Crystal Query Language with PostgreSQL, MySQL, and SQLite

Welcome to CQL! This comprehensive installation guide will walk you through setting up CQL (Crystal Query Language) in your Crystal project. Whether you're building a new application or adding CQL to an existing project, we'll get you up and running quickly with type-safe, high-performance database interactions.

## 📋 Table of Contents

- [🎯 Prerequisites](#-prerequisites)
- [🚀 Quick Start](#-quick-start)
- [📦 Detailed Installation](#-detailed-installation)
- [🗄️ Database Setup](#️-database-setup)
- [🔧 Environment Configuration](#-environment-configuration)
- [✅ Verification](#-verification)
- [🐳 Docker Development Setup](#-docker-development-setup)
- [🚨 Troubleshooting](#-troubleshooting)
- [🎓 Next Steps](#-next-steps)

---

## 🎯 Prerequisites

Before installing CQL, ensure you have the following requirements:

### 💎 Crystal Language
```bash
# Check your Crystal version
crystal --version
# Required: Crystal 1.12.2 or higher
```

**Installation:**
- **macOS**: `brew install crystal`
- **Ubuntu/Debian**: Follow [Crystal installation guide](https://crystal-lang.org/install/)
- **Windows**: Use WSL with Ubuntu setup

### 🗄️ Database Server

Choose one or more databases for your project:

| Database | Recommended For | Installation |
|----------|----------------|--------------|
| **SQLite** | Development, Testing, Small Apps | Built into most systems |
| **PostgreSQL** | Production, Advanced Features | `brew install postgresql` |
| **MySQL** | Legacy Systems, Specific Requirements | `brew install mysql` |

---

## 🚀 Quick Start

### 1. **Create a New Crystal Project**
```bash
# Create new project
crystal init app myapp
cd myapp
```

### 2. **Add CQL to `shard.yml`**
```yaml
dependencies:
  cql:
    github: azutoolkit/cql
    version: "~> 0.0.266"

  # Database drivers (choose what you need)
  sqlite3:
    github: crystal-lang/crystal-sqlite3
```

### 3. **Install Dependencies**
```bash
shards install
```

### 4. **Create Basic Setup**
```crystal
# src/myapp.cr
require "cql"
require "sqlite3"

# Define schema
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

# Create model
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :users

  property id : Int64?
  property name : String
  property email : String
  property created_at : Time?
  property updated_at : Time?
end

# Initialize database
MyDB.build

# Test it!
user = User.create!(name: "Alice", email: "alice@example.com")
puts "✅ CQL is working! Created user: #{user.name}"
```

### 5. **Run Your Application**
```bash
crystal run src/myapp.cr
# Output: ✅ CQL is working! Created user: Alice
```

---

## 📦 Detailed Installation

### Step 1: Configure Dependencies

Choose the database drivers you need for your project:

```yaml
# shard.yml
name: myapp
version: 0.1.0

dependencies:
  cql:
    github: azutoolkit/cql
    version: "~> 0.0.266"

  # 🐘 PostgreSQL (Production recommended)
  pg:
    github: will/crystal-pg
    version: "~> 0.26.0"

  # 🐬 MySQL/MariaDB
  mysql:
    github: crystal-lang/crystal-mysql
    version: "~> 0.14.0"

  # 🗃️ SQLite (Development/Testing)
  sqlite3:
    github: crystal-lang/crystal-sqlite3
    version: "~> 0.20.0"

targets:
  myapp:
    main: src/myapp.cr

crystal: ">= 1.12.2"
```

### Step 2: Install Dependencies
```bash
# Install all dependencies
shards install

# Verify installation
shards list
```

### Step 3: Require CQL and Drivers

Create a database configuration file:

```crystal
# src/config/database.cr
require "cql"

# Require only the drivers you're using
{% if flag?(:sqlite) %}
  require "sqlite3"
{% end %}

{% if flag?(:postgres) %}
  require "pg"
{% end %}

{% if flag?(:mysql) %}
  require "mysql"
{% end %}
```

### Step 4: Main Application Setup

```crystal
# src/myapp.cr
require "./config/database"

# Your application code here
puts "CQL loaded successfully!"
```

---

## 🗄️ Database Setup

### 🐘 PostgreSQL Configuration

**For Production Applications:**

```crystal
# config/database.cr
AppDB = CQL::Schema.define(
  :production_db,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]? || "postgresql://username:password@localhost:5432/myapp_production",
  pool_size: 20,
  checkout_timeout: 10.seconds,
  retry_attempts: 3
) do
  # Schema definition
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String, size: 100, null: false
    column :email, String, size: 255, null: false
    column :password_hash, String, null: false
    column :active, Bool, default: true
    column :metadata, JSON::Any, default: JSON::Any.new({} of String => JSON::Any)
    timestamps

    # Constraints and indexes
    unique_constraint [:email]
    index [:active, :created_at]
    index [:email], unique: true
  end

  table :posts do
    primary :id, Int64, auto_increment: true
    column :title, String, size: 255, null: false
    column :content, String
    column :user_id, Int64, null: false
    column :published, Bool, default: false
    column :tags, Array(String), default: [] of String
    timestamps

    # Foreign key relationships
    foreign_key :user_id, references: :users, on_delete: :cascade
    index [:user_id, :published]
    index [:published, :created_at]
  end
end
```

**Connection String Examples:**
```crystal
# Production with SSL
"postgresql://user:pass@prod-server:5432/myapp_prod?sslmode=require"

# Development
"postgresql://user:pass@localhost:5432/myapp_dev"

# With connection pooling
"postgresql://user:pass@localhost:5432/myapp?pool_size=25"
```

### 🐬 MySQL Configuration

```crystal
# config/database.cr
AppDB = CQL::Schema.define(
  :mysql_db,
  adapter: CQL::Adapter::MySql,
  uri: ENV["DATABASE_URL"]? || "mysql://username:password@localhost:3306/myapp_development",
  pool_size: 15,
  charset: "utf8mb4",
  collation: "utf8mb4_unicode_ci"
) do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String, size: 100
    column :email, String, size: 320  # Support longer emails
    column :password_hash, String, size: 255
    column :preferences, String  # JSON as text
    timestamps

    # MySQL-specific features
    index [:email], unique: true, name: "idx_users_email"
    index [:created_at], name: "idx_users_created"
  end
end
```

**Connection String Examples:**
```crystal
# Production
"mysql://user:pass@prod-server:3306/myapp_prod?charset=utf8mb4"

# Development with custom socket
"mysql://user:pass@localhost:3306/myapp_dev?socket=/tmp/mysql.sock"

# With SSL
"mysql://user:pass@localhost:3306/myapp?ssl=true&ssl_verify_cert=false"
```

### 🗃️ SQLite Configuration

**Perfect for Development and Testing:**

```crystal
# config/database.cr
case ENV["CRYSTAL_ENV"]?
when "test"
  # In-memory database for fast tests
  AppDB = CQL::Schema.define(
    :test_db,
    adapter: CQL::Adapter::SQLite,
    uri: "sqlite3://:memory:",
    pool_size: 1
  )
when "production"
  # Production SQLite (for small apps)
  AppDB = CQL::Schema.define(
    :prod_db,
    adapter: CQL::Adapter::SQLite,
    uri: "sqlite3://#{ENV["DATA_PATH"]? || "./"}/production.db",
    pool_size: 5
  )
else
  # Development
  AppDB = CQL::Schema.define(
    :dev_db,
    adapter: CQL::Adapter::SQLite,
    uri: "sqlite3://./db/development.db",
    pool_size: 1
  )
end

# Schema definition
AppDB.define_schema do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String
    column :email, String
    column :created_at, Time
    column :updated_at, Time

    # SQLite constraints
    unique_constraint [:email]
  end
end
```

**File Locations:**
```bash
# Development
./db/development.db

# Test (in-memory)
:memory:

# Production
/var/data/myapp/production.db
```

---

## 🔧 Environment Configuration

### 🌍 Multi-Environment Setup

Create a flexible configuration that adapts to different environments:

```crystal
# config/database.cr
module DatabaseConfig
  # Environment detection
  ENV_NAME = ENV["CRYSTAL_ENV"]? || "development"

  # Database URLs by environment
  DATABASE_URLS = {
    "development" => "sqlite3://./db/development.db",
    "test"        => "sqlite3://:memory:",
    "staging"     => ENV["STAGING_DATABASE_URL"]? || "postgresql://localhost:5432/myapp_staging",
    "production"  => ENV["DATABASE_URL"]? || raise("DATABASE_URL required in production")
  }

  # Adapter selection
  def self.adapter_for(url : String)
    case url
    when .starts_with?("postgresql://"), .starts_with?("postgres://")
      CQL::Adapter::Postgres
    when .starts_with?("mysql://")
      CQL::Adapter::MySql
    when .starts_with?("sqlite3://")
      CQL::Adapter::SQLite
    else
      raise "Unsupported database URL: #{url}"
    end
  end

  # Pool size by environment
  POOL_SIZES = {
    "development" => 5,
    "test"        => 1,
    "staging"     => 10,
    "production"  => 25
  }
end

# Create database instance
database_url = DatabaseConfig::DATABASE_URLS[DatabaseConfig::ENV_NAME]
adapter = DatabaseConfig.adapter_for(database_url)
pool_size = DatabaseConfig::POOL_SIZES[DatabaseConfig::ENV_NAME]

AppDB = CQL::Schema.define(
  :app_database,
  adapter: adapter,
  uri: database_url,
  pool_size: pool_size,
  checkout_timeout: 10.seconds
) do
  # Your schema definitions here
  load_schema_from_file("./config/schema.cr")
end
```

### 📁 Organized File Structure

```
src/
├── config/
│   ├── database.cr          # Main database configuration
│   ├── schema.cr            # Schema definitions
│   └── environments/
│       ├── development.cr   # Dev-specific overrides
│       ├── test.cr          # Test configuration
│       └── production.cr    # Production settings
├── models/
│   ├── user.cr
│   ├── post.cr
│   └── concerns/
│       └── timestampable.cr
└── myapp.cr
```

### 🔐 Secure Configuration

```crystal
# config/environments/production.cr
module ProductionConfig
  # Secure database configuration
  DATABASE_URL = ENV["DATABASE_URL"]? ||
    raise "DATABASE_URL environment variable is required"

  # SSL Configuration for PostgreSQL
  SSL_PARAMS = "?sslmode=require&sslcert=client-cert.pem&sslkey=client-key.pem"

  # Connection pooling for high traffic
  POOL_CONFIG = {
    pool_size: ENV["DB_POOL_SIZE"]?.try(&.to_i) || 25,
    checkout_timeout: 15.seconds,
    retry_attempts: 3,
    retry_delay: 1.second
  }

  def self.database_url
    url = DATABASE_URL
    # Add SSL params for PostgreSQL in production
    url += SSL_PARAMS if url.starts_with?("postgresql://")
    url
  end
end
```

---

## ✅ Verification

### 🧪 Basic Connection Test

Create a simple test to verify your installation:

```crystal
# test_connection.cr
require "./config/database"

# Test database connection
puts "Testing database connection..."

begin
  # Build schema (create tables)
  AppDB.build
  puts "✅ Database connection successful"
  puts "📊 Available tables: #{AppDB.tables.keys}"

  # Test basic operations
  if AppDB.tables.has_key?(:users)
    # Create a test user
    result = AppDB.insert.into(:users)
                  .values(name: "Test User", email: "test@example.com")
                  .commit

    puts "✅ Insert operation successful"

    # Query the user
    user = AppDB.query.from(:users)
                     .where(email: "test@example.com")
                     .first

    puts "✅ Query operation successful: #{user}"

    # Clean up
    AppDB.delete.from(:users).where(email: "test@example.com").commit
    puts "✅ Delete operation successful"
  end

rescue ex
  puts "❌ Database test failed: #{ex.message}"
  puts "Check your database configuration and ensure the server is running"
end
```

Run the test:
```bash
crystal run test_connection.cr
```

### 🏗️ Model Integration Test

Test with actual CQL models:

```crystal
# test_models.cr
require "./config/database"

# Define a test model
struct TestUser
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :users

  property id : Int64?
  property name : String
  property email : String
  property created_at : Time?
  property updated_at : Time?

  validates :email, presence: true, format: /@/
  validates :name, presence: true, length: {minimum: 2}
end

# Test model operations
puts "Testing CQL Active Record functionality..."

begin
  # Create
  user = TestUser.create!(
    name: "Alice Johnson",
    email: "alice@example.com"
  )
  puts "✅ User created: #{user.name} (ID: #{user.id})"

  # Read
  found_user = TestUser.find(user.id!)
  puts "✅ User found: #{found_user.try(&.name)}"

  # Update
  user.update!(name: "Alice Smith")
  puts "✅ User updated: #{user.name}"

  # Query
  users = TestUser.where(name: "Alice Smith").all
  puts "✅ Query successful: found #{users.size} user(s)"

  # Delete
  user.delete!
  puts "✅ User deleted successfully"

  puts "\n🎉 All tests passed! CQL is working correctly."

rescue ex
  puts "❌ Model test failed: #{ex.message}"
  puts "Stack trace:"
  puts ex.backtrace.join("\n")
end
```

---

## 🐳 Docker Development Setup

### 🐘 PostgreSQL with Docker

```yaml
# docker-compose.yml
version: "3.8"

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: myapp_development
      POSTGRES_USER: myapp_user
      POSTGRES_PASSWORD: myapp_password
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8 --lc-collate=C --lc-ctype=C"
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./docker/postgres/init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U myapp_user -d myapp_development"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Redis for caching (optional)
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:

networks:
  default:
    name: myapp_network
```

**Setup Commands:**
```bash
# Start services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs postgres

# Connect to database
docker-compose exec postgres psql -U myapp_user -d myapp_development

# Stop services
docker-compose down
```

### 🐬 MySQL with Docker

```yaml
# docker-compose.mysql.yml
version: "3.8"

services:
  mysql:
    image: mysql:8.0
    command: --default-authentication-plugin=mysql_native_password
    environment:
      MYSQL_ROOT_PASSWORD: root_password
      MYSQL_DATABASE: myapp_development
      MYSQL_USER: myapp_user
      MYSQL_PASSWORD: myapp_password
      MYSQL_CHARSET: utf8mb4
      MYSQL_COLLATION: utf8mb4_unicode_ci
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
      - ./docker/mysql/conf.d:/etc/mysql/conf.d
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "myapp_user", "-pmyapp_password"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  mysql_data:
```

### 🔧 Development Environment Script

```bash
#!/bin/bash
# scripts/dev-setup.sh

echo "🚀 Setting up CQL development environment..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Choose database
echo "Select database for development:"
echo "1) PostgreSQL (recommended)"
echo "2) MySQL"
echo "3) SQLite (no Docker needed)"
read -p "Enter choice (1-3): " choice

case $choice in
    1)
        echo "🐘 Setting up PostgreSQL..."
        docker-compose -f docker-compose.yml up -d postgres
        export DATABASE_URL="postgresql://myapp_user:myapp_password@localhost:5432/myapp_development"
        ;;
    2)
        echo "🐬 Setting up MySQL..."
        docker-compose -f docker-compose.mysql.yml up -d mysql
        export DATABASE_URL="mysql://myapp_user:myapp_password@localhost:3306/myapp_development"
        ;;
    3)
        echo "🗃️ Using SQLite..."
        mkdir -p db
        export DATABASE_URL="sqlite3://./db/development.db"
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

# Install dependencies
echo "📦 Installing Crystal dependencies..."
shards install

# Test connection
echo "🧪 Testing database connection..."
crystal run test_connection.cr

echo "✅ Development environment ready!"
echo "Database URL: $DATABASE_URL"
```

---

## 🚨 Troubleshooting

### 🔍 Common Issues and Solutions

#### ❌ **"Crystal version too old"**
```bash
# Error: CQL requires Crystal 1.12.2 or higher
crystal --version

# Solution: Update Crystal
brew upgrade crystal  # macOS
# or follow Crystal installation guide for your OS
```

#### ❌ **"Database driver not found"**
```bash
# Error: can't load file 'pg'
# Solution: Add database driver to shard.yml
```

```yaml
dependencies:
  pg:
    github: will/crystal-pg
```

#### ❌ **"Connection refused"**
```bash
# Error: Connection refused (Errno)
# Solution: Check if database server is running

# PostgreSQL
brew services start postgresql
# or
sudo systemctl start postgresql

# MySQL
brew services start mysql
# or
sudo systemctl start mysql
```

#### ❌ **"Permission denied"**
```sql
-- Error: permission denied for database
-- Solution: Grant proper permissions

-- PostgreSQL
CREATE USER myapp_user WITH PASSWORD 'myapp_password';
GRANT ALL PRIVILEGES ON DATABASE myapp_development TO myapp_user;
ALTER USER myapp_user CREATEDB;

-- MySQL
CREATE USER 'myapp_user'@'localhost' IDENTIFIED BY 'myapp_password';
GRANT ALL PRIVILEGES ON myapp_development.* TO 'myapp_user'@'localhost';
FLUSH PRIVILEGES;
```

#### ❌ **"Table doesn't exist"**
```crystal
# Error: relation "users" does not exist
# Solution: Build your schema first

AppDB.build  # Creates all tables

# Or create individual tables
AppDB.users.create!
```

#### ❌ **"SSL connection required"**
```crystal
# Error: SSL connection required
# Solution: Add SSL parameters to connection string

uri = "postgresql://user:pass@host:5432/db?sslmode=require"

# Or disable SSL for development
uri = "postgresql://user:pass@localhost:5432/db?sslmode=disable"
```

### 🔧 Debug Mode

Enable debug mode to see what's happening:

```crystal
# Enable SQL query logging
ENV["CQL_LOG_LEVEL"] = "DEBUG"

# Enable connection pool logging
ENV["DB_LOG_LEVEL"] = "DEBUG"

# Your CQL code here
AppDB = CQL::Schema.define(
  :debug_db,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://debug.db",
  log_level: :debug  # Enable query logging
)
```

### 📞 Getting Help

If you're still having issues:

1. **Check the [Troubleshooting Guide](troubleshooting.md)** for more detailed solutions
2. **Review [Frequently Asked Questions](faqs.md)**
3. **Search existing issues** on [GitHub](https://github.com/azutoolkit/cql/issues)
4. **Create a new issue** with:
   - Crystal version (`crystal --version`)
   - CQL version (from `shard.yml`)
   - Database type and version
   - Full error message
   - Minimal reproduction code

---

## 🎓 Next Steps

Congratulations! You now have CQL installed and configured. Here's what to explore next:

### 🏁 **Immediate Next Steps**
1. **[Getting Started Guide](guides/getting-started.md)** - Build your first CQL application
2. **[Core Concepts](core-concepts/README.md)** - Understand CQL fundamentals
3. **[Schema Definition](core-concepts/schemas.md)** - Learn to design your database structure

### 🏗️ **Build Your First App**
1. **[Define Models](guides/active-record-with-cql/defining-models.md)** - Create your data models
2. **[CRUD Operations](core-concepts/crud-operations/README.md)** - Master database interactions
3. **[Validations](guides/active-record-with-cql/validations.md)** - Add data validation rules
4. **[Relationships](guides/active-record-with-cql/relations/README.md)** - Connect your models

### 🚀 **Advanced Topics**
1. **[Migrations](core-concepts/migrations.md)** - Manage schema changes
2. **[Transactions](guides/active-record-with-cql/transactions.md)** - Ensure data consistency
3. **[Performance Optimization](guides/performance/)** - Scale your application
4. **[Testing](guides/testing/)** - Test your CQL code

### 🎯 **Quick Start Project**

Try building a simple blog application:

```crystal
# 1. Define schema
AppDB = CQL::Schema.define(:blog, adapter: CQL::Adapter::SQLite, uri: "sqlite3://blog.db") do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String
    column :email, String
    timestamps
  end

  table :posts do
    primary :id, Int64, auto_increment: true
    column :title, String
    column :content, String
    column :user_id, Int64
    timestamps
    foreign_key :user_id, references: :users
  end
end

# 2. Define models
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :users

  property id : Int64?
  property name : String
  property email : String
  property created_at : Time?
  property updated_at : Time?

  has_many :posts, Post
end

struct Post
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :posts

  property id : Int64?
  property title : String
  property content : String
  property user_id : Int64?
  property created_at : Time?
  property updated_at : Time?

  belongs_to :user, User
end

# 3. Build and use
AppDB.build

user = User.create!(name: "Alice", email: "alice@example.com")
post = user.posts.create!(title: "Hello CQL!", content: "My first post with CQL")

puts "Created post: #{post.title} by #{user.name}"
```

---

> 🎉 **You're all set!** CQL is now installed and ready to power your Crystal applications with type-safe, high-performance database interactions.

**Happy coding with CQL!** 💎
