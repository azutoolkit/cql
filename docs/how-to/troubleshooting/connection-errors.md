# Fix Connection Errors

This guide helps you diagnose and fix database connection errors.

## How Errors Surface

With the native PostgreSQL driver (the default for `postgres://` and `postgresql://` URLs), failures are raised as `CQL::Postgres` errors, all subclasses of `CQL::Error`; server errors are `CQL::Postgres::ServerError`, which carries `sqlstate` and a message such as `FATAL: password authentication failed for user "myuser" (SQLSTATE 28P01)`. Messages for most SQLSTATE classes use a fixed title instead of the server's wording, because the server's text can quote bound values. Connect failures at pool level are reported by crystal-db as `DB::ConnectionRefused` after `retry_attempts`. The native driver is described in the [native PostgreSQL driver guide](../postgres-native/README.md); CockroachDB URLs (`cockroachdb://`) are covered in [CockroachDB](../configuration/cockroachdb.md).

| Exception | Meaning |
|-----------|---------|
| `DB::ConnectionRefused` | TCP/TLS failure while opening a connection (retried by the pool) |
| `CQL::Postgres::AuthenticationError` | Client could not finish authentication (no password configured, unsupported method) |
| `CQL::Postgres::TLSRefused` | Server refused or failed TLS while `sslmode` requires it |
| `CQL::Postgres::ConnectionLost` | Socket failed or was already closed |
| `CQL::Postgres::PoolTimeout` | No pooled connection became free in `checkout_timeout` (native `AsyncEngine` pool) |
| `DB::PoolTimeout` | Same, for `CQL::Schema`'s crystal-db pool |
| `CQL::Schema::InvalidURIError` | Malformed or unsupported URI, raised by `Schema.define` |

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

3. Use connection pooling and cap it below the server limit (`max_pool_size`, see [Set Up Connection Pooling](../configuration/connection-pooling.md))

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

The native driver supports `disable`, `prefer`, `require` and `verify-full`; other values raise `ArgumentError`. See [Enable SSL Connections](../configuration/ssl.md).

## Common Error: Unsupported URL Option

**Error:**
```
ArgumentError: the sslcert option is not supported by this driver
```

The native driver rejects libpq-only options (`sslcert`, `sslkey`, `target_session_attrs`, ...) instead of ignoring them, and `user`, `database`, `password` and similar cannot be set through the query string. Put credentials in the URL's userinfo.

## Debugging Connection Issues

```crystal
begin
  MyDB.exec_query(&.scalar("SELECT 1"))
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

url = ARGV[0]? || ENV["DATABASE_URL"]? || "postgres://localhost/myapp"

puts "Testing connection to: #{url.gsub(/:[^:@]+@/, ":****@")}"

begin
  db = CQL::Schema.define(:test, adapter: CQL::Adapter::Postgres, uri: url) do
  end
  db.exec_query(&.scalar("SELECT 1"))
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
