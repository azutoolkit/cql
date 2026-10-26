# Configure TLS, Poolers, Timeouts and Transactions

Secure the connection, run behind a pooler such as PgBouncer, bound statement time, listen for notifications and tune transactions.

## TLS

```crystal
engine = CQL::Postgres::AsyncEngine.connect("postgres://app:secret@db.internal/app?sslmode=verify-full")
```

| `sslmode` | Behavior |
| --- | --- |
| `disable` | No TLS |
| `prefer` (default) | TLS if the server offers it; certificate not verified |
| `require` | TLS required; certificate not verified, like libpq |
| `verify-full` | TLS required; certificate and host name verified |

```crystal
# Trust a private CA as well as the system roots (Crystal's TLS context cannot drop them)
"postgres://app:secret@db.internal/app?sslmode=verify-full&sslrootcert=/etc/ssl/internal-ca.pem"
# Unix socket: host names the socket directory
"postgres://app@/app?host=/var/run/postgresql"

# ArgumentError: sslmode=allow or verify-ca, sslcert, sslkey, and sslrootcert without verify-full
```

When TLS is required and cannot be had (the server declines, the handshake fails, the certificate is bad), the driver raises `CQL::Postgres::TLSRefused`. It is not an `IO::Error`, so crystal-db's pool does not retry it; a server that hangs up mid-handshake is retried.

## Protocol Versions

The driver asks for protocol 3.2 (PostgreSQL 18) and follows the server's `NegotiateProtocolVersion`. It retries once on 3.0 when a server or proxy rejects the startup, answers with something that is not a protocol message, resets the connection or closes it unanswered. A stall is not retried; `connect_timeout` ends it.

```crystal
# Skip the extra 3.2 attempt on every new connection
"postgres://app:secret@pooler.internal/app?max_protocol_version=3.0"
# min_protocol_version and max_protocol_version take 3.0, 3.2 or latest (the default maximum).
# A minimum above the maximum raises ArgumentError. cockroachdb:// URLs default the maximum to 3.0.
# OAuth authentication (PostgreSQL 18) is not supported.
```

## Poolers

From the project's live probes, PostgreSQL 16 behind each pooler ([measured compatibility](https://github.com/azutoolkit/cql#measured-compatibility)):

| Pooler | Result |
| --- | --- |
| PgBouncer 1.22, 1.24, 1.26 | Session mode behaves like a direct connection. Transaction mode works with `max_prepared_statements` above 0. Falls back from 3.2 to 3.0 on its own. |
| Odyssey 1.5.2, transaction mode | All nine probes pass. It resets a 3.2 startup: set `max_protocol_version=3.0`. |
| pgcat 1.2.0, transaction mode | Drops a 3.2 startup and rejects Flush. Cached statements, pipelining and timeout cancel work; `statement_cache_size=0`, `SET LOCAL`, streaming and savepoints hang. |
| pgpool-II 4.3.7, default settings | Needs `max_protocol_version=3.0`; then eight of nine probes pass, and streaming through a portal hangs. |

Not tested: RDS Proxy, Supavisor, other pgpool-II settings.

```crystal
# Transaction-mode pooler without prepared-statement support: named statements collide between
# clients (SQLSTATE 42P05, or 26000 on the next server connection). Use the unnamed statement:
"postgres://app:secret@pgbouncer.internal:6432/app?statement_cache_size=0&max_protocol_version=3.0"
# Pipelining needs the cache, so engine.pipeline raises ArgumentError there.
# In transaction mode a stream's portal pins the pooler's server connection until its block ends.
```

```bash
# Nine probes: connect, cached statements, interleaved clients, statement_cache_size=0,
# pipelining, SET LOCAL, timeout cancel, streaming, savepoints (pooler on 127.0.0.1, database postgres)
POOLER_NAME=pgbouncer POOLER_PORT=6432 POOLER_USER=app POOLER_PASSWORD=secret \
  crystal run script/pooler_probes.cr  # POOLER_QUERY adds URL options (default sslmode=disable)
```

## Timeouts and Cancel

```crystal
engine.with_connection do |connection|
  connection.session.query("SELECT pg_sleep(10)", timeout: 2.seconds)
rescue CQL::Postgres::QueryTimeout
  puts "gave up" # the driver sent a cancel; the connection stays usable once the server confirms it
end
# A cancel that does not take effect within session.cancel_grace (default 5 seconds) closes the socket.
# connection.cancel or connection.session.cancel, from another fiber, makes the running statement
# raise CQL::Postgres::QueryCanceled. PostgreSQL ignores a cancel when nothing runs.
```

{% hint style="warning" %}
A cancel request carries the session's secret key over a new, **unencrypted** connection, even under `sslmode=require`, as libpq does before version 17.
{% endhint %}

Pool health checks ping idle connections for at most 5 seconds (`Session::PING_TIMEOUT`) and share one `checkout_timeout` budget per checkout, so dead connections delay a checkout by about one timeout, not one each. A dropped connection closes its socket without a TLS close_notify, which could block on a dead path.

## LISTEN and NOTIFY

```crystal
engine.with_connection do |connection|
  connection.on_notification { |note| puts "#{note.channel}: #{note.payload}" }
  connection.on_notice { |fields| puts "notice #{fields['C']}" } # without a handler: logged as severity and SQLSTATE
  connection.exec_all("LISTEN posts")
  connection.exec_all("SELECT 1") # notifications arrive while a request runs on this connection
end
```

Handlers run under the session's lock, so they must not use that session. They are cleared when the connection returns to the pool, which keeps no `LISTEN` state: hold one connection for as long as you listen. CockroachDB has no `LISTEN`, and behind a transaction-mode pooler it breaks because the server connection changes between transactions (general pooler behavior, not probed).

## Transactions: Isolation and Savepoints

```crystal
engine.transaction(isolation: :serializable, read_only: true) do |tx|
  AppDB.query.from(:users).select(:name).using(tx).all(as: String)
end
```

| Option | Values | Effect, applied before the first query |
| --- | --- | --- |
| `isolation:` | `:read_uncommitted`, `:read_committed`, `:repeatable_read`, `:serializable` | `SET TRANSACTION ISOLATION LEVEL ...` |
| `read_only:` | `true` / `false` | `READ ONLY`; a write raises SQLSTATE `25006` |
| `deferrable:` | `true` / `false` | `DEFERRABLE`; `ArgumentError` on CockroachDB |
| `synchronous_commit:` | `true` / `false` / `nil` | `SET LOCAL synchronous_commit` |

```crystal
engine.transaction do |tx|
  AppDB.insert.into(:users).values(name: "Ada", email: "ada@example.com").using(tx).commit

  tx.savepoint do |inner| # can open savepoints of its own
    AppDB.insert.into(:posts).values(title: "Draft", user_id: 1_i64).using(inner).commit
    raise DB::Rollback.new # undoes the post only; savepoint returns nil
  end
end
# A savepoint block that raises rolls back its own work, and the exception propagates.

# Retry serialization failures (SQLSTATE 40001): under :serializable, and always on CockroachDB
def with_retries(attempts = 3, &)
  attempts.times do |attempt|
    return yield
  rescue ex : CQL::Postgres::SerializationFailure
    raise ex if attempt == attempts - 1
  end
end

with_retries { engine.transaction(isolation: :serializable) { |tx| transfer(tx) } }

# COMMIT returns before the WAL is flushed: never corrupts the database, but commits from roughly the
# last 3 x wal_writer_delay can vanish in a server crash after a client or replica saw them.
engine.transaction(synchronous_commit: false) do |tx|
  AppDB.insert.into(:posts).values(title: "Page view").using(tx).commit
end
# true forces on, overriding settings such as remote_apply; for a whole connection use ?synchronous_commit=off.
```

## Troubleshooting

**`TLSRefused`**: the server does not offer TLS or the certificate failed verification; check `sslmode`, `sslrootcert` and the server's `ssl` setting.

**Login fails through a pooler right after connecting**: set `max_protocol_version=3.0`.

**SQLSTATE `42P05` or `26000`**: a transaction-mode pooler without prepared-statement support; use `statement_cache_size=0`.

## See Also

- [Use AsyncEngine and Its Connection Pool](async-engine.md)
- [Enable SSL Connections](../configuration/ssl.md)
- [Use CockroachDB](../configuration/cockroachdb.md)
- [Use Transactions](../data-operations/transactions.md)
- [Fix Connection Errors](../troubleshooting/connection-errors.md)
