# Database Tasks and Maintenance

`CQL::Postgres::Database::Tasks` is the code behind the database commands (`create`, `migrate`, `seed`, ...). Apps expose it through a small file:

```crystal
# db/tasks.cr
require "cql"
require "cql/postgres"
require "../src/models"
require "./migrations/*"
require "./seeds"

exit CQL::Postgres::Database::Tasks.run(ARGV)
```

```bash
crystal run db/tasks.cr -- <command> [options]
```

Exit status is 0 on success, 1 on a failed task (message on stderr) and 2 for unknown commands.
Logging is quiet; `--verbose` prints the SQL each command runs.

## Commands

| Command | Description |
| --- | --- |
| `create` | Creates the database (no-op if it exists) |
| `drop` | Drops it, terminating other sessions first. Refuses in production unless `--force` |
| `setup` | `create` + `migrate` + `seed` |
| `reset` | `drop` + `setup` |
| `migrate [VERSION]` | Applies pending migrations, optionally up to `VERSION`. `--dry-run` prints the SQL |
| `rollback [STEPS]` | Reverts the last migration, or `STEPS` of them. `--dry-run` prints the SQL |
| `redo` | Reverts and re-applies the last migration |
| `status` | `up` / `down` per migration (`NO FILE` for a recorded version without a class) |
| `version` | Prints the current schema version |
| `seed` | Runs the blocks registered with `CQL::Postgres::Database.seed` |
| `structure:dump [PATH]` | Writes `db/structure.sql` with `pg_dump --schema-only`, plus the applied versions |
| `structure:load [PATH]` | Loads it with `psql` (stops at the first error) |
| `analyze [--refresh]` | Health report below; `--refresh` runs `ANALYZE` after printing it |

`create`/`drop` connect to the `postgres` maintenance database and quote identifiers. Connection
details (host, port, user, password, `sslmode`) come from the same URL the app uses.
`structure:*` need `pg_dump` / `psql` on the `PATH`, and restoring from `structure.sql` gives a
database that already knows which migrations it contains.

## Seeds

```crystal
# db/seeds.cr
CQL::Postgres::Database.seed do
  next if User.count > 0
  User.create!(email: "admin@example.com", name: "Admin", role: "admin")
end
```

Seeds run in registration order. Make them idempotent: `setup` and `reset` run them too.

## Health report (`analyze`)

Reads PostgreSQL's statistics views and prints, with a hint under each section:

* largest tables (rows, dead rows, size including indexes and TOAST)
* unused indexes (never scanned, not enforcing uniqueness) — drop candidates
* duplicate indexes and invalid indexes (a failed `CREATE INDEX CONCURRENTLY` leaves one behind)
* tables with many dead rows (vacuum candidates, bloat) and tables read mostly by sequential scan
* long-running statements
* buffer cache hit ratio, connections versus `max_connections`, and the application's pool usage

The same report is available from code:

```crystal
puts CQL::Postgres::Database::Maintenance.new.to_text
CQL::Postgres::Database::Maintenance.new.analyze!   # ANALYZE
```

## Runtime monitoring

| Setting | Effect |
| --- | --- |
| `c.slow_query_ms` (default 0, `CQL_DB_SLOW_QUERY_MS`; 0 disables) | Each statement at or over the limit is logged as a warning with its SQL, from a `CQL::Events` subscriber |
| `c.n_plus_one` | `Off`, `Warn` (log) or `Raise` for lazy association loads inside a loop, see [Models](models.md#n1-detection) |
| `c.pool_size`, `checkout_timeout` | Applied to the connection URL |
| `CQL::Postgres::Database.healthy?` / `CQL::Postgres::Database.pool` | For health endpoints: `SELECT 1` result and pool counters |

Dashboards and tracers can subscribe to `CQL::Events` (`on_query`, `on_transaction`, `on_connect`) and read
`CQL::Postgres::Database.pool` for pool counters.
