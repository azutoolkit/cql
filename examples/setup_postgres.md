# PostgreSQL Setup for CQL Schema Migration Example

This guide helps you set up PostgreSQL to run the schema migration workflow example.

## Prerequisites

1. **PostgreSQL installed** on your system
2. **Crystal** with the `pg` shard available
3. **Database connection** configured

## Quick Setup

### 1. Install PostgreSQL

**macOS (with Homebrew):**

```bash
brew install postgresql
brew services start postgresql
```

**Ubuntu/Debian:**

```bash
sudo apt-get install postgresql postgresql-contrib
sudo systemctl start postgresql
```

**Windows:**
Download and install from https://www.postgresql.org/download/windows/

### 2. Create Database

```bash
# Create a database for the example
createdb cql_example_db

# Or if you need to specify a user:
createdb -U postgres cql_example_db
```

### 3. Set Environment Variable

**Option A: Use default local connection**

```bash
export DATABASE_URL="postgresql://localhost/cql_example_db"
```

**Option B: With username/password**

```bash
export DATABASE_URL="postgresql://username:password@localhost/cql_example_db"
```

**Option C: Full connection string**

```bash
export DATABASE_URL="postgresql://username:password@host:5432/database_name"
```

### 4. Verify Connection

Test your connection:

```bash
psql $DATABASE_URL -c "SELECT version();"
```

## Running the Example

### Install Dependencies

```bash
cd /path/to/cql
shards install
```

### Run the Schema Migration Example

```bash
crystal examples/schema_migration_workflow.cr
```

## Environment-Specific Configurations

### Development

```bash
export DATABASE_URL="postgresql://localhost/myapp_development"
```

### Test

```bash
export DATABASE_URL="postgresql://localhost/myapp_test"
```

### Production

```bash
export DATABASE_URL="postgresql://user:pass@prod-host:5432/myapp_production"
```

## Troubleshooting

### Connection Issues

**Error: `connection refused`**

- Ensure PostgreSQL is running: `brew services list | grep postgresql`
- Start if needed: `brew services start postgresql`

**Error: `database does not exist`**

- Create the database: `createdb cql_example_db`

**Error: `authentication failed`**

- Check your username/password in DATABASE_URL
- Use `psql` to test authentication manually

**Error: `role does not exist`**

- Create a PostgreSQL user:

```bash
createuser -s your_username
```

### Permission Issues

**Error: `permission denied`**

- Ensure your user has access to the database:

```sql
-- Connect as postgres superuser
psql -U postgres
-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE cql_example_db TO your_username;
```

### Crystal/Shard Issues

**Error: `pg shard not found`**

```bash
# Make sure pg dependency is in shard.yml and install
shards install
```

## Expected Output

When the example runs successfully, you should see:

```
🚀 CQL Schema Migration Workflow Demonstration
==================================================

🗃️  Setting up fresh PostgreSQL database...

📊 Initial Migration Status:
Pending migrations:
  ⏱ create_users_table (version 1)
  ⏱ add_email_index (version 2)
  ⏱ create_posts_table (version 3)
  ⏱ add_published_to_posts (version 4)

⬆️  Applying all migrations...
This will automatically update the schema file after each migration.
📄 Migration 1: Creating users table...
📄 Migration 2: Adding email index...
📄 Migration 3: Creating posts table...
📄 Migration 4: Adding published column to posts...

📊 Migration Status After Up:
Applied migrations:
  ✔ create_users_table (version 1)
  ✔ add_email_index (version 2)
  ✔ create_posts_table (version 3)
  ✔ add_published_to_posts (version 4)

📁 Generated Schema File:
File: examples/generated_app_schema.cr
----------------------------------------
[Generated schema content with PostgreSQL-specific types]
----------------------------------------

✅ Verifying Schema Consistency:
Schema is consistent with database: true

[... rest of demonstration ...]
```

## Clean Up

The example automatically cleans up after itself, but you can manually clean up:

```bash
# Drop the example database
dropdb cql_example_db

# Remove generated schema file
rm examples/generated_app_schema.cr
```

## Notes

- The example uses PostgreSQL-specific features like JSONB and advanced column types
- Foreign key constraints work properly with PostgreSQL (unlike SQLite limitations)
- The generated schema file will show PostgreSQL column types (INTEGER, VARCHAR, TIMESTAMP, etc.)
- Schema synchronization works the same way regardless of database adapter
