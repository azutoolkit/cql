---
description: "Connect to MySQL 8.4 with caching_sha2_password, verified TLS and bounded authentication using CQL's optional MySQL integration."
---

# Use MySQL 8.4 with Verified TLS

CQL's optional `require "cql/mysql"` entry point supports MySQL 8.4's default
`caching_sha2_password` authentication. It adds TLS and authentication to the `mysql` shard's existing
statements, row decoding and crystal-db pool. The integration was introduced in PR #65; use a CQL revision
that includes it. Requiring only `"cql"` or `"mysql"` does not enable this integration.

## Install the driver

Add the following alongside your existing CQL dependency in `shard.yml`, then run `shards install`:

```yaml
dependencies:
  mysql:
    github: crystal-lang/crystal-mysql
    version: ~> 0.16.0
```

The validated combination uses `crystal-mysql` 0.16 and `crystal-db` 0.13. Newer mysql shard versions have
not been validated with this integration. Requiring `"cql/mysql"` loads both CQL and the mysql shard and
registers the integration for subsequent `mysql://` connections in that process.

## Connect with a private CA

Provision a MySQL account using `caching_sha2_password`, grant the privileges your application needs, and
require encrypted connections on the server or account. MySQL 8.4 does not need its legacy native-password
plugin enabled for this integration. The database must already exist.

Set `DATABASE_URL` through your application's secret configuration. For example, its shape is:

```text
mysql://app:URL_ENCODED_PASSWORD@mysql.internal:3306/app?ssl-mode=verify_identity&ssl-ca=%2Fetc%2Fapp%2Fmysql-ca.pem&connect_timeout=5
```

Mount the trusted CA's PEM certificate at `/etc/app/mysql-ca.pem`. The URL hostname must match the server
certificate's subject alternative name (SAN). An IP address needs a matching IP SAN. Omit `ssl-ca` when the
server certificate chains to a CA in the system trust store. URL-encode credentials and query parameter values;
do not print the resulting URL in logs.

```crystal
require "cql"
require "cql/mysql"

CQL.configure do |config|
  config.db = ENV["DATABASE_URL"]
  config.pool_size = 10
end

AppDB = CQL.build_schema(:app) do
end

AppDB.exec_query do |connection|
  puts connection.query_one("SELECT 1", as: Int64)
end
```

`CQL.build_schema` opens `config.full_db_url`, preserving the URL's driver options. Use the MySQL-specific
`ssl-mode` and `ssl-ca` keys in the URL or `config.adapter_options`. For MySQL, the shared `config.ssl` settings emit
`sslmode` and `sslca` parameters; those do not configure this MySQL integration.

## Connection options

| URL parameter | Default | Meaning |
| --- | --- | --- |
| `ssl-mode` | `verify_identity` | Requires encryption, a trusted CA and a matching hostname. No fallback to plaintext. |
| `ssl-ca` | System trust store | Path to a PEM CA file for server verification. |
| `connect_timeout` | `5` seconds | Positive number of seconds, at most `300`; fractional values such as `0.5` are accepted. Invalid or nonpositive values raise `ArgumentError`. |
| `encoding` | `utf8mb4_unicode_ci` | Collation resolved by the mysql shard. |
| `max_pool_size` | crystal-db pool default | Maximum connections when using `DB.open`; CQL's `config.pool_size` also supplies this parameter. |

`ssl-mode=required` encrypts traffic without verifying the server's identity. It is not equivalent to
`verify_identity`. `ssl-mode=disabled` explicitly permits plaintext. Neither mode is needed for the verified
setup above. Unsupported modes, including `preferred` and `verify_ca`, raise `ArgumentError`.

Use separate budgets for connection establishment, waiting for a pool lease and executing SQL:

- `connect_timeout` bounds authentication, including TLS negotiation and servers that trickle handshake bytes.
  The authentication deadline is measured from before TCP connection establishment; authentication gets the
  remaining budget. Expiry closes the socket. DNS resolution and TCP connection attempts also receive timeouts;
  this is not an end-to-end deadline covering pool retries or application work.
- `checkout_timeout` is the crystal-db pool setting for waiting to acquire a connection. See
  [Set Up Connection Pooling](connection-pooling.md).
- Authentication clears its socket read/write timeouts after success. `connect_timeout` does not bound SQL
  execution, transaction duration or a long-running result stream. Configure workload-appropriate execution
  limits separately; CQL's native PostgreSQL timeout settings do not apply to this driver.

## Authentication behavior and limits

The integration handles both the cached and full `caching_sha2_password` exchanges, including one server-requested
switch between supported plugins. Full authentication sends the password only inside TLS. A plaintext connection
may appear to work while the server's authentication cache is warm, then fail when that cache is cleared;
use verified TLS for reliable cold and warm connections.

Legacy `mysql_native_password` is supported for compatible servers, but CQL does not enable that plugin or change
server authentication policy. RSA public-key retrieval, other authentication plugins and mutual TLS/client
certificates are unsupported. Authentication packets have bounded lengths, sequence validation and bounded
exchange counts. Server authentication errors report a numeric error code without including server-provided
text or credentials.

This integration supplies a MySQL driver for CQL schemas and crystal-db. It does not add MySQL support to
`CQL::Postgres::AsyncEngine`, its streaming API or its pipelining API.

## Check the negotiated encryption

For a standalone connection check, open the same URL directly with crystal-db:

```crystal
require "cql"
require "cql/mysql"

DB.open(ENV["DATABASE_URL"]) do |db|
  puts db.scalar("SELECT VERSION()")
  cipher = db.query_one("SHOW SESSION STATUS LIKE 'Ssl_cipher'", as: {String, String})[1]
  raise "MySQL connection is not encrypted" if cipher.empty?
  puts "TLS cipher: #{cipher}"
  puts db.query_one("SELECT CAST(? AS SIGNED)", 42_i64, as: Int64)
end
```

A nonempty cipher confirms encryption. Identity verification comes from using `ssl-mode=verify_identity` with
the correct trust store and hostname; a cipher alone does not prove that verification was enabled.

## Troubleshooting

| Failure | Check or remediation |
| --- | --- |
| Cannot resolve `require "cql/mysql"` | Use a CQL revision containing the optional integration and install the pinned mysql dependency. |
| `OpenSSL::SSL::Error` during connection | Check CA trust, certificate validity and the hostname/IP SAN. Mount the correct CA and use the certificate's hostname. |
| `MySQL server does not offer TLS; refusing authentication` | Enable TLS on the server and check that the endpoint or proxy supports the MySQL TLS negotiation. |
| `MySQL full password authentication requires TLS` | Use `ssl-mode=verify_identity` with the appropriate CA. A cached plaintext authentication success does not establish cold-connect compatibility. |
| `MySQL authentication rejected (server error 1045)` | Check the account, password, host grants and authentication plugin on the server. |
| `unsupported MySQL authentication plugin` | Use an account with a supported plugin, normally MySQL 8.4's default `caching_sha2_password`. |
| `IO::TimeoutError` during authentication | Check DNS, routing, server saturation and TLS negotiation; set a realistic `connect_timeout` within the application's connection budget. |

After a password rotation, existing connections retain their authenticated identity. Create a new pool with the
new secret, verify a fresh connection, switch new work to it, then drain and close the old pool. Coordinate account
revocation with that transition. CQL does not rotate secrets or reload an existing pool's credentials. Likewise,
validate new CA trust with fresh connections before retiring old certificates.

## Reproduce the release checks

From a CQL checkout with Docker, OpenSSL, Crystal and installed shards:

```bash
script/mysql84-fixture start
script/mysql84-fixture run
script/mysql84-fixture stop
```

Always run `stop`, including after a failed test. This disposable loopback fixture requires secure transport and
uses a `caching_sha2_password` account, a test CA and hostname verification. The run command clears the server's
authentication cache before checking cold/warm authentication, rejected credentials, untrusted CA, wrong hostname,
plaintext refusal, concurrent pooling, optimistic locking, savepoints and isolation. Missing fixtures fail the
run rather than becoming pending. The release workflow runs this contract and the authentication packet/deadline
regressions. Fixture passwords and certificates are for local tests only.

See [Database Support](../../reference/database-support.md) for MySQL SQL/DDL limits and
[Telemetry](../observability/telemetry.md) for query instrumentation. A deployed proxy's TLS termination,
certificate rotation, failover and workload limits still need validation against that application's topology.
