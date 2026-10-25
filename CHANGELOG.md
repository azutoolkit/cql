# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- `Model.query...count` ignores `order` (it emitted `COUNT(*) ... ORDER BY`, a wasted sort that PostgreSQL rejects for ungrouped columns) and respects `limit`/`offset`: `limit(2).count` now returns at most 2 by counting a derived table (`SELECT COUNT(*) FROM (...) AS counted_rows`); before, LIMIT/OFFSET applied to the single aggregate row, so `limit(2).count` returned the full count and `offset(2).count` returned 0. The limited count runs on the query's pinned executor, selects only the primary key (or the counted column) inside the derived table, and `QueryBuilder#count_query` returns the statement `count` runs.
- has_many and many_to_many collections no longer change their own query: `reload`, `count`, `find`, `find_by`, `where`, `limit`, `offset` and `order` run on a copy. Before, each call added another `fk = ?` to the stored query, `count` left `COUNT(*)` behind (so a later `reload` failed with a missing column), and `limit`/`offset`/`order`/`where` stuck to every later call on the same collection. `Collection.new` and `ManyCollection.new` now scope the query they are given to the parent themselves (many_to_many through the join table), lazily on first use, so passing an unscoped `query:` no longer returns other parents' rows. Pass the base query unscoped: for `Collection` an already scoped query still works but carries the predicate twice; for `ManyCollection` a query that already joins the join table raises a duplicate table error.
- `CQL.build_schema` now compiles and runs: the table-definition block runs against the new schema (it previously failed with `undefined method 'table' for top-level`), and the SQL logging setup calls `CQL::Performance.enable_sql_logging` (the development default used a method that did not exist).
- `CQL.build_schema` opens the database through `config.full_db_url`, so `pool.*`, `ssl.*`, SQLite/MySQL/PostgreSQL settings and `adapter_options` now reach the connection. URL parameters still win.
- The native PostgreSQL driver accepts and ignores the `auth_methods` URL option that `CQL.configure` adds for the `pg` shard, instead of sending it to the server as a startup parameter (which PostgreSQL rejects). This matters now that `CQL.build_schema` opens through `config.full_db_url`.
- `config.sql_logging` is now unset until you assign it: unset follows the environment (on in `development` unless `CQL_NO_SQL_LOG` is set, evaluated when queried), and `config.sql_logging = false` turns it off in development.
- `config.pool_size=` updates `config.pool.size` and keeps `pool.initial_size` and `pool.max_idle_size` from exceeding it.
- `config.sql_logging_async` is unused and kept only for compatibility.
- Because `CQL.build_schema` now applies `full_db_url`, SQLite connections opened through it use the configured defaults (`journal_mode=wal`, `synchronous=normal`, `foreign_keys=1`, `busy_timeout=5000`); set `config.sqlite.*` to change them.

### Documentation

- Fixed broken links, version pins and wrong class names across `README.md` and `docs/`; CockroachDB is listed wherever dialects are enumerated.
- Rewrote the caching how-to pages (`per-request`, `redis`, `query-cache`) against the real `CQL::Cache` API.
- Added how-to pages for the native PostgreSQL driver, CockroachDB, CTEs, window functions, set operations, upsert, row locking, raw fragments, `explain`, JSON/geo predicates and the typed `where` DSL; plus schema dump/validation, UUID/ULID keys, safety guardrails and the query profiler.
- Added `benchmarks/README.md` and `script/README.md`.

### Added

- PostgreSQL driver binary parameters (`binary_params=true`, off by default: measured faster for arrays and for statements with several parameters, about even for a single value; see the README) chosen per parameter from the server's `ParameterDescription` for int2/4/8, float4/8, bool, uuid, timestamp(tz), date, numeric, jsonb and arrays of them, falling back to the text form whenever there is no equivalent binary one; CockroachDB keeps float4 and numeric as text. Binary `COPY`: `Session#copy_in_binary` / `copy_out_binary` (and on `Connection`), which raise `ArgumentError` if the server runs the statement as text. `Session#encode` builds a parameter for the session's setting; `ParamEncoder.encode(value, binary)` defers one.
- PostgreSQL driver live verification: `script/tls-probes` (TLS refusal against real servers, asserting the pool does not retry), `script/pooler_probes.cr` (nine probes for any pooler) and `spec/postgres/blackhole_spec.cr` (hard close under TLS on a dead path); results for PostgreSQL 19rc1, PgBouncer 1.26.1 (also with client TLS, `sslmode=require` and `verify-full`), Odyssey 1.5.2, pgcat 1.2.0 and pgpool-II 4.3.7 are in the README. A server that resets the connection before answering a 3.2 startup (Odyssey) now falls back to 3.0 like one that closes it.
- Native PostgreSQL wire-protocol driver (`require "cql/postgres"`, also loaded by `require "cql"`): `CQL::Postgres::AsyncEngine` is a `CQL::Executor` (`query.using(engine)`, `engine.transaction`, `engine.pipeline`) with its own fiber-safe connection pool, startup/authentication (trust, cleartext, MD5, SCRAM-SHA-256), TLS and Unix sockets, simple and extended protocol with prepared-statement caching, binary results, `COPY`, `LISTEN`/`NOTIFY`, cancellation and statement timeouts, and typed `CQL::Postgres::ServerError` subclasses per SQLSTATE. Rows map into `all(as:)` and models through crystal-db's own interfaces. Bound values and passwords never appear in driver messages or telemetry. `Pinnable#using` (and the ActiveRecord query builder's) now also accepts any `CQL::Executor`. See the README section "Native PostgreSQL Driver", `playground/postgres_async_demo.cr` and `benchmarks/pg_wire_bench.cr`.
- PostgreSQL driver speaks protocol 3.2 and falls back to 3.0 (`NegotiateProtocolVersion`, or a rejected startup on older servers); `min_protocol_version` / `max_protocol_version` URL options pin the range, and cancel requests carry the server's (possibly 256-byte) secret key.
- PostgreSQL driver transactions take `isolation:`, `read_only:`, `deferrable:` and `synchronous_commit:` (a `SET LOCAL`; see the README for the durability trade-off) and offer `tx.savepoint { }`. The pool gains `pool_min_size`, `max_queries`, `max_idle_lifetime`, a per-connection `setup:` hook and a `reset:` statement; a transaction left open by a borrower is now rolled back and the connection reused instead of dropped.
- The native PostgreSQL driver is now the default crystal-db driver for `postgres://` and `postgresql://` URLs (`require "cql"` registers it; `cockroachdb://` is opt-in with `CQL::Postgres::Driver.register_cockroachdb` or `-Dcql_postgres_driver_cockroachdb`; a `pg` shard loaded first, or later, keeps serving `postgres`/`postgresql`), so `CQL::Schema` runs on it without the `pg` shard (schemas on `CQL::Adapter::CockroachDB` use the `postgres` name, so they follow the same rule). A `Schema` on the default driver was checked against PostgreSQL 18; see the next entry for the other servers. Server errors 42P05 and 26000 now say to try `statement_cache_size=0` behind a transaction-mode pooler.
- PostgreSQL driver compatibility, each checked against a real server: PostgreSQL 11 through 18 (`script/pg-matrix`), PgBouncer 1.22 in transaction and session mode (`script/pgbouncer-matrix`) and CockroachDB 24.3 (which answers an unknown protocol version with HTTP/2 bytes: `cockroachdb://` starts at 3.0 and any unrecognised first reply falls back to 3.0; its stale-plan error is recognised too). `-Dcql_no_postgres_driver` keeps the driver out of crystal-db's registry.
- PostgreSQL driver `ResultSet#result` is gone (rows now come from an iterator, so a `RowStream` can back a result set) and `ResultSet.new` takes `detached` positionally.
- PostgreSQL driver streaming: `engine.stream(query, fetch_size:)`, `Connection#stream` (a lazy `DB::ResultSet`) and `Session#stream` (a `RowStream` iterator) read large results through a portal `fetch_size` rows at a time; stopping early, errors between fetches, cancel and timeouts leave the session in sync (checked on PostgreSQL 16 and CockroachDB 24.3).
- PostgreSQL driver fix: with `statement_cache_size=0` the unnamed statement is now described without a Sync, so Parse/Describe and Bind form one request. Behind a transaction-mode pooler with several server connections they could land on different ones, failing with a parameter-count error or running another client's statement.
- PostgreSQL driver hardening: connection failures reach crystal-db's pool as `DB::ConnectionRefused` (so `retry_attempts` applies); a health-check ping and a timed-out request whose cancel is ignored now close the socket instead of blocking (`Session#ping(timeout)`, `Session#cancel_grace`); a `TransactionScope` raises `TransactionClosed` once its block is over; `inspect` of sessions, connections and pools shows no secrets; malformed pool options (`pool_size=abc`, `max_queries=many`, ...) raise `ArgumentError`; `Pool#close` wakes waiting fibers; `AsyncEngine.connect` picks the CockroachDB adapter for `cockroachdb://`; a server that closes the connection on a 3.2 startup falls back to 3.0. Telemetry carries no bound values unless `capture_params` is on. Telemetry now labels `WITH ... INSERT/UPDATE/DELETE` queries by the statement they modify (they were `select`) and skips leading comments; `RowStream#next` raises when called from another fiber; `TransactionScope` is a standalone class (no longer a `CQL::ConnectionExecutor`); `Config.number`, `Config.seconds` and `Config.whole` are public.
- PostgreSQL driver: a required TLS that cannot be had (the server declines, answers the SSLRequest oddly, or fails the handshake or certificate check) raises `CQL::Postgres::TLSRefused`, which is not an `IO::Error`, so crystal-db's pool does not retry it and the cause is not lost; dropping a connection closes the socket itself (no TLS close_notify that could block on a dead path); `RowStream#next` from another fiber raises `WrongFiber`; telemetry's statement labelling also understands `E'...'` strings; a server that hangs up during the SSLRequest or the TLS handshake stays a retryable `IO::Error`; a pool health-check ping waits at most `Session::PING_TIMEOUT` (5 seconds) even when `checkout_timeout` is longer.
- PostgreSQL driver fix: `Session#cancel` now ends a stream that still has rows to fetch. PostgreSQL ignores a cancel while no statement is running, which is the case between the fetches of a stream, so such a cancel used to be lost and the stream ran to the end; once the cancel has been delivered, the next fetch raises `QueryCanceled` (buffered rows are still delivered first), and a cancel still in flight when the stream ends is waited for.
- PostgreSQL driver cancel follow-up: every request, not only streams, waits for a `Session#cancel` that is still on its way before the session is handed on, and drops the session if it is not delivered within about twice `cancel_grace` (a cancel counts as delivered once written and the hang-up wait ended, even if the peer never hung up; a cancel begun while no request holds the session is not covered); a pool health-check ping on a session with a cancel pending reports it unhealthy; a cancel's own connect (name lookup included, not a Unix socket) and wait for the postmaster's hang-up are each capped at `cancel_grace` (`Session#cancel_grace` now also bounds those and the wait, not only the time between a timeout and the socket being closed); a `QueryCanceled` the driver raised itself (`CQL::Postgres::LocalCancel`) is no longer taken as the server's confirmation of a timeout cancel, so such a session is dropped instead of kept with a portal still open; a cancel that lands on a stream's cleanup is ignored.
- Typed model DSL: `Model.query.where { (age >= 18) & (status == "active") }` with bare column names typed to the column (unknown columns and type mismatches are compile errors), `order_by(created_at: :desc)` checked at compile time, `joins(:assoc) { ... }` / `left_joins`, `to_a`, and `Model.cql_columns` / `cql_association` metadata.
- Telemetry: `CQL::Telemetry.subscribe`, `alert_on_slow`, `log_queries`, `with_context` and an abstract `Tracer` for OpenTelemetry-style adapters; parameters are not captured unless `capture_params` is on.
- Transaction telemetry: `Telemetry.subscribe_transactions` / `unsubscribe_transactions` publish `TransactionEvent`s (Begin, Commit, Rollback with id, duration, `nested`, `error`) from `Schema#transaction`; `Telemetry.subscribed?(name)` and `next_transaction_id`. `Schema#pool_stats` returns a `CQL::PoolStats` (`open`, `idle`, `in_flight`, `max`) without checking out a connection. A manual `tx.rollback` followed by a normal return still reports Commit.
- Unified execution: every statement runs through `CQL::Execution.run`; `Schema#with_connection` and `query.using(connection)` pin an explicit connection (e.g. a transaction).
- Safe raw SQL fragments: `where("lower(name) = ? AND age > :age", "ada", age: 18)` on `Query`, `QueryBuilder`, models, associations, `Update` and `Delete`, plus `raw(...)` inside `where { }` blocks and `CQL.raw`. Values are always bound as parameters (arrays expand to `IN (?)` lists, `??` is a literal `?`, quoted text and comments are skipped); a value given in the wrong placeholder style raises instead of being dropped. The fragment text must be a literal, never built from user input. `nil` binds NULL (`name = ?` never matches it; use `IS NOT DISTINCT FROM ?`).
- Window functions: `query.window(:row_number, as: :dept_rank, partition_by: :dept, order_by: {salary: :desc})`, aggregates over a window (`window(:sum, :salary, as: :running, order_by: :id, rows: {:unbounded_preceding, 0})`), `lag`/`lead`/`first_value`/`last_value`/`ntile`/`rank`/`dense_rank`/`percent_rank`/`cume_dist` and ROWS/RANGE frames. Needs MySQL 8.0+ and SQLite 3.25+. On MySQL, avoid window function names (`rank`, `row_number`, ...) as aliases unless `quote_identifiers` is on.
- Upsert and bulk upsert: `insert.on_conflict(:email).do_update(:name, visits: 1)`, `.do_nothing`, and `insert.upsert(rows, conflict: [:email], update: [:name])` (`ON CONFLICT` on PostgreSQL/SQLite, `ON DUPLICATE KEY UPDATE` on MySQL). Not supported with `INSERT ... SELECT`. Needs SQLite 3.24+. On MySQL the conflict target is ignored: any unique key triggers `ON DUPLICATE KEY UPDATE`.
- CockroachDB: `CQL::Adapter::CockroachDB` (`cockroachdb://` URLs, opened through the PostgreSQL driver) with a dialect that inherits PostgreSQL's SQL (`Int32` columns are declared `INT4`, since CockroachDB's `INTEGER` is 64-bit); it shares PostgreSQL's query features, but `structure_dump` is unsupported. The CA path is passed as `sslrootcert`.
- Row locking `query.lock(:update | :share, skip_locked:, nowait:)` (PostgreSQL, MySQL, CockroachDB; SQLite raises `CQL::DialectError`), `distinct_on(:col)` (PostgreSQL, CockroachDB), `FULL` and `CROSS` joins (`full(:t) { |j| ... }`, `cross(:t)`; MySQL has no FULL JOIN).
- Predicates: `ilike` / `not_ilike` (native `ILIKE` on PostgreSQL, `LOWER()` comparison elsewhere), `not(...)` / `.not` on conditions, `count(:col, distinct: true)`.
- JSON: `col.json_eq(path, value)` (value at a key/index path compared as text) and `col.json_contains(json)` (PostgreSQL `@>`, MySQL `JSON_CONTAINS`; not on SQLite), with the path always bound as a parameter. Geospatial: `col.within_distance(longitude, latitude, meters)` (`ST_DWithin` on geography for PostgreSQL/CockroachDB, `ST_Distance_Sphere` with a long-lat point on MySQL 8.0.13+; the MySQL form is unverified against a live server and expects an SRID 4326 column).
- Set operations: `union`, `union_all`, `intersect`, `except` on queries and on each other (`CompoundQuery`), executable like any query. Operands with their own `ORDER BY`/`LIMIT` or nested set operations are grouped (derived tables on SQLite). Ordering the combined result is not supported yet. MySQL needs 8.0.31+ for `INTERSECT`/`EXCEPT` and 8.0.18+ for `EXPLAIN ANALYZE`.
- `query.to_sql(for: CQL::Adapter::Postgres)` renders SQL for another dialect without a connection, and `query.explain(analyze: false)` returns the database's execution plan (SQLite `EXPLAIN QUERY PLAN`, PostgreSQL/MySQL `EXPLAIN [ANALYZE]`).
- Common table expressions and derived tables: `query.with(:totals, subquery).from(:totals)`, `with_recursive(:tree, anchor) { |step| ... }` for `WITH RECURSIVE`, and `from(subquery, as: :alias)`. The CTE/subquery's selected columns (and aliased aggregates) are addressable in the DSL like any table. `with(:b) { |scope| ... }` builds a CTE that can read earlier ones, and `query.nested` gives subqueries access to the query's CTEs. Available on `CQL::Query` (not on `QueryBuilder`/models yet). Needs MySQL 8.0+ and SQLite 3.8.3+.
- `CQL::Executable`: one shared implementation of `all`, `get`, `each`, `to_sql` and `explain` (result cache and performance tracking included) for every executable statement.

- Comprehensive CHANGELOG.md for tracking changes
- Performance monitoring system with N+1 query detection
- Multi-layer caching architecture (memory, Redis, fragment, request-scoped)
- Query profiling and slow query detection
- Advanced configuration system via `CQL.configure`
- Support for UUID and ULID primary keys
- Optimistic locking support
- Soft delete functionality
- Query scopes for reusable query patterns
- Lifecycle callbacks (before/after validation, save, create, update, destroy)
- Comprehensive validation system
- Schema dump functionality for reverse-engineering databases
- Migration system with rollback support
- Support for Active Record, Repository, and Data Mapper patterns
- Full support for PostgreSQL, MySQL, and SQLite
- Compile-time FK/PK validation for `belongs_to` and `has_many`, including associations whose target model is defined later in the program
- Opt-in schema mapping validation via `CQL_VALIDATE_SCHEMA_MAPPINGS=1`
- **New API methods for consistency (v0.0.436+)**:
  - `Query#get!` - Raises exception if scalar value not found (matches `first!` pattern)
  - `Query#where_null(field)` - Explicit IS NULL condition for better clarity
  - `Query#where_not_null(field)` - Explicit IS NOT NULL condition for better clarity

### Changed

- **Behavior change:** `QueryBuilder#select(:a, :b)` now returns a builder whose results are `Model::Row` records (unselected columns are `nil`) instead of hydrating a full model that failed for non-nilable attributes. `QueryBuilder#where { }` now yields typed bare columns; `ids` goes through the executor. Use `Model.query.select(...)` results as `Model::Row`, not `Model`.
- **`QueryBuilder#where { }`, `join { }`, `left { }`, `right { }` return a new builder** like every other builder method; they no longer also mutate the receiver. Use the returned value.
- `NOT (...)` conditions are always parenthesized (`NOT a AND b` negated only `a`).
- `Insert`/`Update`/`Delete` raise `ArgumentError` ("Column x not found in table") for an unknown column; they used to raise `KeyError`, so a `rescue KeyError` around them must change.
- `Query#first` no longer temporarily rewrites the query's limit; it runs a copy with `LIMIT 1`.
- Aggregates accept `as:` (a Symbol) for a select-list alias: `count(:id, as: :n)`.
- Opt-in identifier quoting: `CQL::Schema.define(..., quote_identifiers: true)` quotes table, column and alias names (double quotes, backticks on MySQL). Default is off, so generated SQL is unchanged. Quoting covers queries and DML only; DDL (`build`, migrations, `alter`) is not quoted yet.

- Improved error handling with detailed exception hierarchy
- Enhanced N+1 query detection with better pattern recognition
- Optimized expression builder architecture
- Modernized configuration API with smart defaults
- Improved connection pool management
- Better type safety through Crystal's type system
- Clearer CQL-specific compile-time errors for malformed relationship macros

### Deprecated

- `cascade` parameter in relation collections (use `dependent: :destroy` instead)
  - Affects: `Collection` and `ManyCollection` classes
  - Migration: Replace `cascade: true` with `dependent: :destroy`
  - Will be removed in: v1.0.0

### Removed

- Unused backup code in `src/expression/expressions_backup.cr`

### Fixed

- Building a query no longer rewrites the table's primary key. It read `Table#primary`, which re-declared a default `id` (Int32) key, so after the first select `create_sql` declared an `Int64` key as `INTEGER`, a key not named `id` gained a second `id` key, and a keyless or plain-`id` table gained an `id` key. Query building and foreign keys use the new non-mutating `Table#primary_key`; a bare `primary` in a table block still declares the default key, and `primary(name, type)` now requires the name.
- `Model.create!(record)` with an Int32 primary key on PostgreSQL and CockroachDB no longer raises `DB::ColumnTypeMismatchError` (the `RETURNING` key is read as `INT4`).
- CQL's native PostgreSQL layer (`CQL::Postgres`) compiles against crystal-db 0.15, which made `DB::Connection#driver_name` abstract (`CQL::Postgres::Connection#driver_name` returns `"postgres"`). The SQLite, MySQL and `pg` drivers CQL's own specs use still need releases that support db 0.15. `script/check_db_compat` and the `crystal-db compatibility` workflow (also weekly, against the latest db) compile the native layer against crystal-db 0.13.1, 0.14.0, 0.15.0.
- `Model.create!(**fields)` and `Model.create!(attrs)` on PostgreSQL and CockroachDB now read the new key through `RETURNING` (as `create!(record)` already did for Int64 keys) instead of `last_insert_id`, which crystal-pg always reports as 0, so the row was inserted but `find!(0)` raised `DB::NoResultsError`. Int32 keys are read as `INT4`.
- Subqueries (`IN (SELECT ...)`, `EXISTS`, `INSERT ... SELECT`) no longer discard the parameters bound by the enclosing query (SELECT, UPDATE and DELETE), and PostgreSQL `$n` numbering now continues across them.
- Multi-row `INSERT` on PostgreSQL numbers each row's placeholders (it emitted `($1,$2),($1,$2)`); rows are aligned by column name and rows with a different column set raise `ArgumentError`.
- `OFFSET` without `LIMIT` is no longer dropped (bare `OFFSET` on PostgreSQL, `LIMIT -1` on SQLite, maximum `LIMIT` on MySQL).
- Block DSL qualifies columns with the table alias (`from(customers: :c).where { c.city == ... }`).
- `Update#where` / `Delete#where` AND with earlier conditions instead of replacing them.
- `QueryBuilder#having` builds a `HAVING` clause (it called `where`); `reverse_order` and `unscope` work; aggregates, `ids` and `reorder` no longer alter the builder they are called on.
- `mysql://` URIs are accepted by `Schema` (an empty host is rejected).
- `QueryBuilder#pick` no longer alters the builder it is called on; `Model.having` accepts implicit-self blocks.

- Connection pool configuration consistency
- Transaction rollback handling
- Error context in exception messages

### Security

- DDL identifiers that cannot be bound as parameters are now validated: index, foreign key, unique/check constraint names, rename targets and foreign key table/column names must match `[A-Za-z_][A-Za-z0-9_]*` (`DROP INDEX` also accepts one `schema.` qualifier). Anything else raises `ArgumentError` instead of being spliced into SQL. Names with other characters (hyphens, dots, spaces, non-ASCII) previously produced broken unquoted SQL.
- Aggregate aliases (`count(:id, as: "n")`) are validated the same way.

- SQL injection prevention in query builder
- Parameterized query support
- Prepared statement usage by default

## [0.0.435]

### Summary

Last release with its own heading in this file. Entries for later versions (up to 0.0.589) are listed under `[Unreleased]` above.

## Migration Guide

### Deprecated parameters

#### Deprecated `cascade` Parameter

**Deprecated:**

```crystal
has_many :posts, foreign_key: :user_id, cascade: true
```

**Preferred:**

```crystal
has_many :posts, foreign_key: :user_id, dependent: :destroy
```

**Dependency Options:**

- `:destroy` - Destroy associated records (runs callbacks)
- `:delete_all` - Delete associated records (no callbacks)
- `:nullify` - Set foreign key to NULL (default)
- `:restrict` - Prevent deletion if associations exist

## Version History

For detailed version history, see [GitHub Releases](https://github.com/azutoolkit/cql/releases).

---

## Contributing

When adding entries to this changelog:

1. Add new changes under `[Unreleased]` section
2. Use the following categories: Added, Changed, Deprecated, Removed, Fixed, Security
3. Write changes from user perspective (what changed, not how)
4. Link to relevant issues/PRs when applicable
5. Update migration guide for breaking changes

## Version Numbering

- **Major version (X.0.0)**: Incompatible API changes
- **Minor version (0.X.0)**: New functionality in backward-compatible manner
- **Patch version (0.0.X)**: Backward-compatible bug fixes
