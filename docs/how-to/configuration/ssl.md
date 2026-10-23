# Enable SSL Connections

Configure SSL/TLS for secure database connections.

## Prerequisites

- CQL installed
- Database server with SSL enabled
- SSL certificates (if using certificate verification)

## Configure SSL with `CQL.configure`

`CQL.configure` is the entrypoint. The `config.ssl` object holds the settings, and `CQL.build_schema` adds them to the connection URL:

```crystal
CQL.configure do |config|
  config.db = ENV["DATABASE_URL"]
  config.ssl.mode = "verify-full"
  config.ssl.ca_path = ENV["SSL_CA_PATH"]
end

MyDB = CQL.build_schema(:my_db) do
end

puts CQL.config.full_db_url   # ...&sslmode=verify-full&sslrootcert=/path/to/ca.crt
```

| `config.ssl.*` | Default | URL parameter (PostgreSQL, CockroachDB) | URL parameter (MySQL) |
|----------------|---------|------------------------------------------|-----------------------|
| `mode` | `prefer` | `sslmode` | `sslmode` |
| `ca_path` | none | `sslrootcert` | `sslca` |
| `cert_path` | none | `sslcert` | `sslcert` |
| `key_path` | none | `sslkey` | `sslkey` |

Only `mode` is always sent; the paths are added when set. SQLite gets no SSL parameters. Production defaults to `ssl.mode = "require"` (see [Configure Multiple Environments](environments.md)). A `sslmode` already in `config.db` wins over `ssl.mode`.

`CQL.configure` accepts `disable`, `allow`, `prefer`, `require`, `verify-ca` and `verify-full`, and raises `ArgumentError` for anything else. That list is wider than what the native PostgreSQL driver supports (see [SSL Modes](#ssl-modes)): `allow` and `verify-ca` pass `CQL.configure` but the native driver then refuses the URL. Likewise `cert_path` and `key_path` add `sslcert`/`sslkey`, which the native driver rejects. `ssl.mode` is always sent, so set `ssl.mode = "verify-full"` whenever you set `ca_path`: the native driver rejects `sslrootcert` with any other mode.

The crystal-mysql version in `lib/` has no TLS code and does not read these parameters, so for MySQL they do not encrypt the connection. Check the shard version you use before relying on MySQL SSL.

For the full lifecycle see [Configure CQL](configure-cql.md) and the [configuration reference](../../reference/configuration.md).

## Low-Level: SSL in the URI with `Schema.define`

`CQL::Schema.define` ignores `CQL.config`, so SSL is whatever you put in the URI. The sections below show the URI parameters, which are the same ones `config.ssl` produces.

### PostgreSQL SSL

#### Basic SSL

Enable SSL in your connection URL. `postgres://` URLs are handled by CQL's native driver (see the [native PostgreSQL driver guide](../postgres-native/README.md)); `cockroachdb://` URLs take the same parameters (see [CockroachDB](cockroachdb.md)):

```crystal
MyDB = CQL::Schema.define(
  :my_db,
  adapter: CQL::Adapter::Postgres,
  uri: "postgres://user:pass@host/db?sslmode=require"
) do
end
```

#### SSL Modes

The native driver accepts four modes (default `prefer`):

| Mode | Description |
|------|-------------|
| `disable` | No SSL |
| `prefer` | Try SSL first, then non-SSL; encrypts without verifying the server |
| `require` | SSL required; encrypts without verifying the server (like libpq) |
| `verify-full` | SSL required, verify certificate chain and hostname |

`allow` and `verify-ca` are rejected with an `ArgumentError`. `CQL.configure`'s `ssl.mode` validator still accepts them, but a native-driver URL built from it will not connect, so stick to the four modes above.

#### With Certificate Verification

`sslrootcert` is only accepted with `sslmode=verify-full`, and adds your CA to the system trust store. Client certificate options (`sslcert`, `sslkey`, `sslcrl`, ...) are not supported by the native driver and raise `ArgumentError` rather than being ignored:

```crystal
uri = "postgres://user:pass@host/db?" + {
  "sslmode"     => "verify-full",
  "sslrootcert" => "/path/to/ca.crt"
}.map { |k, v| "#{k}=#{v}" }.join("&")

MyDB = CQL::Schema.define(:my_db, adapter: CQL::Adapter::Postgres, uri: uri) do
end
```

### MySQL SSL

The crystal-mysql version in `lib/` does not read these parameters (it has no TLS handling), so verify your driver version supports them.

```crystal
uri = "mysql://user:pass@host/db?" + {
  "ssl-mode" => "REQUIRED",
  "ssl-ca"   => "/path/to/ca.pem"
}.map { |k, v| "#{k}=#{v}" }.join("&")

MyDB = CQL::Schema.define(:my_db, adapter: CQL::Adapter::MySql, uri: uri) do
end
```

### Environment Variables

Store certificates securely:

```crystal
uri = "postgres://#{ENV["DB_USER"]}:#{ENV["DB_PASS"]}@#{ENV["DB_HOST"]}/#{ENV["DB_NAME"]}?" +
      "sslmode=verify-full&" +
      "sslrootcert=#{ENV["SSL_CA_PATH"]}"
```

## Verify SSL Connection

Test that SSL is working:

```crystal
# PostgreSQL: `SHOW ssl` reflects the server setting, not this connection;
# pg_stat_ssl reports whether the current connection is encrypted.
encrypted = MyDB.exec_query(&.scalar("SELECT ssl FROM pg_stat_ssl WHERE pid = pg_backend_pid()"))
puts "Connection encrypted: #{encrypted}"
```

## Cloud Database SSL

### AWS RDS

```crystal
uri = "postgres://user:pass@rds-host.amazonaws.com/db?sslmode=verify-full&sslrootcert=/path/to/rds-ca-2019-root.pem"
```

### Heroku

Heroku manages SSL automatically:

```crystal
MyDB = CQL::Schema.define(:my_db, adapter: CQL::Adapter::Postgres, uri: ENV["DATABASE_URL"]) do
end
```

## Troubleshooting

**Certificate verification failed:**
- Check certificate paths are correct
- Verify CA certificate matches server
- Check certificate expiration

**Connection refused:**
- Verify server has SSL enabled
- Check firewall allows SSL port
- Try `sslmode=require` first
- A `CQL::Postgres::TLSRefused` error means the server refused TLS while `sslmode` demanded it

## See Also

- [Configure CQL](configure-cql.md)
- [Configuration reference](../../reference/configuration.md)
- [Configure Database Connection](database-connection.md)
- [Configure Multiple Environments](environments.md)
- [Fix Connection Errors](../troubleshooting/connection-errors.md)
