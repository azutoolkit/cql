# Scripts

Helpers that check CQL's native PostgreSQL driver against real servers, poolers and `crystal-db` versions. They exist for maintainers and CI. Several of them start throwaway servers and trust local connections, so run them on a disposable machine or container, never next to data you care about.

Run everything from the repository root.

| Script | Checks | Needs |
| --- | --- | --- |
| `check_db_compat` | that CQL compiles against each supported `crystal-db` version | `crystal`, `shards`, network access to fetch `crystal-db` |
| `pg-matrix` | the live specs on several PostgreSQL major versions | PostgreSQL binaries (`initdb`, `pg_ctl`) per version |
| `pgbouncer-matrix` | the PgBouncer specs, in transaction and session pooling | `pgbouncer`, and the role created by `pg-matrix` |
| `tls-probes` and `tls_probes.cr` | what the driver does when TLS is refused or cannot be verified | PostgreSQL binaries, `openssl` |
| `pooler_probes.cr` | nine behaviours through any pooler or proxy | a running pooler |

## `check_db_compat`

Builds a tiny project that depends on this checkout and on one `crystal-db` version, and compiles `require "cql"` without generating code. A new abstract member in `DB::Connection`, `DB::Statement`, `DB::ResultSet` or `DB::Driver` fails here instead of in users' projects.

```bash
script/check_db_compat               # 0.13.1, 0.14.0 and 0.15.0
script/check_db_compat 0.14.0        # one version
script/check_db_compat latest        # newest release
```

## `pg-matrix`

Starts one throwaway PostgreSQL per major version and runs the live specs against each.

```bash
export PG_MATRIX_BINS="14=/usr/lib/postgresql/14/bin 16=/usr/lib/postgresql/16/bin"
script/pg-matrix start    # initdb if needed, then start every server
script/pg-matrix run      # matrix_spec.cr once, then live_spec.cr against each server
script/pg-matrix stop
```

- `PG_MATRIX_BINS` is required: space-separated `major=bin-directory` pairs.
- `PG_MATRIX_DIR` sets where data and logs go (default `/tmp/cql-pg-matrix`). The script refuses a symlink.
- Server `N` listens on `127.0.0.1:55NN` (major 16 on 5516). Unix sockets go under the data directory.
- Superuser `cql` is trusted. The roles `cql_scram`, `cql_md5` and `cql_clear` use the matching password method, with the password `secret`.
- When run as root, servers run as the `postgres` OS user.
- `run` sets `CQL_PG_MATRIX` for `spec/postgres/matrix_spec.cr` and `DATABASE_URL` (with `sslmode=disable`) for `spec/postgres/live_spec.cr`. It exits non-zero if any run failed and prints the last lines of each `live_spec` log.

## `pgbouncer-matrix`

Starts four PgBouncer instances in front of one PostgreSQL server and runs `spec/postgres/pgbouncer_spec.cr` against them.

```bash
script/pg-matrix start                    # once: it creates the cql_scram role
PGB_BACKEND_PORT=5516 script/pgbouncer-matrix start
PGB_BACKEND_PORT=5516 script/pgbouncer-matrix run
script/pgbouncer-matrix stop
```

| Instance | Port | Pool mode | `max_prepared_statements` | `default_pool_size` |
| --- | --- | --- | --- | --- |
| `tx` | 6501 | transaction | 0 | 1 |
| `txps` | 6502 | transaction | 100 | 1 |
| `session` | 6503 | session | 0 | 3 |
| `txmulti` | 6504 | transaction | 0 | 3 |

Settings: `PGB_BACKEND_PORT` (default 5516), `PGB_DIR` (default `/tmp/cql-pgbouncer`) and `PGBOUNCER` (path to the binary; defaults to the one on `PATH`). The instances authenticate with `scram-sha-256` as `cql_scram`. `run` passes the ports to the spec through `CQL_PGB_TX`, `CQL_PGB_TX_PS`, `CQL_PGB_SESSION` and `CQL_PGB_TX_MULTI`.

## `tls-probes`

Starts a TLS-enabled PostgreSQL (its own cluster, a self-signed certificate valid for the name `localhost`) and runs `script/tls_probes.cr`. The probes check that a TLS requirement that cannot be met raises `CQL::Postgres::TLSRefused`, and that crystal-db's pool makes one connection attempt instead of retrying. A control probe confirms the pool does retry a plain hang-up.

```bash
PG_TLS_BIN=/usr/lib/postgresql/16/bin NOTLS_PG_PORT=5516 script/tls-probes
```

| Variable | Meaning |
| --- | --- |
| `PG_TLS_BIN` | required: a PostgreSQL `bin` directory |
| `NOTLS_PG_PORT` | required: a PostgreSQL without TLS (user `cql`, trust), for the "server without TLS" probes. The `5516` server from `pg-matrix` works |
| `PG_TLS_PORT` | port for the TLS server (default 5640) |
| `PG_TLS_DIR` | data, key and certificate directory (default `/tmp/cql-pg-tls`) |
| `CRDB_PORT`, `CRDB_CA` | optional: also probe a secure CockroachDB (user `cql_pw`, password `secret`, database `cql_wire`) |

Probes covered: `sslmode=require` against a server without TLS, `prefer` falling back to plaintext, `require` connecting without verifying the certificate, `verify-full` with the right CA, with the wrong host name and without the CA, `prefer` using TLS against a TLS server, and the pool's retry behaviour for each refusal.

The TLS server is left running afterwards. `spec/postgres/blackhole_spec.cr` uses it through `CQL_TLS_PG_PORT`. Each probe prints `PASS` or `FAIL`; the exit status is the number of failures. `tls_probes.cr` reads `TLS_PG_PORT`, `TLS_CA` and `NOTLS_PG_PORT` directly if you want to point it at your own servers: `TLS_PG_PORT=... TLS_CA=... NOTLS_PG_PORT=... crystal run script/tls_probes.cr`.

## `pooler_probes.cr`

Runs nine probes through any pooler or proxy sitting in front of PostgreSQL and reports what works. A `FAIL` is a finding about the pooler (or the driver), not necessarily a bug, so read the detail.

```bash
POOLER_NAME=pgbouncer POOLER_PORT=6432 POOLER_USER=app POOLER_PASSWORD=secret \
  crystal run script/pooler_probes.cr
```

| Variable | Meaning |
| --- | --- |
| `POOLER_NAME` | required: label used in the report |
| `POOLER_PORT` | required: the pooler listens on `127.0.0.1` at this port |
| `POOLER_USER` | role to log in with (default `cql`) |
| `POOLER_PASSWORD` | password; may be empty |
| `POOLER_QUERY` | extra URL options, for example `sslmode=require` (default `sslmode=disable`) |

The probes:

1. connects; protocol version and cancel key
2. cached prepared statement, three runs
3. two clients, same SQL, interleaved (statement names shared on one server connection)
4. unnamed statements (`statement_cache_size=0`), two clients interleaved
5. pipeline of five statements
6. `SET LOCAL` stays inside its transaction
7. statement timeout cancels through the pooler and the session keeps working
8. streaming 2000 rows, 100 at a time, then stopping early
9. transaction with a savepoint through `AsyncEngine`

Each probe has a 20 second limit, so a pooler that never answers fails the probe instead of hanging the run. The exit status is the number of failed probes. The README's "Native PostgreSQL Driver" section records results for PgBouncer, Odyssey, pgcat and pgpool-II; run the probes against your own pooler and settings before relying on those.

## Related

- `benchmarks/README.md` for the performance scripts.
- `spec/postgres/` for the specs these scripts drive.
