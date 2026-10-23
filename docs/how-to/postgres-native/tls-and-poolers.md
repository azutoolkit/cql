# Configure TLS, Poolers, Timeouts and Transactions

Secure the connection, run behind a pooler such as PgBouncer, bound statement time, listen for notifications and tune
transactions.

## TLS

Set `sslmode` in the URL:

```crystal
engine = CQL::Postgres::AsyncEngine.connect("postgres://app:secret@db.internal/app?sslmode=verify-full")
```

| Mode | Behavior |
| --- | --- |
| `disable` | No TLS |
| `prefer` (default) | Use TLS if the server offers it; the certificate is not verified |
| `require` | TLS required; the certificate is not verified, like libpq |
| `verify-full` | TLS required; certificate and host name are verified |

`allow` and `verify-ca` are rejected with `ArgumentError`, as are libpq options such as `sslcert` and `sslkey`.

To trust a private CA, add `sslrootcert` (allowed only with `verify-full`). It adds the CA to the system trust store;
Crystal's TLS context cannot drop the system roots.

```crystal
"postgres://app:secret@db.internal/app?sslmode=verify-full&sslrootcert=/etc/ssl/internal-ca.pem"
```

If TLS is required but cannot be had (the server declines, the handshake fails or the certificate is bad), the driver
raises `CQL::Postgres::TLSRefused`. It is not an `IO::Error`, so crystal-db's pool does not retry it. A server that
simply hangs up is still retried.

Unix sockets use the `host` option: `postgres://app@/app?host=/var/run/postgresql`.

## Protocol Versions

The driver asks for protocol 3.2 (PostgreSQL 18) and follows the server's `NegotiateProtocolVersion`. It retries on
3.0 when an older server or proxy rejects the startup, answers with something that is not a protocol message, resets
the connection or closes it without answering. A stall is not retried: `connect_timeout` ends it.

A server that rejects 3.2 costs every new connection one extra attempt. Skip it by pinning the range:

```crystal
"postgres://app:secret@pooler.internal/app?max_protocol_version=3.0"
```

`min_protocol_version` and `max_protocol_version` accept `3.0` or `3.2` (and `latest` for the maximum). A minimum newer
than the maximum raises `ArgumentError`. `cockroachdb://` URLs default the maximum to 3.0. OAuth authentication
(PostgreSQL 18) is not supported.

## Poolers

External poolers differ in what they support. Results from the project's live probes (PostgreSQL 16 behind, one
machine):

| Pooler | Result |
| --- | --- |
| PgBouncer 1.22, 1.24, 1.26 | Session mode behaves like a direct connection. Transaction mode works with `max_prepared_statements` above 0. Falls back from 3.2 to 3.0 on its own. |
| Odyssey 1.5.2 (transaction mode) | All nine probes pass. It resets the connection on a 3.2 startup, so set `max_protocol_version=3.0`. |
| pgcat 1.2.0 (transaction mode) | It drops a 3.2 startup and does not accept the Flush message. Cached statements, pipelining and timeout cancel work; `statement_cache_size=0`, `SET LOCAL`, streaming and savepoints hang. |
| pgpool-II 4.3.7 (default settings) | Needs `max_protocol_version=3.0`. Then eight of nine probes pass; streaming through a portal hangs. |

Not tested: RDS Proxy, Supavisor, other pgpool-II settings.

### Transaction-mode pooler without prepared-statement support

Named statements collide between clients (SQLSTATE `42P05`, or `26000` when a statement is missing on the next server
connection). Turn the statement cache off:

```crystal
"postgres://app:secret@pgbouncer.internal:6432/app?statement_cache_size=0&max_protocol_version=3.0"
```

With `statement_cache_size=0` the unnamed statement is used. Pipelining needs the cache, so it raises there.

### Probe your own pooler

`script/pooler_probes.cr` runs nine probes (connect, cached statements, interleaved clients, `statement_cache_size=0`,
pipelining, `SET LOCAL`, timeout cancel, streaming, savepoints). Configure it with `POOLER_NAME`, `POOLER_PORT`,
`POOLER_USER`, `POOLER_PASSWORD` and optionally `POOLER_QUERY` (extra URL options).

### A stream pins a pooler connection

In transaction mode, a stream's portal pins the pooler's server connection until the block ends. Another client of a
one-connection pool waits for it.

## Timeouts and Cancel

Bound one statement with `timeout:` on the session:

```crystal
engine.with_connection do |connection|
  connection.session.query("SELECT pg_sleep(10)", timeout: 2.seconds)
rescue ex : CQL::Postgres::QueryTimeout
  puts "gave up"
end
```

On timeout the driver sends a cancel request. If the cancel does not help (a dead path, a server that ignores it), the
socket is closed after `cancel_grace`, 5 seconds by default (`session.cancel_grace = 2.seconds`).

Cancel from another fiber with `connection.cancel` or `connection.session.cancel`; the statement raises
`CQL::Postgres::QueryCanceled`.

A cancel request carries the session's secret key and travels over a new, **unencrypted** connection, even under
`sslmode=require`, as libpq does before version 17.

Related health checks:

- `Session#ping(timeout)` closes a connection that does not answer in time. A pool health-check ping waits at most 5
  seconds (`Session::PING_TIMEOUT`).
- Health checks of one checkout share the `checkout_timeout` budget, so idle connections on a silently dropped path
  delay a checkout by about one timeout, not one each.
- Dropping a connection closes the socket itself, never a TLS close_notify, which could block on a dead path.

## LISTEN and NOTIFY

Register handlers on a connection, then `LISTEN`:

```crystal
engine.with_connection do |connection|
  connection.on_notification { |note| puts "#{note.channel}: #{note.payload}" }
  connection.on_notice { |fields| puts "notice #{fields['C']}" }
  connection.exec_all("LISTEN orders")
  # notifications are delivered while a request runs on this connection
  connection.exec_all("SELECT 1")
end
```

Rules:

- Handlers run while the session's lock is held, so they must not use the same session.
- Handlers are cleared when the connection returns to the pool, and a pool does not keep `LISTEN` state for you. Hold
  a dedicated connection for as long as you listen.
- CockroachDB has no `LISTEN`.
- `LISTEN` does not work behind a transaction-mode pooler, because the server connection changes between
  transactions; use session mode or connect directly. (This is how PostgreSQL and poolers behave in general; it was not
  part of the driver's probes.)

## Transactions: Isolation and Savepoints

```crystal
engine.transaction(isolation: :serializable, read_only: true) do |tx|
  AppDB.query.from(:accounts).select(:balance).using(tx).all(as: Int64)
end
```

Options of `engine.transaction`:

| Option | Values | Effect |
| --- | --- | --- |
| `isolation:` | `:read_uncommitted`, `:read_committed`, `:repeatable_read`, `:serializable` | `SET TRANSACTION ISOLATION LEVEL ...` |
| `read_only:` | `true` / `false` | `READ ONLY` |
| `deferrable:` | `true` / `false` | `DEFERRABLE` (raises `ArgumentError` on CockroachDB) |
| `synchronous_commit:` | `true` / `false` / `nil` | `SET LOCAL synchronous_commit` |

The options are applied before the transaction's first query.

### Savepoints

`tx.savepoint` nests inside the transaction. If the block raises, only its own work is rolled back and the exception
propagates. Raise `DB::Rollback` to undo it quietly, which makes `savepoint` return `nil`.

```crystal
engine.transaction do |tx|
  AppDB.insert.into(:orders).values(total: 10_i64).using(tx).commit

  tx.savepoint do |inner|
    AppDB.insert.into(:audit).values(note: "tried").using(inner).commit
    raise DB::Rollback.new # the audit row is undone, the order stays
  end
end
```

The yielded scope can open savepoints of its own.

### Retry serialization failures

Under `:serializable` (and always on CockroachDB), retry on `CQL::Postgres::SerializationFailure` (SQLSTATE `40001`):

```crystal
attempts = 0
begin
  engine.transaction(isolation: :serializable) { |tx| transfer(tx) }
rescue CQL::Postgres::SerializationFailure
  attempts += 1
  retry if attempts < 3
  raise
end
```

### Relax durability with synchronous_commit

`synchronous_commit: false` lets `COMMIT` return before the WAL is flushed. It cannot corrupt the database, but commits
from the last few hundred milliseconds (up to about three times `wal_writer_delay`) can be lost if the server crashes,
and a replica or client may have seen them already. Use it for data you can recompute; keep the default for money.
`true` forces `on`, overriding settings like `remote_apply`. As a `SET LOCAL`, it affects only that transaction. For a
whole connection use `?synchronous_commit=off` in the URL.

## Troubleshooting

**`TLSRefused`**: the server does not offer TLS, or the certificate failed verification. Check `sslmode`,
`sslrootcert` and the server's `ssl` setting.

**`sslrootcert needs sslmode=verify-full`**: other modes do not verify the server, so a CA would be pointless.

**Login fails through a pooler right after connecting**: set `max_protocol_version=3.0`.

**SQLSTATE `42P05` or `26000`**: a transaction-mode pooler without prepared-statement support; use
`statement_cache_size=0`.

**Statements hang behind pgcat**: see the table above; those features are not usable there.

**Cancel seems to do nothing**: PostgreSQL ignores a cancel when no statement is running. Streams handle this by
raising on the next fetch.
