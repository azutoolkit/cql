# Scripts

Helpers for maintainers and CI: checks of CQL's native PostgreSQL driver against real servers, poolers and
`crystal-db` versions, the docs checks, the release step and the API reference build. Run them from the repository
root.

> [!CAUTION]
> `pg-matrix`, `pgbouncer-matrix` and `tls-probes` start throwaway servers that trust local connections (the
> superuser `cql` needs no password). Run them on a disposable machine or container, never next to data you care
> about.

| Script | Checks | Needs |
| --- | --- | --- |
| `check_db_compat` | that CQL compiles against each supported `crystal-db` version | `crystal`, `shards`, network access to fetch `crystal-db` |
| `pg-matrix` | the live specs on several PostgreSQL major versions | PostgreSQL binaries (`initdb`, `pg_ctl`) per version |
| `pgbouncer-matrix` | the PgBouncer specs, in transaction and session pooling | `pgbouncer`, and the `cql_scram` role that `pg-matrix run` creates |
| `tls-probes` and `tls_probes.cr` | what the driver does when TLS is refused or cannot be verified | PostgreSQL binaries, `openssl` |
| `pooler_probes.cr` | nine behaviours through any pooler or proxy | a running pooler |

When run as root, `pg-matrix`, `pgbouncer-matrix` and `tls-probes` start their servers as the `postgres` OS user, and
each refuses a data directory that is a symlink.

## `check_db_compat`

```bash
script/check_db_compat               # 0.13.1, 0.14.0 and 0.15.0
script/check_db_compat 0.14.0        # one version
script/check_db_compat latest        # newest release
```

For each version it builds a throwaway project that depends on this checkout and on that `crystal-db`, and runs
`crystal build --no-codegen` on `require "cql"; CQL::Postgres::Connection`. A new abstract member in
`DB::Connection`, `DB::Statement`, `DB::ResultSet` or `DB::Driver` fails here instead of in users' projects.

## `pg-matrix`

```bash
export PG_MATRIX_BINS="14=/usr/lib/postgresql/14/bin 16=/usr/lib/postgresql/16/bin"
script/pg-matrix start    # initdb if needed, then start every server
script/pg-matrix run      # matrix_spec.cr once, then live_spec.cr against each server
script/pg-matrix stop
```

| Setting | Meaning |
| --- | --- |
| `PG_MATRIX_BINS` | required: space-separated `major=bin-directory` pairs |
| `PG_MATRIX_DIR` | data and logs (default `/tmp/cql-pg-matrix`) |
| ports | server `N` listens on `127.0.0.1:` 5500 + `N` (major 16 on 5516); Unix sockets go under the data directory |
| roles | superuser `cql` is trusted; `pg_hba.conf` gives `cql_scram`, `cql_md5` and `cql_clear` the matching password method |

`run` sets `CQL_PG_MATRIX` for `spec/postgres/matrix_spec.cr`, which creates the three password roles (password
`secret`), then runs `spec/postgres/live_spec.cr` against each server with `DATABASE_URL` set (`sslmode=disable`).
It prints the last lines of each `live_spec` run and exits non-zero if any run failed.

## `pgbouncer-matrix`

```bash
script/pg-matrix start && script/pg-matrix run   # once: matrix_spec.cr creates the cql_scram role
PGB_BACKEND_PORT=5516 script/pgbouncer-matrix start
PGB_BACKEND_PORT=5516 script/pgbouncer-matrix run
script/pgbouncer-matrix stop
```

It starts four PgBouncer instances in front of one PostgreSQL server and runs `spec/postgres/pgbouncer_spec.cr`
against them, passing the ports through `CQL_PGB_TX`, `CQL_PGB_TX_PS`, `CQL_PGB_SESSION` and `CQL_PGB_TX_MULTI`. The
instances authenticate `cql_scram` with `scram-sha-256`.

| Instance | Port | Pool mode | `max_prepared_statements` | `default_pool_size` |
| --- | --- | --- | --- | --- |
| `tx` | 6501 | transaction | 0 | 1 |
| `txps` | 6502 | transaction | 100 | 1 |
| `session` | 6503 | session | 0 | 3 |
| `txmulti` | 6504 | transaction | 0 | 3 |

Settings: `PGB_BACKEND_PORT` (default 5516), `PGB_DIR` (default `/tmp/cql-pgbouncer`) and `PGBOUNCER` (the binary;
defaults to the one on `PATH`).

## `tls-probes`

```bash
PG_TLS_BIN=/usr/lib/postgresql/16/bin NOTLS_PG_PORT=5516 script/tls-probes
```

It starts a TLS-enabled PostgreSQL (its own cluster and a self-signed certificate valid for `localhost`) and runs
`script/tls_probes.cr`, which checks that a TLS requirement that cannot be met raises `CQL::Postgres::TLSRefused` and
that crystal-db's pool makes one connection attempt instead of retrying. A control probe confirms the pool does retry
a plain hang-up.

| Variable | Meaning |
| --- | --- |
| `PG_TLS_BIN` | required: a PostgreSQL `bin` directory |
| `NOTLS_PG_PORT` | required: a PostgreSQL without TLS (user `cql`, trust), for the "server without TLS" probes; the 5516 server from `pg-matrix` works |
| `PG_TLS_PORT` | port for the TLS server (default 5640) |
| `PG_TLS_DIR` | data, key and certificate directory (default `/tmp/cql-pg-tls`) |
| `CRDB_PORT`, `CRDB_CA` | optional: also probe a secure CockroachDB (user `cql_pw`, password `secret`, database `cql_wire`) |

The probes: `sslmode=require` against a server without TLS; `prefer` falling back to plaintext; `require` connecting
without verifying the certificate; `verify-full` with the right CA, with the wrong host name, and without the CA;
`prefer` using TLS against a TLS server; and the pool's retry behaviour for each refusal. Each prints `PASS` or
`FAIL`, and the exit status is the number of failures.

The TLS server is left running; `spec/postgres/blackhole_spec.cr` uses it through `CQL_TLS_PG_PORT`. To point the
probes at your own servers, run `tls_probes.cr` directly:

```bash
TLS_PG_PORT=5640 TLS_CA=/tmp/cql-pg-tls/server.crt NOTLS_PG_PORT=5516 crystal run script/tls_probes.cr
```

## `pooler_probes.cr`

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

The nine probes:

1. connects; protocol version and cancel key
2. cached prepared statement, three runs
3. two clients, same SQL, interleaved (statement names shared on one server connection)
4. unnamed statements (`statement_cache_size=0`), two clients interleaved
5. pipeline of five statements
6. `SET LOCAL` stays inside its transaction
7. statement timeout cancels through the pooler and the session keeps working
8. streaming 2000 rows, 100 at a time, then stopping early
9. transaction with a savepoint through `AsyncEngine`

Each probe has a 20 second limit, so a pooler that never answers fails the probe instead of hanging the run. The exit
status is the number of failed probes. A `FAIL` is a finding about the pooler (or the driver), not necessarily a bug,
so read the detail. Results for PgBouncer, Odyssey, pgcat and pgpool-II are in
[Poolers](../docs/how-to/postgres-native/tls-and-poolers.md#poolers); run the probes against your own pooler and
settings before relying on them.

## Docs, Release and API Reference

| Script | Does | Run by |
| --- | --- | --- |
| `docs/check_links.py`, `docs/check_nav.py`, `docs/gitbook_lint.py` | check links and anchors, the docs navigation and redirects, and GitBook markup | the `docs` CI job |
| `docs/compile_snippets.py` | compiles the programs and tutorials in `README.md` and `docs/` | the `docs-snippets` CI job |
| `release VERSION [--dry-run]` | sets `shard.yml`, moves `[Unreleased]` under the version, commits, tags that commit, publishes the GitHub release | the `release` CI job on `master` |
| `api-docs VERSION [DIR]` | builds the API reference from the doc comments in `src/` | the `api-docs` CI job, before the Pages deploy |

The Pages deploy needs **Settings → Pages → Source: GitHub Actions** set once in the repository; until then the
`deploy-api-docs` job fails after the release is already published.

How to steer `compile_snippets.py` with `<!-- docs-check: ... -->` comments is in
[the docs style guide](../.claude/docs-style-guide.md#verifying-examples) and the script's header.

## See Also

- [Native PostgreSQL Driver](../README.md#native-postgresql-driver): the results these scripts produced
- [benchmarks/README.md](../benchmarks/README.md): the performance scripts
- `spec/postgres/`: the specs these scripts drive
