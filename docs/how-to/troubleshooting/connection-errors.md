---
description: "Find the connection error CQL printed, then apply its fix."
---

# Fix Connection Errors

## Know where errors come from

```crystal
begin
  db = CQL.build_schema(:app) { }
rescue ex : DB::ConnectionRefused                # could not open a connection (TCP, DNS, SQLite file)
rescue ex : DB::PoolTimeout                      # no pooled connection free within checkout_timeout
rescue ex : CQL::Postgres::TLSRefused            # TLS was required and could not be had
rescue ex : CQL::Postgres::AuthenticationError   # the driver could not finish authenticating
rescue ex : CQL::Postgres::ServerError           # the server refused; ex.sqlstate, message ends in (SQLSTATE xxxxx)
rescue ex : CQL::Schema::InvalidURIError         # malformed URI
rescue ex : ArgumentError                        # invalid setting or URL option
end
```

A schema opens its first connection when it is built, so most of these raise from `CQL.build_schema` or `Schema.define`. A `cql.postgres` warning naming the cause is logged before a refused PostgreSQL connection.

## Connection refused

```text
DB::ConnectionRefused: cannot connect to localhost:5432: Error connecting to 'localhost:5432': Connection refused
```

**Cause:** nothing listens on that host and port. A URL without a host (`postgres:///app`) means `PGHOST`; `CQL::Schema` raises `Missing host in PostgreSQL URI` when neither it nor `?host=` is set.

```bash
pg_isready -h localhost -p 5432   # is the server up?
nc -zv db.internal 5432           # is the port reachable from here?
```

## SQLite file cannot be opened

```text
DB::ConnectionRefused:
```

**Cause:** SQLite raised while opening the file, usually because its directory does not exist. The message is empty.

```crystal
Dir.mkdir_p("./db")
```

## Password authentication failed

```text
CQL::Postgres::InvalidAuthorization: FATAL: password authentication failed for user "app" (SQLSTATE 28P01)
CQL::Postgres::AuthenticationError: the server requested a password but none was configured
```

**Cause:** wrong credentials, or no password in the URL or `PGPASSWORD`. Put credentials in the URL's userinfo and percent-encode reserved characters (`+` as `%2B`, `@` as `%40`); `?user=` and `?password=` are rejected.

```crystal
CQL.configure { |c| c.db = "postgres://app:s3cr%2Bt@db.internal/app" }
```

## Database does not exist

```text
CQL::Postgres::ServerError: FATAL: database "myapp_development" does not exist (SQLSTATE 3D000)
```

```bash
createdb myapp_development
```

## Too many connections

```text
CQL::Postgres::ServerError: FATAL: too many connections for role "app" (SQLSTATE 53300)
```

**Cause:** every process opens up to `max_pool_size` connections. Keep processes × `pool_size` below the role's or server's limit, or raise the limit:

```sql
ALTER ROLE app CONNECTION LIMIT 100;
```

## Pool timeout

```text
DB::PoolTimeout: Could not check out a connection in 10.0 seconds
```

**Cause:** all `max_pool_size` connections are checked out, often by code that holds one connection while asking for another. See [Fix checkout timeouts](../configuration/connection-pooling.md#fix-checkout-timeouts).

## Server requires TLS

```text
CQL::Postgres::InvalidAuthorization: FATAL: no pg_hba.conf entry for host "10.0.0.5", user "app", database "app", no encryption (SQLSTATE 28000)
CQL::Postgres::TLSRefused: db.internal:5432 does not support TLS, which the sslmode requires
```

**Cause:** the first is a server that accepts only TLS and a connection without it (`sslmode=disable`); the second is the reverse. Set `sslmode` to match the server; see [Enable SSL Connections](../configuration/ssl.md).

## Unsupported URL option

```text
ArgumentError: unsupported sslmode "verify-ca" (use disable, prefer, require or verify-full)
ArgumentError: the sslcert option is not supported by this driver
ArgumentError: the target_session_attrs option is not supported by this driver
ArgumentError: user cannot be set through the URL query
```

**Cause:** the native PostgreSQL driver rejects libpq options it does not implement instead of ignoring them. Remove the option.

## Malformed URL

```text
ArgumentError: Unsupported database URL: redis://localhost:6379         (CQL.configure)
CQL::Schema::InvalidURIError: Unsupported database type: redis           (Schema.define)
CQL::Schema::InvalidURIError: Missing host in CockroachDB URI            (also MySQL, and PostgreSQL without PGHOST or ?host=)
CQL::Schema::InvalidURIError: Invalid database URI format                (no scheme, e.g. localhost/app)
URI::Error: Invalid URI: bad port at character 11                        (sqlite3://:memory:)
```

Use one of the schemes in [Configure Database Connection](../configuration/database-connection.md) and a file URL for SQLite.

## Check a connection from the command line

Run `crystal run scripts/check_connection.cr -- postgres://app:secret@db.internal/app` to print the error class and
message for a URL.

<details>
<summary>scripts/check_connection.cr</summary>

{% code title="scripts/check_connection.cr" %}
```crystal
require "cql"

url = ARGV[0]? || ENV["DATABASE_URL"]? || "postgres://localhost/myapp"
puts "Connecting to #{url.gsub(/:[^:@\/]+@/, ":****@")}"

begin
  db = CQL::Schema.define(:check, adapter: CQL::Adapter::Postgres, uri: url) do
  end
  db.exec_query(&.scalar("SELECT 1"))
  puts "Connected"
rescue ex
  puts "#{ex.class}: #{ex.message}"
  exit 1
end
```
{% endcode %}

</details>

## See Also

- [Configure Database Connection](../configuration/database-connection.md)
- [Set Up Connection Pooling](../configuration/connection-pooling.md)
- [Enable SSL Connections](../configuration/ssl.md)
- [Use CockroachDB](../configuration/cockroachdb.md)
- [Native PostgreSQL driver](../postgres-native/README.md)
- [Fix Migration Errors](migration-errors.md)
