---
icon: gear
---

# Installation

CQL is a Crystal ORM library that provides type-safe database interactions. Follow these steps to install and configure CQL in your Crystal project.

## Prerequisites

- **Crystal**: Version 1.12.2 or higher
- **Database**: PostgreSQL, MySQL, or SQLite

## Step 1: Add CQL to Your Project

Add CQL and the appropriate database driver to your `shard.yml` file:

```yaml
dependencies:
  cql:
    github: azutoolkit/cql
    version: "~> 0.0.266"

  # Choose the database driver(s) you need:

  # For PostgreSQL
  pg:
    github: will/crystal-pg

  # For MySQL
  mysql:
    github: crystal-lang/crystal-mysql

  # For SQLite
  sqlite3:
    github: crystal-lang/crystal-sqlite3
```

**Note**: You only need to include the database drivers you plan to use. For development, SQLite is often sufficient.

## Step 2: Install Dependencies

Run the following command to install all dependencies:

```bash
shards install
```

## Step 3: Require CQL in Your Application

Add the CQL require statement to your main application file:

```crystal
require "cql"

# Require the database driver(s) you're using:
require "pg"      # For PostgreSQL
require "mysql"   # For MySQL
require "sqlite3" # For SQLite
```

## Step 4: Configure Database Connection

Define your database schema with the appropriate adapter and connection URI:

### PostgreSQL Configuration

```crystal
# config/database.cr
AppDB = CQL::Schema.define(
  :app_database,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]? || "postgresql://user:password@localhost:5432/myapp_development"
) do
  # Table definitions will go here
end
```

### MySQL Configuration

```crystal
# config/database.cr
AppDB = CQL::Schema.define(
  :app_database,
  adapter: CQL::Adapter::MySql,
  uri: ENV["DATABASE_URL"]? || "mysql://user:password@localhost:3306/myapp_development"
) do
  # Table definitions will go here
end
```

### SQLite Configuration

```crystal
# config/database.cr
AppDB = CQL::Schema.define(
  :app_database,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://db/development.db"
) do
  # Table definitions will go here
end
```

## Step 5: Environment-Specific Configuration

For production applications, use environment variables for database configuration:

```crystal
# config/database.cr
database_url = case ENV["CRYSTAL_ENV"]?
when "production"
  ENV["DATABASE_URL"]
when "test"
  "sqlite3://:memory:"
else
  "sqlite3://db/development.db"
end

AppDB = CQL::Schema.define(
  :app_database,
  adapter: CQL::Adapter::SQLite,  # Change based on your production database
  uri: database_url
) do
  # Table definitions
end
```

## Step 6: Define Your Schema

Create your database schema with tables, columns, and relationships:

```crystal
# config/database.cr
AppDB = CQL::Schema.define(
  :app_database,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://db/development.db"
) do

  table :users do
    primary :id, Int32
    column :name, String
    column :email, String
    column :created_at, Time, null: true
    column :updated_at, Time, null: true
  end

  table :posts do
    primary :id, Int32
    column :title, String
    column :body, String
    column :user_id, Int32, null: true
    column :created_at, Time, null: true
    column :updated_at, Time, null: true

    foreign_key [:user_id], references: :users, references_columns: [:id]
  end
end
```

## Step 7: Create Tables

Initialize your database by creating the tables:

```crystal
# In your application or a setup script
AppDB.users.create!
AppDB.posts.create!

# Or create all tables at once
# AppDB.create_tables!
```

## Verification

Verify your installation by creating a simple model and testing the connection:

```crystal
# models/user.cr
require "./config/database"

class User
  include CQL::ActiveRecord::Model(Int32)
  db_context AppDB, :users

  property id : Int32?
  property name : String
  property email : String
  property created_at : Time?
  property updated_at : Time?

  def initialize(@name : String, @email : String)
  end
end

# Test the setup
user = User.new("John Doe", "john@example.com")
if user.save
  puts "CQL is working! User created with ID: #{user.id}"
else
  puts "Error: #{user.errors.map(&.message).join(", ")}"
end
```

## Docker Setup (Optional)

For development with PostgreSQL or MySQL, you can use Docker:

### PostgreSQL with Docker

```yaml
# docker-compose.yml
version: "3.8"
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: myapp_development
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

```bash
docker-compose up -d postgres
```

### MySQL with Docker

```yaml
# docker-compose.yml
version: "3.8"
services:
  mysql:
    image: mysql:8.0
    environment:
      MYSQL_DATABASE: myapp_development
      MYSQL_ROOT_PASSWORD: password
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql

volumes:
  mysql_data:
```

```bash
docker-compose up -d mysql
```

## Troubleshooting

### Common Issues

1. **Database Connection Errors**: Ensure your database server is running and connection details are correct.

2. **Missing Database Driver**: Make sure you've included the correct database driver in your `shard.yml`.

3. **Table Creation Errors**: Verify your schema definition syntax and ensure the database user has proper permissions.

4. **Crystal Version Compatibility**: CQL requires Crystal 1.12.2 or higher.

### Getting Help

- Check the [Troubleshooting Guide](troubleshooting.md)
- Review the [FAQs](faqs.md)
- Visit the project repository: https://github.com/azutoolkit/cql

## Next Steps

After installation:

1. Read the [Getting Started Guide](guides/getting-started.md)
2. Learn about [Schema Definition](core-concepts/schemas.md)
3. Explore [Active Record Models](guides/active-record-with-cql/defining-models.md)
4. Set up [Validations](guides/active-record-with-cql/validations.md)
5. Configure [Relationships](guides/active-record-with-cql/relations/README.md)

You're now ready to build type-safe, high-performance Crystal applications with CQL!
