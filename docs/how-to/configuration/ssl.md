# Enable SSL Connections

Configure SSL/TLS for secure database connections.

## Prerequisites

- CQL installed and configured
- Database server with SSL enabled
- SSL certificates (if using certificate verification)

## PostgreSQL SSL

### Basic SSL

Enable SSL in your connection URL:

```crystal
MyDB = CQL::Schema.define(
  :my_db,
  adapter: CQL::Adapter::Postgres,
  uri: "postgres://user:pass@host/db?sslmode=require"
) do
end
```

### SSL Modes

| Mode | Description |
|------|-------------|
| `disable` | No SSL |
| `allow` | Try non-SSL first, then SSL |
| `prefer` | Try SSL first, then non-SSL |
| `require` | SSL required, no certificate verification |
| `verify-ca` | SSL required, verify CA |
| `verify-full` | SSL required, verify CA and hostname |

### With Certificate Verification

```crystal
uri = "postgres://user:pass@host/db?" + {
  "sslmode"     => "verify-full",
  "sslcert"     => "/path/to/client.crt",
  "sslkey"      => "/path/to/client.key",
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

MyDB = CQL::Schema.define(:my_db, adapter: CQL::Adapter::MySQL, uri: uri) do
end
```

## Environment Variables

Store certificates securely:

```crystal
uri = "postgres://#{ENV["DB_USER"]}:#{ENV["DB_PASS"]}@#{ENV["DB_HOST"]}/#{ENV["DB_NAME"]}?" +
      "sslmode=verify-full&" +
      "sslcert=#{ENV["SSL_CERT_PATH"]}&" +
      "sslkey=#{ENV["SSL_KEY_PATH"]}&" +
      "sslrootcert=#{ENV["SSL_CA_PATH"]}"
```

## Verify SSL Connection

Test that SSL is working:

```crystal
# PostgreSQL
result = MyDB.exec("SHOW ssl")
puts "SSL enabled: #{result.first["ssl"]}"

# Or check connection info
MyDB.exec("SELECT pg_backend_pid()") do |rs|
  puts "Connected with SSL"
end
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

## See Also

- [Configure Database Connection](database-connection.md)
- [Configure Multiple Environments](environments.md)
- [Fix Connection Errors](../troubleshooting/connection-errors.md)
