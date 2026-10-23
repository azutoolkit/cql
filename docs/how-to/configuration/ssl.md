# Enable SSL Connections

Configure SSL/TLS for secure database connections.

## Prerequisites

- CQL installed and configured
- Database server with SSL enabled
- SSL certificates (if using certificate verification)

## PostgreSQL SSL

### Basic SSL

Enable SSL in your connection URL. `postgres://` URLs are handled by CQL's native driver (see the [native PostgreSQL driver guide](../postgres-native/README.md)); `cockroachdb://` URLs take the same parameters (see [CockroachDB](cockroachdb.md)):

```crystal
MyDB = CQL::Schema.define(
  :my_db,
  adapter: CQL::Adapter::Postgres,
  uri: "postgres://user:pass@host/db?sslmode=require"
) do
end
```

### SSL Modes

The native driver accepts four modes (default `prefer`):

| Mode | Description |
|------|-------------|
| `disable` | No SSL |
| `prefer` | Try SSL first, then non-SSL; encrypts without verifying the server |
| `require` | SSL required; encrypts without verifying the server (like libpq) |
| `verify-full` | SSL required, verify certificate chain and hostname |

`allow` and `verify-ca` are rejected with an `ArgumentError`. `CQL.configure`'s `ssl.mode` validator accepts them, but a native-driver URL built from it will not connect, so stick to the four modes above.

### With Certificate Verification

`sslrootcert` is only accepted with `sslmode=verify-full`, and adds your CA to the system trust store. Client certificate options (`sslcert`, `sslkey`, `sslcrl`, ...) are not supported by the native driver and raise `ArgumentError` rather than being ignored:

```crystal
uri = "postgres://user:pass@host/db?" + {
  "sslmode"     => "verify-full",
  "sslrootcert" => "/path/to/ca.crt"
}.map { |k, v| "#{k}=#{v}" }.join("&")

MyDB = CQL::Schema.define(:my_db, adapter: CQL::Adapter::Postgres, uri: uri) do
end
```

## MySQL SSL

```crystal
uri = "mysql://user:pass@host/db?" + {
  "ssl-mode" => "REQUIRED",
  "ssl-ca"   => "/path/to/ca.pem"
}.map { |k, v| "#{k}=#{v}" }.join("&")

MyDB = CQL::Schema.define(:my_db, adapter: CQL::Adapter::MySql, uri: uri) do
end
```

## Environment Variables

Store certificates securely:

```crystal
uri = "postgres://#{ENV["DB_USER"]}:#{ENV["DB_PASS"]}@#{ENV["DB_HOST"]}/#{ENV["DB_NAME"]}?" +
      "sslmode=verify-full&" +
      "sslrootcert=#{ENV["SSL_CA_PATH"]}"
```

## Configure SSL with `CQL.configure`

```crystal
CQL.configure do |config|
  config.db = ENV["DATABASE_URL"]
  config.ssl.mode = "verify-full"
  config.ssl.ca_path = ENV["SSL_CA_PATH"]
end

url = CQL.config.full_db_url   # appends sslmode and sslrootcert (sslca for MySQL)
```

`ssl.cert_path` and `ssl.key_path` add `sslcert`/`sslkey`, which the native PostgreSQL driver rejects. Production defaults to `ssl.mode = "require"`.

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

- [Configure Database Connection](database-connection.md)
- [Configure Multiple Environments](environments.md)
- [Fix Connection Errors](../troubleshooting/connection-errors.md)
