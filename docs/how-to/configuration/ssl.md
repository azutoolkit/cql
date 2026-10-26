# Enable SSL Connections

Encrypt and verify PostgreSQL and CockroachDB connections with `config.ssl` or `sslmode` in the URL.

## Configure SSL with `CQL.configure`

```crystal
CQL.configure do |config|
  config.db = ENV["DATABASE_URL"]
  config.ssl.mode = "verify-full"
  config.ssl.ca_path = ENV["SSL_CA_PATH"] # e.g. /etc/ssl/certs/db-ca.crt
end

AppDB = CQL.build_schema(:app) do
end

puts CQL.config.full_db_url # ...&sslmode=verify-full&sslrootcert=%2Fetc%2Fssl%2Fcerts%2Fdb-ca.crt&...
```

| `config.ssl.*` | Default | PostgreSQL / CockroachDB parameter | MySQL parameter |
|---|---|---|---|
| `mode` | `prefer` (`require` in production) | `sslmode` | `sslmode` |
| `ca_path` | none | `sslrootcert` | `sslca` |
| `cert_path` | none | `sslcert` | `sslcert` |
| `key_path` | none | `sslkey` | `sslkey` |

`mode` is always sent; the paths only when set. SQLite gets no SSL parameters, and a `sslmode` already in `config.db` wins over `ssl.mode`.

## Pick a mode the native driver accepts

```crystal
# sslmode       native driver behavior
# disable       plaintext
# prefer        TLS when the server offers it, else plaintext; the certificate is not checked (default)
# require       TLS or fail; the certificate is not checked (like libpq)
# verify-full   TLS with the chain and host name checked; sslrootcert adds a CA to the system ones
```

`CQL.configure` accepts all six libpq modes, but `CQL.build_schema` then fails on the URLs the native driver refuses:

```crystal
# ❌ ArgumentError: unsupported sslmode "verify-ca" (use disable, prefer, require or verify-full)
CQL.configure { |config| config.ssl.mode = "verify-ca" } # same for "allow"

# ❌ ArgumentError: sslrootcert needs sslmode=verify-full; other modes do not verify the server
CQL.configure { |config| config.ssl.mode = "require"; config.ssl.ca_path = "/certs/ca.crt" }

# ❌ ArgumentError: the sslcert option is not supported by this driver (no client certificates)
CQL.configure { |config| config.ssl.cert_path = "/certs/client.crt" }

# ✅
CQL.configure { |config| config.ssl.mode = "verify-full"; config.ssl.ca_path = "/certs/ca.crt" }
```

## Put SSL in a `Schema.define` URI

`CQL::Schema.define` ignores `CQL.config`, so SSL is whatever the URI says:

```crystal
AppDB = CQL::Schema.define(
  :app,
  adapter: CQL::Adapter::Postgres,
  uri: "postgres://app:secret@db.internal/app?sslmode=verify-full&sslrootcert=/path/to/ca.crt"
) do
end

# AWS RDS: verify against the RDS CA bundle you downloaded
rds = "postgres://app:secret@mydb.abc123.us-east-1.rds.amazonaws.com/app?sslmode=verify-full&sslrootcert=/certs/rds-ca-bundle.pem"

# A DATABASE_URL without sslmode uses prefer: encrypted when offered, never verified
```

`cockroachdb://` URLs take the same parameters; see [Use CockroachDB](cockroachdb.md).

## Check that the connection is encrypted

```crystal
# SHOW ssl reports the server setting; pg_stat_ssl reports this connection
encrypted = AppDB.exec_query(&.scalar("SELECT ssl FROM pg_stat_ssl WHERE pid = pg_backend_pid()"))
puts "Connection encrypted: #{encrypted}" # => true
```

## Fix TLS errors

```text
CQL::Postgres::TLSRefused: db.internal:5432 does not support TLS, which the sslmode requires
CQL::Postgres::TLSRefused: TLS to db.internal:5432 failed: <OpenSSL reason>
```

The first means the server has TLS off while `sslmode` is `require` or `verify-full`: enable `ssl` on the server, or use `prefer` where plaintext is acceptable. The second is a failed handshake or certificate check: check `sslrootcert`, the certificate's host name and its expiry.

{% hint style="warning" %}
The crystal-mysql shard in `lib/` (0.16.0) has no TLS support and ignores `sslmode` and `sslca`, so MySQL connections stay unencrypted whatever `config.ssl` says.
{% endhint %}

## See Also

- [Configure CQL](configure-cql.md)
- [Configuration reference](../../reference/configuration.md)
- [Configure Database Connection](database-connection.md)
- [TLS, poolers and timeouts](../postgres-native/tls-and-poolers.md#tls)
- [Fix Connection Errors](../troubleshooting/connection-errors.md)
