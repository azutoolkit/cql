# Fix Connection Errors

This guide helps you diagnose and fix database connection errors.

## Common Error: Connection Refused

**Error:**
```
Connection refused (localhost:5432)
```

**Causes:**
- Database server not running
- Wrong host or port
- Firewall blocking connection

**Solutions:**

1. Check if database is running:
```shell
# PostgreSQL
pg_isready -h localhost -p 5432

# MySQL
mysqladmin -h localhost -u root ping
```

2. Start the database:
```shell
# PostgreSQL (macOS with Homebrew)
brew services start postgresql

# PostgreSQL (Linux)
sudo systemctl start postgresql

# MySQL
sudo systemctl start mysql
```

3. Verify connection string:
```crystal
# Check your URL format
DATABASE_URL = "postgres://localhost:5432/myapp"  # Port is correct?
```

## Common Error: Authentication Failed

**Error:**
```
password authentication failed for user "myuser"
```

**Solutions:**

1. Verify credentials:
```crystal
# Check username and password
DATABASE_URL = "postgres://username:password@localhost/myapp"
```

2. Reset password (PostgreSQL):
```shell
psql -U postgres
ALTER USER myuser WITH PASSWORD 'newpassword';
```

3. Check pg_hba.conf for authentication method

## Common Error: Database Does Not Exist

**Error:**
```
database "myapp_development" does not exist
```

**Solutions:**

1. Create the database:
```shell
# PostgreSQL
createdb myapp_development

# Or in psql
psql -U postgres -c "CREATE DATABASE myapp_development"
```

2. For SQLite, ensure directory exists:
```crystal
Dir.mkdir_p("./db") unless Dir.exists?("./db")
```

## Common Error: Too Many Connections

**Error:**
```
too many connections for role "myuser"
```

**Solutions:**

1. Close unused connections
2. Increase connection limit:
```sql
ALTER ROLE myuser CONNECTION LIMIT 100;
```

3. Use connection pooling

## Common Error: SSL Required

**Error:**
```
SSL connection is required
```

**Solutions:**

Add SSL mode to connection string:
```crystal
DATABASE_URL = "postgres://user:pass@host/db?sslmode=require"
```

## Debugging Connection Issues

```crystal
begin
  MyDB.init
  puts "Connection successful"
rescue ex
  puts "Connection failed"
  puts "Error type: #{ex.class}"
  puts "Message: #{ex.message}"

  # Print sanitized connection string
  puts "URL: #{DATABASE_URL.gsub(/:[^:@]+@/, ":****@")}"
end
```

## Test Connection Script

```crystal
# scripts/test_connection.cr
require "cql"
require "pg"

url = ARGV[0]? || ENV["DATABASE_URL"]? || "postgres://localhost/myapp"

puts "Testing connection to: #{url.gsub(/:[^:@]+@/, ":****@")}"

begin
  db = CQL::Schema.define(:test, adapter: CQL::Adapter::Postgres, uri: url) do
  end
  db.init
  db.exec("SELECT 1")
  puts "Connection successful!"
rescue ex
  puts "Connection failed: #{ex.message}"
  exit 1
end
```

Run:
```shell
crystal scripts/test_connection.cr
```

## Check Network Connectivity

```shell
# Test if host is reachable
ping database-host.example.com

# Test if port is open
nc -zv localhost 5432
```

## Related

- [Configure Database Connection](../configuration/database-connection.md)
- [Fix Migration Errors](migration-errors.md)
- [Enable SSL Connections](../configuration/ssl.md)
