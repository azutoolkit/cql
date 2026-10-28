# CQL v1.0 hardening plan (from .factory/source-plan.md)

Branch: all milestones on `claude/sharp-galileo-ygjvv3` (harness rule; one PR, or one per milestone if the user asks).
Process deviations from the factory defaults (repo rules win): the repo's `code-reviewer` agent plus Security and
Performance reviewers run on the STAGED diff before each src/spec commit (CQL CLAUDE.md); every fix ships a regression
spec that fails without it; behaviour changes go under CHANGELOG `[Unreleased]` (UPGRADE = an Upgrade notes entry).
Commands: BUILD/TYPECHECK = `crystal build --no-codegen src/cql.cr`; LINT = `crystal tool format --check src spec` +
`crystal run lib/ameba/bin/ameba.cr -- -f progress ./src ./spec`; TEST = `crystal spec`; FAST_TEST = `crystal spec <files>`;
docs = `python3 script/docs/check_links.py && python3 script/docs/check_nav.py && python3 script/docs/gitbook_lint.py`.
Baseline: 3233 examples, 0 failures, 19 pending (live PG 16 + SQLite; no MySQL/CockroachDB server).

## Design
- D1 `Schema#retrying_transaction(attempts = 3, isolation = nil, read_only = false, &)` in src/transaction_retry.cr; retries only 40001/40P01 (never 40003); ArgumentError inside an open transaction; jittered backoff 10ms*2^n capped 200ms.
- D2 `CQL::IsolationLevel` (old `CQL::Postgres::IsolationLevel` stays as alias); `isolation:`/`read_only:` on `Schema#transaction`, outermost only; dialect hooks `transaction_mode_sql`, `transaction_mode_before_begin?` (MySQL true).
- D3 native URL key `query_timeout` (seconds, default nil) applied in `Statement#run` and simple-query path; `CQL.configure` `pool.query_timeout` stays unwired.
- D4 do NOT map 57P01 to ConnectionLost at statement time (crystal-db retries exec too); detect dead idle connections before sending instead.
- D5 dialect hook `migration_lock_sql : String?`; PG `SELECT pg_advisory_xact_lock(?)` keyed by CRC32 of migrations table name; pending recomputed under the lock.
- D6 `Deleteable#delete!` calls `delete_row! : Bool`; `optimistic_locking` overrides it (Template Method).
- D7 `pool_reset=discard_all|reset_all`, engine pool only; crystal-db driver rejects it.
- D8 LIKE escape char `!` with `ESCAPE '!'` on every dialect.
- D9 default log source `cql`.
- D10 every breaking slice lands before one `(MAJOR)` commit, which only the user cuts.

## Milestone 1: Silent wrong data  (tier 2)
- [x] Slice 1: `delete!` on a stale record with optimistic locking raises instead of deleting (from S3.3, P3#1) (7a65ad0, +107)
      Criteria: stale `delete!` raises `CQL::OptimisticLockError` and the row survives; fresh `delete!` deletes; dependents roll back when it raises; SoftDeletable unchanged. UPGRADE.
      Files: src/active_record/deleteable.cr, src/active_record/optimistic_locking.cr, spec/patterns/active_record/optimistic_locking_spec.cr, CHANGELOG.md, docs/how-to/models/optimistic-locking.md
- [x] Slice 2: Duplicate migration versions raise at `Migrator.new` (from S5.2, P5#5) (82b58ea, +77)
      Criteria: two classes with the same version raise `Migrator::Error` naming both; nothing applied. UPGRADE.
      Files: src/migrations.cr, spec/core/migration_spec.cr, CHANGELOG.md, docs/how-to/migrations/create-migration.md
- [x] Slice 3: A version recorded by someone else mid-run aborts the batch instead of being skipped (from S5.2, P5#1) (c656c4d, +35)
      Criteria: SQLite: a migration whose `up` inserts its own version row makes `migrator.up` raise and its data change roll back; `record_migration` no longer skips silently.
      Files: src/migrations.cr, spec/core/migration_transaction_spec.cr, CHANGELOG.md, docs/how-to/migrations/run-migrations.md
- [x] Slice 3b: `Schema#close` on SQLite does not re-raise the error of a statement that failed earlier (found in slice 3) [dropped: upstream crystal-sqlite3 bug (`check finalize`), fixed in 0.24; CQL dev deps resolve sqlite3 0.21 because `pg ~> 0.29` holds crystal-db at 0.13]
      Criteria: SQLite: a failed unique insert, rescued, then `schema.close` returns without raising (today: SQLite3::Exception UNIQUE constraint failed, from sqlite3_finalize of the cached statement).
      Files: src/schema.cr or src/connection_source.cr, spec/core/schema_spec.cr, CHANGELOG.md
- [x] Slice 4: Concurrent PostgreSQL migrators serialise on an advisory lock and apply each migration once (from S5.2, P5#1) (f390ca6 +150, d03fb02 +28, 434c534 +65)
      Criteria: live PG: two schemas run `up` concurrently on a sleeping data migration -> 1 data change, 1 version row, no error; without the lock the second fails with the driver unique violation (review of slice 3); up_to/down/down_to recompute under the lock; generated-SQL spec pins nil lock for CockroachDB/MySQL/SQLite.
      Files: src/dialects/dialect.cr, src/dialects/postgres_dialect.cr, src/migrations.cr, spec/postgres/migrator_lock_live_spec.cr, spec/integration/dialects/postgres_dialect_spec.cr, CHANGELOG.md, docs/how-to/migrations/run-migrations.md
      Also (security review of slice 3): fix the slice-3 wording that says the unique index catches an uncommitted concurrent record (UNIQUE(version) is not guaranteed: tables built from a dumped schema lack it). PG: the lock protects; SQLite: writes serialise; MySQL/CockroachDB: both migrators still apply, run from one process. Update record_migration comment, CHANGELOG Fixed bullet and run-migrations.md.
- [x] Slice 4d (195e380 +44, 1fff0b6 +134): Migration lock wait is bounded (from perf review of slice 4)
      Criteria: MigratorConfig lock_timeout (default 60s, nil = unbounded); live PG: a second migrator waiting on a held lock raises Migrator::Error naming the migrations table after the timeout; applied via a dialect hook (SET LOCAL lock_timeout around acquisition).
      Files: src/migrations.cr, src/dialects/dialect.cr, src/dialects/postgres_dialect.cr, spec/postgres/migrator_lock_live_spec.cr, CHANGELOG.md, docs/how-to/migrations/run-migrations.md
      Also (slice 4 security confirmation, minors): wording: a waiting up(steps) applies the next pending migrations (not "finds nothing pending"); the unlocked pick runs CREATE TABLE IF NOT EXISTS outside the lock (fix wording or skip ensure in the unlocked pick); SQLite concurrent run fails with "database is locked"; down raises when its unlocked pick differs from the locked one; Upgrade note: building a migrator can block boot while another process migrates.
- [x] Slice 4c (ed52116, +95): SchemaDump writes `unique: true` for unique columns, so a schema rebuilt from the dump keeps them (from security review of slice 3)
      Criteria: SQLite/live PG: a table with a unique column dumps a declaration containing `unique: true`; the migrations table rebuilt from the dump rejects a duplicate version.
      Files: src/schema_dump.cr, spec/core/schema_dump_spec.cr, CHANGELOG.md
- [x] Slice 4b (029c91f): pending/applied migrations come from one query, not 2 per migration (from perf review of slice 2)
      Criteria: a statement-counting telemetry subscriber sees a constant number of statements for `pending_migrations` with 1 vs 20 registered migrations; behaviour unchanged.
      Files: src/migrations.cr, spec/core/migrator_steps_spec.cr, CHANGELOG.md
- [x] Slice 5: `default: "CURRENT_TIMESTAMP"` on any Time column emits the SQL keyword, not a string (from S5.1, P5#4) (d8d7dde, +117)
      Criteria: live SQLite `published_at` gets a real timestamp; live PG table creates; MySQL DATETIME(3) gets CURRENT_TIMESTAMP(3); detection keys on column type, not created_at/updated_at names.
      Files: src/expression/generator.cr, src/dialects/*_dialect.cr, spec/core/table_spec.cr, spec/integration/dialects/dialect_spec.cr, CHANGELOG.md, docs/how-to/models/timestamps.md
- [x] Slice 6: MySQL `rename_column` keeps NOT NULL and DEFAULT (from S5.1, P5#2) (see 6+7 commit, +122)
      Criteria: generated SQL `CHANGE old new <type> NOT NULL DEFAULT ...` from the declared column (Generator with Adapter::MySql).
      Files: src/expression/generator.cr, src/dialects/mysql_dialect.cr, spec/integration/dialects/mysql_dialect_spec.cr, CHANGELOG.md, docs/reference/api/migration-dsl.md
- [x] Slice 7: `change_column` keeps the column's null/default in the declaration and in MySQL `MODIFY` (from S5.1, P5#2) (see 6+7 commit, +122)
      Criteria: after `change_column :age, Int64`, `columns[:age].null?`/`.default` unchanged on all dialects; MySQL MODIFY carries them.
      Files: src/alter_table.cr, src/expression/generator.cr, spec/core/alter_table_spec.cr, spec/integration/dialects/mysql_dialect_spec.cr, CHANGELOG.md, docs/reference/api/migration-dsl.md

## Milestone 2: Secrets, PII, tenant isolation  (tier 3: secrets/PII)
- [x] Slice 8 (40e2a2c, +51): A failed insert is no longer logged at ERROR with the driver message (from S4.3, P4#1)
      Criteria: Log.capture sees no entry from commit/get on a unique violation; exception propagates; telemetry event carries the error.
      Files: src/insert.cr, spec/operations/insert_spec.cr, CHANGELOG.md
- [x] Slice 8b (f9e63ac, +51): `RelationError` from `safe_db_operation` keeps the driver error as `cause:` with a generic message (from review of slice 8)
  - also (security minors of slice 11): reword src/postgres/driver.cr:7 (the pg shard always takes postgres:// when linked, whatever the require order) and say in docs/how-to/observability/telemetry.md that capture_params on also logs values at `db` Debug on the native driver
      Criteria: a dependent delete failing with a driver error raises RelationError whose message does not contain the driver text (values), and `cause` is the driver exception.
      Files: src/active_record/relations/base_relation.cr, spec/patterns/active_record/base_relation_spec.cr, CHANGELOG.md
- [x] Slice 8d (675c4ae, +24): `Scopes.evaluate` (src/active_record/scopes.cr:145) names only the error class and keeps `cause:` instead of copying `ex.message` into its ArgumentError (from security review of 8b)
- [x] Slice 8c (1ec0cf1, +89 -89): With include_params off, the monitor logs and stores failed statements' errors as class + SQLSTATE/code only (from security review of slice 8)
      Criteria: a pg-shard error whose message carries an unquoted value (trigger RAISE 'rejected name %') does not appear in the monitor's `Query failed` log line nor in QueryData#error/export_metrics_as_json; with include_params on, the message is kept.
      Files: src/performance/sql_formatter.cr, src/performance/monitor.cr, spec/performance/*_spec.cr, CHANGELOG.md, docs/explanation/safety-guardrails.md
- [x] Slice 9: The generated schema file escapes its URI literal (21a99e0, 9+10 +73) (from S5.2, P5#6)
      Criteria: a password with `"` or `#{` produces a file that compiles and holds the same string.
      Files: src/schema_dump.cr, spec/core/schema_dump_spec.cr, CHANGELOG.md
- [x] Slice 9b (1a2b174, +66): SchemaDump writes database-supplied names safely (from security review of slice 4c)
      Criteria: a table/column/FK name containing `"`, newline or `#{` produces a schema file that compiles and declares that exact name (`:"..."` via inspect); SQLite PRAGMA table_info/foreign_key_list use the bound pragma_*(?) forms; MySQL DESCRIBE quotes the identifier. A decoy table survives a crafted name.
      Files: src/schema_dump.cr, spec/core/schema_dump_spec.cr, CHANGELOG.md
- [x] Slice 10: The generated schema file omits the password (21a99e0, 9+10 +73) (from S5.2, P5#6) [blocked by Q1]
      Criteria: output contains no password whatever auto_sync is. UPGRADE.
      Files: src/schema_dump.cr, spec/core/schema_dump_spec.cr, CHANGELOG.md, docs/how-to/migrations/schema-dump-and-validation.md
- [x] Slice 10b (43a62b6, +102): Schema file fallback drops credential-like query params and the fragment; the env var name is configurable (from security review of 9+10)
      Criteria: `?sslpassword=`, `?Password=`, `?api_key=`, `?app.token=`, `?options=` and a `#fragment` never reach the file (allowlist of known non-secret keys, case-insensitive); `dump_to_file`/MigratorConfig take an env var name (default "DATABASE_URL"), emitted via inspect.
      Files: src/schema_dump.cr, src/migrations.cr, spec/core/schema_dump_spec.cr, CHANGELOG.md, docs/how-to/migrations/schema-dump-and-validation.md
- [x] Slice 9c (f9a23c1, +147): SchemaDump refuses table/column/FK names that are not valid identifiers (from security review of 9b: escaped names became a second-order SQL injection when the dumped schema is built, since CQL's DDL does not quote)
      Criteria: a dump of a SQLite/PG table or column named like `t(id int);DROP TABLE decoy;--` or `note TEXT, injected TEXT)--` raises SchemaDump::Error naming it (fail closed, as the compile error did before 9b); on_delete/on_update are mapped to the fixed set (fixes SQLite 'no action' vs no_action); plain names unchanged.
      Files: src/schema_dump.cr, spec/core/schema_dump_spec.cr, CHANGELOG.md, docs/how-to/migrations/schema-dump-and-validation.md
- [x] Slice 10c (470971d, +22): Fallback allowlist splits pairs on `&` and `;`, matches ASCII-only keys, and gives no fallback for ambiguous userinfo (blocker from security review of 10b, introduced by an orchestrator-applied minor fix)
      Criteria: `?sslmode=require;password=pw_leak&application_name=app;api_key=key_leak` keeps no secret; a Kelvin-sign key is dropped; `app:abc:def@db` and `app:p@ss@x` give `ENV[...]` with no fallback.
      Files: src/schema_dump.cr, spec/core/schema_dump_spec.cr, CHANGELOG.md
- [x] Slice 9d (12bf9bc, +62): SchemaDump name-check polish (from security review of 9c, minors)
      Criteria: FK local/referenced names are checked with CQL::Identifier.valid? (what the FK DDL requires), so a dump never writes a file it cannot build; a non-UTF-8 name raises SchemaDump::Error naming the table, not ArgumentError; check_rule has a direct spec; docs say reserved words (select, order, ...) must also be renamed; optionally refuse Hangul filler code points.
      Files: src/schema_dump.cr, spec/core/schema_dump_spec.cr, docs/how-to/migrations/schema-dump-and-validation.md, CHANGELOG.md
- [x] Slice 9e (e7c5001, +110): SchemaDump refuses names a build silently misreads (from security review of 9d, pre-existing since 9c): the column names `constraint` (SQLite: read as a table constraint, the column vanishes) and `like` (PostgreSQL: read as a LIKE clause), case-insensitive; on PostgreSQL/CockroachDB any name with an ASCII uppercase letter (unquoted DDL folds it, so `Users` and `users` collapse into one table)
      Criteria: live SQLite `constraint` column and live PG `like` column and `"Users"` table raise SchemaDump::Error naming the table; the live specs also build the dumped schema of an accepted case (create! and compare columns); docs sentence on reserved words rewritten. Must land before any release (security condition).
      Files: src/schema_dump.cr (+ a dialect hook for case folding), spec/core/schema_dump_spec.cr, spec/postgres or the PG schema dump spec, docs/how-to/migrations/schema-dump-and-validation.md, CHANGELOG.md
- [x] Slice 11 (a306dd4, +51): Native driver `db` Debug log includes bound args only when `Telemetry.capture_params` is on (from S4.3, P4#2)
      Criteria: Debug on + capture_params false: query, no args; capture_params true: args.
      Files: src/postgres/statement.cr, spec/postgres/connection_spec.cr, CHANGELOG.md, docs/how-to/observability/telemetry.md
- [x] Slice 12 (fbdffb3, +102): `pool_reset=discard_all` resets engine connections on return (reset_all dropped after review) (from S2.1, P3#4)
      Criteria: live PG: set_config('app.tenant','a',false) not visible to next borrower; unknown value ArgumentError; crystal-db driver rejects the key pointing to EngineSource.
      Files: src/postgres/config.cr, src/postgres/pool.cr, src/postgres/driver.cr, spec/postgres/pool_spec.cr, spec/postgres/driver_spec.cr, CHANGELOG.md, docs/how-to/postgres-native/async-engine.md
- [x] Slice 13 (6d608e3, +127): `contains`/`starts_with`/`ends_with` escape `%`, `_`, `!` and bind the pattern (from S6.2, P4#8)
      Criteria: to_sql `{"... LIKE ? ESCAPE '!'", ["%50!%%"]}`; live SQLite "50%" matches only literally; MySQL/PG SQL pinned; tutorial uses contains.
      Files: src/expression/base_expression.cr, src/expression/generator.cr, src/dialects/dialect.cr, spec/core/query_spec.cr, spec/integration/dialects/mysql_dialect_spec.cr, CHANGELOG.md, docs/how-to/querying/filter-records.md, docs/tutorials/building-a-blog/04-crud-operations.md

## Milestone 3: Hangs and failover  (tier 2)
- [x] Slice 14 (7e7ec5c, +130): `query_timeout` bounds every native-driver statement (from S2.2c, P3#2)
      Criteria: BlackholeProxy + query_timeout=1 raises QueryTimeout within timeout+grace; pool slot free after; no key = unchanged.
      Files: src/postgres/config.cr, src/postgres/statement.cr, spec/postgres/blackhole_spec.cr, CHANGELOG.md, docs/how-to/postgres-native/async-engine.md, docs/how-to/configuration/connection-pooling.md
- [x] Slice 14b (281c803, +90): A timeout that drops the session inside a transaction surfaces as `QueryTimeout`, not `DB::ConnectionLost` from crystal-db's ROLLBACK on a closed session; `ping` never takes the default deadline (from security review of 14)
      Criteria: FakePG answering BEGIN then silent: `transaction { exec }` raises QueryTimeout; savepoint rollback likewise; ping on a silent FakePG with query_timeout=0.1 sends no cancel. Also (security minors of 14): `query_timeout=1e-10` is refused (a sub-nanosecond value parses to a zero span); the pg-shard warning also fires where a crystal-db Schema opens a URL carrying query_timeout under another driver (schema.cr open, not only CQL.configure), and its text says it concerns schemas opened through crystal-db. Optional (perf minor of 14): split `with_deadline` so the nil path builds no closure (-64 B/stmt).
      Files: src/postgres/connection.cr, spec/postgres/query_timeout_spec.cr, CHANGELOG.md
- [x] Slice 15 (e8cfe16, +112): After a server restart the engine pool fails no caller (from S3.2, P3#3)
      Criteria: live PG: pg_terminate_backend on 3 idle connections, then 3 sequential queries all succeed.
      Files: src/postgres/pool.cr, src/postgres/session.cr, spec/postgres/engine_source_live_spec.cr, CHANGELOG.md, docs/how-to/postgres-native/async-engine.md
- [x] Slice 16a (fced483, +136): A statement whose request reached the server never surfaces as `DB::ConnectionLost`, so crystal-db's pool (retry_attempts, 3 by default) never re-runs it (from security review of 15: a committed INSERT whose response was cut ran twice on DB.open)
      Criteria: through DB.open / CQL::Schema on postgres://, a proxy that cuts the connection after the INSERT's CommandComplete reached the client... (rather: after the server committed and before the reply) leaves exactly 1 row and raises; a connection lost before anything was sent still maps to DB::ConnectionLost (retried).
      Files: src/postgres/statement.cr, src/postgres/connection.cr, src/postgres/session.cr, spec/postgres/*, CHANGELOG.md
- [x] Slice 16 (folded into 16a, fced483): The default `postgres://` Schema (crystal-db pool, native driver) replaces dead idle connections at checkout (from S3.2, P3#3)
      Criteria: before_checkout peeks and raises DB::ConnectionLost before sending; retry never wraps the block; live PG scenario as slice 15.
      Files: src/postgres/connection.cr, src/connection_source.cr, spec/postgres/live_spec.cr, CHANGELOG.md, docs/how-to/configuration/connection-pooling.md
- [x] Slice 16b (b151a4b, +127): CQL's own queries on a `CQL::Schema` without `source:` (`DatabaseSource#using_connection`, never retried by crystal-db) take another connection when the one lent is found closed before anything is sent (`DB::ConnectionLost` caused by `ConnectionClosed`), so a dead idle connection fails no caller there either (from implementer of 16a)
      Criteria: FakePG: a pooled idle connection closed by the server; the next `Model.create!`/`schema.exec` succeeds once on a new connection; a connection lost after sending still raises and is not retried.
      Files: src/connection_source.cr, spec/postgres/statement_retry_spec.cr, CHANGELOG.md
- [x] Slice 17 (5fd8b87, +109): Pool-timeout and connect errors name host:port without credentials (from S2.2c, P3#5)
      Criteria: PoolTimeout and refused-connect messages contain 127.0.0.1:<port>, never the password.
      Files: src/postgres/pool.cr, spec/postgres/pool_spec.cr, CHANGELOG.md
- [x] Slice 18 (6f44894, +145): Connecting during checkout is bounded by the remaining `checkout_timeout` (from S2.2c, P3#5)
      Criteria: checkout_timeout=1 + accept-but-silent peer fails in ~1s not ~6s. UPGRADE. Also (security minor of 16b): `DatabaseSource#checkout_open`'s loop shares that budget, so dead idle connections with pending input (a 5 s ping each) cannot add up past checkout_timeout.
      Files: src/postgres/pool.cr, src/postgres/connection.cr, spec/postgres/pool_spec.cr, CHANGELOG.md, docs/how-to/postgres-native/async-engine.md
- [x] Slice 18c (533e07e, +96): A connect within a checkout is capped as a whole by the checkout's deadline: a watchdog (as Session#with_hard_deadline) closes the socket at the deadline unless the handshake finished, so a peer that sends a byte at a time cannot stretch it (from security review of 18, measured: 0.3 s/byte startup took 2.4 s with checkout_timeout=1; a slowed TLS handshake ran > 8 s). Also: the SSLRequest limit gets a spec that fails without it (time must pass between open and the SSLRequest), and TCPSocket.new's per-address connect_timeout (N addresses x time left).
      Criteria: FakePG sending one startup message at 0.3 s/byte with checkout_timeout=1 fails < 1.4 s naming the server; docs/CHANGELOG say the whole connect is bounded.
      Files: src/postgres/session.cr, src/postgres/transport.cr, spec/postgres/checkout_budget_spec.cr, CHANGELOG.md, docs/how-to/postgres-native/async-engine.md
- [x] Slice 18b (9ddd778, +149): The crystal-db path (DB.open / CQL::Schema without source:) bounds a connect and the before_checkout ping by checkout_timeout, and DatabaseSource#checkout_open shares one budget across its loop (from slice 18 RED, examples parked in scratchpad/slice18b/checkout_budget_spec.full.cr examples 3-4)
      Criteria: open_native with checkout_timeout=1 and a silent peer fails < 1.75 s with DB::ConnectionRefused naming host:port; a Schema with 2 idle connections whose pings are never answered finishes < 1.75 s (INSERT once or not at all).
      Files: src/postgres/driver.cr, src/postgres/connection.cr, src/connection_source.cr, src/schema.cr, spec/postgres/checkout_budget_spec.cr, CHANGELOG.md
- [x] Slice 18d (30de5f0, +113): Unit spec for `CQL::CheckoutBudget` (nested `within` restores the outer scope, restored after a raise, repeated claims reuse the first deadline, a zero timeout, a spawned fiber sees nil, health checks share one half and a later one gets nil) (review minor of 18b; did not fit its budget)
      Files: spec/core/checkout_budget_spec.cr
- [x] Slice 19 (5779063, +149): `sslcert`/`sslkey` present a client certificate (from S2.2c, P3#9)
      Criteria: FakePG TLS with verify PEER accepts the client; missing file ArgumentError; keys leave UNSUPPORTED_LIBPQ.
      Files: src/postgres/config.cr, src/postgres/transport.cr, spec/postgres/transport_spec.cr, CHANGELOG.md, docs/how-to/postgres-native/tls-and-poolers.md

- [x] Slice 19b (89d8ef9, +84): Client-certificate follow-ups (from reviews of 19): warn once per path when sslkey has group/world permission bits (libpq's rule: 0600 if owned by the user, 0640 if root; warn, do not refuse: k8s secret mounts), docs say certs are only presented when TLS is negotiated (+ spec), troubleshooting line for TLSRefused 'certificate required'/encrypted key, pg_dump env forwards PGSSLCERT/PGSSLKEY/PGSSLROOTCERT (postgres_dialect.cr dump_env); docs say rotation must replace the files atomically (rename); docs warn that with the pg shard (driver: :db) an encrypted key still prompts (lib/pg loads it without the guard); a one-line comment on transport.cr's `lib LibSSL` reopen (delete if the stdlib gains SSL_CTX_set_default_passwd_cb_userdata)
      Files: src/postgres/config.cr, src/dialects/postgres_dialect.cr, spec/postgres/*, docs/how-to/postgres-native/tls-and-poolers.md, docs/how-to/troubleshooting/connection-errors.md, CHANGELOG.md

## Milestone 4: Transactions and locking  (tier 2)
- [x] Slice 20 (5f405a8, +134): `Schema#transaction(isolation:)` on PG, CockroachDB and SQLite (from S3.1, P3#7)
      Criteria: live PG SHOW transaction_isolation = serializable; CRDB SQL pinned; SQLite accepts :serializable, others DialectError; nested ArgumentError; old alias compiles.
      Files: src/isolation_level.cr, src/postgres/transaction_scope.cr, src/dialects/*.cr, src/schema.cr, spec/core/transaction_options_spec.cr, spec/postgres/live_spec.cr, CHANGELOG.md, docs/how-to/data-operations/transactions.md
- [x] Slice 21 (8c9ef5e, +141): MySQL isolation is set before BEGIN (from S3.1, P3#7)
      Criteria: hook returns SET TRANSACTION ISOLATION LEVEL ... with before_begin? true; spy records SET then BEGIN.
      Files: src/dialects/mysql_dialect.cr, src/schema.cr, spec/integration/dialects/mysql_dialect_spec.cr, CHANGELOG.md, docs/how-to/data-operations/transactions.md
- [x] Slice 22 (aee8dbf, +136): `Schema#transaction(read_only: true)` (from S3.1, P3#7) [blocked by Q4 for SQLite]
      Criteria: live PG INSERT raises 25006; MySQL SQL pinned.
      Files: src/dialects/*.cr, src/schema.cr, spec/core/transaction_options_spec.cr, CHANGELOG.md, docs/how-to/data-operations/transactions.md
- [x] Slice 22b (27a780d, +26): `Schema#transaction` refuses `read_only: true` when the dialect gives no statement for it (fail closed for a custom dialect that drops it) (from security review of 22; patch ready: scratchpad/slice22b.py apply)
      Criteria: a spec-local dialect returning nil for read_only makes `transaction(read_only: true)` raise DialectError before the block runs.
      Files: src/schema.cr, src/dialects/dialect.cr, spec/core/transaction_options_spec.cr
- [x] Slice 23 (852ce6f, +59): `Model.transaction` forwards isolation:/read_only: (from S3.1)
      Criteria: User.transaction(isolation: :serializable) reaches the Schema; existing `User.transaction { |tx| }` compiles.
      Files: src/active_record/transactional.cr, spec/patterns/active_record/transactional_spec.cr, docs/how-to/data-operations/transactions.md
- [x] Slice 24 (6f8ddba, +150): `Schema#retrying_transaction` re-runs the block on serialization failure or deadlock (from S3.1, P3#7) [scope by Q5]
      Criteria: SerializationFailure once -> commits on attempt 2, first rolled back; stops after attempts; non-retryable propagates; inside a transaction ArgumentError.
      Files: src/transaction_retry.cr, src/schema.cr, spec/core/transaction_retry_spec.cr, CHANGELOG.md, docs/how-to/data-operations/transactions.md
- [x] Slice 24b (0ae6fcc, +42): `retrying_transaction` never retries a run whose block ended the transaction itself (`tx.commit`/`tx.rollback` then a retryable error: the retry duplicated committed work, live probe) (security review of 24)
      Criteria: SQLite stand-in: tx.commit, then raise SerializationFailure -> runs == 1, one row, the error propagates.
      Files: src/schema/transaction_retry.cr, spec/core/transaction_retry_spec.cr, docs/how-to/data-operations/transactions.md
- [x] Slice 24c (05bcd81, +41): A COMMIT that fails on the native driver releases or drops the connection (crystal-db's TopLevelTransaction#commit raises before close!, leaving the pooled connection's @transaction flag set: every later transaction on it raises "There is an existing transaction"), so `retrying_transaction` retries a 40001/40P01 raised at COMMIT (SERIALIZABLE "during commit attempt", deferred constraints) (security review of 24, predates it)
      Criteria: live PG, pool of 1: a DEFERRABLE INITIALLY DEFERRED constraint trigger raising 40001 once -> retrying_transaction runs twice and commits; a later plain transaction works; plain transaction with a failing COMMIT leaves a usable pool.
      Files: src/postgres/connection.cr, spec/postgres/live_spec.cr
- [x] Slice 24e (55ffdbc, +39): A COMMIT the server answers with the ROLLBACK tag (the block swallowed a failed statement) raises instead of reporting success (security review of 24, predates it)
      Files: src/postgres/connection.cr, spec/postgres/*
- [x] Slice 24d1 (80f1d05, +150): Rollback hooks run only when nothing can have committed: not after the block ended the transaction itself (tx.commit/rollback then a raise), not after a COMMIT with an unknown outcome (lost reply, timeout: a dialect hook says which COMMIT errors are refusals), a raising hook neither stops the others nor masks the error, and `transaction(tx)` of another connection gets its own hooks; `Schema#on_rollback` public (security review of 24d: request_changes, 2 majors)
- [x] Slice 24d1b (fd081dc, +99): Rollback hooks after a `return`/`break` out of a transaction block whose COMMIT then fails: not run (the COMMIT failure lands in the block-level rescue during unwinding); the pre-existing double frame pop there (`KeyError: Missing hash key: Fiber` replacing the COMMIT error, popping the parent frame when nested) made idempotent; a nested block that committed an enclosing transaction (`outer.commit`) skips the savepoint's hooks (security review of 24d1)
- [x] Slice 24d1c (26947c3, +115): SQLite: only BUSY/LOCKED/CONSTRAINT COMMIT failures count as refused (IOERR/FULL/CORRUPT keep state); a refused SQLite COMMIT no longer leaves the pooled connection inside the transaction (later exec silently uncommitted); a request never sent (`DB::ConnectionLost` with cause `ConnectionClosed`) counts as refused (security review of 24d1)
- [x] Slice 24d2 (5d21b62, +106): A record inserted in a transaction that rolls back gets its new-record state back (id nil, dirty snapshot as before) (Q10 part 1; patch: scratchpad/slice24d-full.patch)
- [x] Slice 24f (c6b53c6, +124): `update!`/`save!` of an existing record raises when the UPDATE matched no row (deleted, or its insert rolled back); message names the model, never the id (Q10 part 2, UPGRADE) (security review of 24, escalated: a record saved in a rolled-back run keeps its id, so a retry updates 0 rows and reports success)
- [x] Slice 24g (98cb44c, +73): A record deleted (`delete!`, soft-delete `destroy`: `clear_id!`, `destroyed = true`) in a transaction that rolls back gets its id back, so a later `save!` does not insert a duplicate row (tester of 24d)
- [x] Slice 24h (0bfa438, +31): A DirtyTracking record updated in a transaction that rolls back is dirty again (its snapshot as before), so a later `save!` sends the UPDATE; an optimistic-lock version bumped in memory is reverted (tester of 24d)
- [x] Slice 24i (3d7c2ef, +68): Rollback hooks keep the order things happened after a savepoint released by hand (`sp.commit`) whose block goes on: hooks registered after the release go to the outer frame at once, the savepoint's older ones only when its block ends, so they run in the wrong order (a DirtyTracking record ends with the wrong snapshot: a change lost silently, or a lock version ahead of the row) (security review of 24h; predates it)
- [x] Slice 25 (0e96ea3, +89): `OptimisticLockError` carries model, id and expected version (from S3.3, P3#6)
      Criteria: fields populated by update! and delete!; message names model and versions, never the id (review of slice 1: keys can be natural/PII).
      Files: src/active_record/optimistic_locking.cr, src/update.cr, spec/patterns/active_record/optimistic_locking_spec.cr, CHANGELOG.md, docs/how-to/models/optimistic-locking.md
- [x] Slice 26 (1ca37ab, +67): `with_optimistic_lock` applies in `to_sql` without mutating the builder or the schema column (from S3.3, P3#8)
      Criteria: to_sql shows version predicate and SET; second commit raises OptimisticLockError with no duplicate SET; column untouched.
      Files: src/update.cr, spec/operations/update_spec.cr, CHANGELOG.md

- [x] Slice 26b (172efa5, +143): Association destroy paths run in one transaction (from review of slice 1)
      Criteria: ManyCollection#delete with dependent: :destroy, clear_with_destroy and Collection#clear(:destroy) roll back their join/target deletes when a target's delete! raises (stale locked target).
      Files: src/active_record/relations/many_collection.cr, src/active_record/relations/collection.cr, spec/patterns/active_record/many_collection_spec.cr, CHANGELOG.md

- [x] Slice 26b2 (6024d28, +85): The :delete_all destroy paths go all or none too, and a join model on another schema keeps working (split from 26b over budget; reviews of 26b)
      Criteria: many_to_many `delete` with :delete_all and `clear_with_delete` keep the join rows when the target DELETE is refused (SQLite trigger); a join model on another schema of the same SQLite file: `delete` and `clear` with :destroy succeed (the transaction is on Target.schema; on Through.schema they hit "database is locked", and on PG with an FK they hang).
      Files: src/active_record/relations/many_collection.cr, spec/patterns/active_record/relations/destroy_transaction_spec.cr, docs/how-to/relationships/many-to-many.md, CHANGELOG.md. Saved work: scratchpad 26b2/.

## Milestone 5: Migrations for production deploys  (tier 2)
- [x] Slice 26c (9578993, +139): Extract the migration lock into a `MigrationLock` collaborator (refactor; from review of slice 4d: src/migrations.cr is ~525 lines)
      Criteria: behaviour unchanged (all migration specs green); Migrator delegates lock_migrations/within_lock_timeout/require_read_committed!/migration_lock_key; src/migrations.cr shrinks below ~450 lines.
      Files: src/migrations.cr, src/migration_lock.cr
- [x] Slice 27 (d9bb0bd, +137): `disable_ddl_transaction!` runs one migration outside the batch transaction (from S5.2, P5#8) [blocked by Q3]
      Criteria: live PG CREATE INDEX CONCURRENTLY succeeds; SQLite batch splits around the flagged migration; earlier ones stay committed if it fails.
      Files: src/migrations.cr, spec/core/migrator_steps_spec.cr, spec/postgres/migrator_lock_live_spec.cr, CHANGELOG.md, docs/reference/api/migration-dsl.md, docs/how-to/migrations/indexes.md
- [ ] Slice 27a (WIP, parked on branch claude/sharp-galileo-ygjvv3-wip, 150 lines, suite green 3453): code review request_changes, two majors: (1) a pool of one now fails every flagged migration (DB::PoolTimeout: hold_alone keeps the only pooled connection); (2) inside a caller's transaction the session lock is taken in that transaction, the ensure unlock fails after an abort, masks the real error and leaves the lock on a pooled connection. Planned fix: hold the turn on a connection of its own, `DB.connect(URI.parse(schema.adapter.driver_uri(schema.uri)))`, outside the pool and any transaction; closing it ends the lock (drop `migration_session_unlock_sql`); drop the `not_nil!` (minor); specs for a pool of one and for a failing flagged migration inside `schema.transaction` (real error raised, another session can take the turn); docs: "opens a connection of its own for the turn" instead of "the pool needs two". Security review was stopped mid-way (its probes P1 held); re-run both reviews. If over budget, move the how-to section to a docs-only commit.
      Original entry: Migrators take turns on a `disable_ddl_transaction!` migration (user decision 2026-10-28, replaces Q3; security review of 27: concurrent CREATE INDEX CONCURRENTLY deadlocked 19/20 runs and the survivor could record an INVALID index)
      Criteria: PG: a session advisory lock under a second key, held on one pooled connection outside any transaction (taken in a short transaction so the lock_timeout bound applies), around re-check + `up` + record; live race of two migrators on one flagged CREATE INDEX CONCURRENTLY: no deadlock, exactly one record, the waiter skips it; the lock_timeout message no longer says "ran nothing" for a later batch; how-to section (scratchpad 27a/) with DROP INDEX CONCURRENTLY IF EXISTS + CREATE INDEX CONCURRENTLY, so a re-run repairs an INVALID index; docs: needs a pool of 2 on PG. From the review of 27 v2: a rollback takes only the first key, so keep the record step's prefix check under it (or have down take the second key); the lock_timeout on the record step leaves a migration that ran unrecorded and says "ran nothing"; apply_alone's pre-lock oldest_pending message says "waited for the migration lock", and the record-step one says "not applied" although the migration ran (unrecorded); spec the record-step raise; align "runs nothing" in CHANGELOG (lock_timeout entry, Upgrade note) with the new message.
      Files: src/migration_lock.cr, src/migrations.cr, src/dialects/dialect.cr, src/dialects/postgres_dialect.cr, spec/postgres/migrator_lock_live_spec.cr, docs/how-to/migrations/indexes.md, docs/reference/api/migration-dsl.md, CHANGELOG.md
- [ ] Slice 27b: A rollback runs a `disable_ddl_transaction!` migration's `down` alone too (split from 27 over budget)
      Criteria: live PG DROP INDEX CONCURRENTLY in down succeeds; SQLite: the rollback batch splits around it, the newer ones stay reverted if it fails; under the lock each batch must still be the newest applied migrations (a waiter raises instead of reverting a middle one); docs/CHANGELOG drop "down still runs in the rollback's transaction".
      Files: src/migrations.cr, spec/core/migrator_steps_spec.cr, spec/postgres/migrator_lock_live_spec.cr, CHANGELOG.md, docs/reference/api/migration-dsl.md, docs/how-to/migrations/indexes.md
- [ ] Slice 28: `CQL::IrreversibleMigration` raised in `down` aborts the rollback naming the migration (from S5.2, P5#9)
      Criteria: SQLite: batch rolled back; no version rows removed.
      Files: src/migrations.cr, spec/core/migration_transaction_spec.cr, CHANGELOG.md, docs/how-to/migrations/rollback.md
- [x] Slice 29: An auto_sync write failure after commit logs WARN and `up` returns (from S5.2, P5#6) [pulled into slice 9c fix round]
      Criteria: unwritable path: up returns, migrations recorded, WARN logged. UPGRADE.
      Files: src/migrations.cr, spec/core/migrator_schema_file_spec.cr, CHANGELOG.md, docs/how-to/migrations/schema-dump-and-validation.md
- [ ] Slice 30: How-to page for zero-downtime expand/contract (from S5.2)
      Criteria: snippets compile (compile_snippets.py); check_nav passes.
      Files: docs/how-to/migrations/zero-downtime.md, docs/SUMMARY.md, docs/how-to/README.md

## Milestone 6: Boot and compile-time safety  (tier 2)
- [ ] Slice 31: `has_one` checks foreign-key existence and type at compile time (from S1.1, P1#10)
      Criteria: missing/mistyped FK fails with "CQL has_one error". UPGRADE (compile).
      Files: src/active_record/model.cr, spec/patterns/active_record/compile_time_safety_spec.cr, CHANGELOG.md, docs/how-to/troubleshooting/schema-mapping-errors.md
- [ ] Slice 32: `db_context` to an undeclared table raises SchemaMappingError on first use instead of KeyError (from S1.1, P1#11)
      Criteria: message names model, table and schema.
      Files: src/active_record/definition.cr, spec/patterns/active_record/definition_spec.cr, CHANGELOG.md, docs/how-to/troubleshooting/schema-mapping-errors.md
- [ ] Slice 33: An unsupported column type raises at declaration (from S1.1, P1#12)
      Criteria: `column :x, Int16` raises CQL::Error listing supported types before create_sql.
      Files: src/table.cr, spec/core/column_types_spec.cr, CHANGELOG.md, docs/reference/api/migration-dsl.md
- [ ] Slice 34: The validator flags model properties with no column, with a virtual opt-out (from S1.2, P1#3) [blocked by Q9]
      Criteria: unmapped nickname flagged; virtual property not; create! unchanged.
      Files: src/active_record/schema_validator.cr, src/active_record/definition.cr, spec/patterns/active_record/definition_spec.cr, CHANGELOG.md, docs/how-to/migrations/schema-dump-and-validation.md
- [ ] Slice 35: `SchemaValidator.validate_all!` checks every model at boot (from S1.2, P1#14)
      Criteria: raises SchemaMappingError listing every mismatch.
      Files: src/active_record/schema_validator.cr, src/active_record/definition.cr, spec/patterns/active_record/definition_spec.cr, CHANGELOG.md, docs/how-to/troubleshooting/schema-mapping-errors.md

## Milestone 7: Observability  (tier 2)
- [ ] Slice 36: The default logger source is `cql` (from S4.3, P4#5)
      Criteria: CQL.config.logger.source == "cql" in every environment. UPGRADE.
      Files: src/configure.cr, spec/configure/configure_spec.cr, CHANGELOG.md, docs/reference/configuration.md, docs/installation.md
- [ ] Slice 37: `log_queries` emits structured metadata (from S4.3, P4#6)
      Criteria: entry metadata has sql, operation, duration_ms, rows, and error when failed.
      Files: src/telemetry.cr, spec/performance/telemetry_spec.cr, CHANGELOG.md, docs/how-to/observability/telemetry.md
- [ ] Slice 38: `AsyncEngine#transaction` publishes TransactionEvents (from S4.1, P4#7)
      Criteria: live PG subscriber sees Begin then Commit, or Rollback on raise.
      Files: src/postgres/async_engine.cr, spec/postgres/async_engine_spec.cr, CHANGELOG.md, docs/how-to/observability/telemetry.md
- [ ] Slice 39: Engine pool stats report waiters and timeouts (from S4.1, P4#7)
      Criteria: saturated pool size 1 -> stats.waiting == 1; after a timeout stats.timeouts == 1.
      Files: src/postgres/pool.cr, src/pool_stats.cr, spec/postgres/pool_spec.cr, CHANGELOG.md, docs/how-to/observability/monitoring.md
- [ ] Slice 40: The N+1 detector counts per telemetry context (from S4.2, P4#4)
      Criteria: two contexts each threshold-1 times -> nothing flagged; one context threshold times -> flagged; memory capped.
      Files: src/performance/n_plus_one_detector.cr, spec/performance/n_plus_one_detector_spec.cr, CHANGELOG.md, docs/how-to/performance/n-plus-one.md

## Milestone 8: Runbooks and release  (tier 0 docs; slice 45 tier 3)
- [ ] Slice 41: Production checklist page (from S6.3)
      Criteria: covers TLS, query_timeout, pool_reset, auto_sync false, log levels, capture_params; every cited option exists in src/.
      Files: docs/how-to/configuration/production-checklist.md, docs/SUMMARY.md, docs/how-to/README.md
- [ ] Slice 42: connection-pooling page links the pooler section and adds sizing guidance (from S6.3, P4#10)
      Criteria: check_links passes.
      Files: docs/how-to/configuration/connection-pooling.md
- [ ] Slice 43: Migrating-from-ActiveRecord guide (from S6.3)
      Criteria: snippets compile.
      Files: docs/how-to/migrate-from-activerecord.md, docs/SUMMARY.md, docs/how-to/README.md
- [ ] Slice 44: Raw-fragment limits documented (from S6.2, P4#9)
      Criteria: page lists E'...\'', nested /* */, -- followed by \r.
      Files: docs/how-to/advanced-sql/raw-fragments.md
- [x] Slice 45: Cut 1.0.0 (from E3) [skipped: user cuts (MAJOR) on merge]
      Criteria: a single (MAJOR) commit; every Upgrade note under one heading.
      Files: CHANGELOG.md

## Changes from the source plan
- S1.3a dropped: CTE/recursive/window/set ops exist with correct $n numbering (7 combos generated).
- S1.2 live-DB strict mode reduced to validate_all! + unmapped-property check; live drift check deferred.
- S2.1 dropped: MT stress 64 fibers/8 threads clean, pool/session/cache state locked.
- S2.3 dropped: zero-allocation is the wrong goal (find 64us, I/O bound; generator already single-buffer).
- S3.2 circuit breaker replaced by dead-connection detection on lend (what actually fails callers).
- S3.1 deadlock detection: server already detects (40P01); CQL adds retry (slice 24).
- S4.1 no vendor exporters: telemetry is pluggable; missing events/counters added.
- S5.1 narrowed to reproduced dialect bugs; S5.2 expand/contract as a docs page (YAGNI).
- S6.1 mostly exists (blackhole, FakePG, timeouts, stress); slices add live specs per fix.
- S6.2 fuzzing deferred: 44 adversarial inputs found nothing, values always bound; tokenizer limits documented.
- E1/E2/E3 horizontal phases replaced by vertical slices with spec+docs+CHANGELOG each.

## Deferred
- Each insert/update/delete inside a transaction keeps a rollback closure (record + snapshot) until the outermost transaction ends: memory grows with the batch size; the snapshot proc is also built outside a transaction and dropped. Check for an active frame first (security minor of 24h).
- `update!`'s existence check locks with FOR UPDATE: on PostgreSQL/CockroachDB stronger than an UPDATE's FOR NO KEY UPDATE, so on the rare 0-count-but-exists path (suppress_redundant_updates_trigger, a blocking trigger) it blocks child-row inserts until the caller's transaction ends; a dialect hook for the lock mode (FOR NO KEY UPDATE on PG/CRDB, FOR UPDATE on MySQL/MariaDB). Custom dialects: `supports_row_locks?` defaults to true (security/code minors of 24f).
- Rollback hooks still run after a COMMIT the block sent as SQL (or a MySQL implicit commit): a record inserted before it is reset although its row was kept (documented). Mitigation: skip the hooks when the native driver reports the session no longer in a transaction at CQL's ROLLBACK (security minor of 24d2).
- After a failed COMMIT whose ROLLBACK also fails, `ConnectionSource#roll_back_or_release` keeps the connection for every driver (right for SQLite, where close half-fails); for MySQL/pg shard a ROLLBACK timeout could lend it inside an open server transaction: close unless SQLite; and a SQLite ROLLBACK failing before it runs (NOMEM) lends it inside the open transaction: bind sqlite3_get_autocommit (reviews of 24d1c).
- `Model.create!(attrs)`/`create!(**fields)` return a fresh record (find!/RETURNING) not reset by a rollback (24d covers `create!(record)`/`save!`); callbacks/timestamps on the instance are not undone; `transaction(tx)` with a raw DB::Transaction and no CQL frame registers hooks on a throwaway RollbackHooks (tester of 24d).
- DirtyTracking with a field without a default fails to compile (`initialize(__set_for_db_serializable)` does not initialize it) (tester of 24d).
- After a refused COMMIT the crystal-db TopLevelTransaction stays open (`tx.closed?` false) while the connection is released: a `tx` kept past its block could later send ROLLBACK/COMMIT on another borrower's connection (misuse only; security minor of 24c). Harden with a TopLevelTransaction subclass that closes itself.
- `retrying_transaction` does not detect a COMMIT/ROLLBACK statement the block sends itself (`tx.connection.exec("COMMIT")`): it retries and repeats committed work (docs say do not); a native-connection `in_transaction?` check behind a dialect/source hook would detect it (security minor of 24b).
- `retrying_transaction(attempts)` has no upper bound (1_000_000 attempts x up to 200 ms); nested retrying_transaction on another schema multiplies runs (security minor of 24).
- No spec pins the retry backoff bound/clamp (code review minor of 24).
- crystal-db (lib, 0.13.1) `Pool#close` iterates @total while `Connection#do_close` removes from it, so `DB#close` leaves other connections open (security review of 18b, upstream bug; consider reporting upstream or closing defensively in DatabaseSource#close).
- crystal-db's retry around exec/query/scalar starts a fresh checkout_timeout per attempt (0.5N+2.2 s with N dead idle connections and silent connects); and its own using_connection/transaction lend a dead idle connection after a failed ping (ConnectionLost after 0.5 s).
- Native driver connect: DNS resolution is unbounded (Crystal ignores dns_timeout on Unix) and TCPSocket.new gives each resolved address the full time left (2 dead addresses = 2x the budget); walk Socket::Addrinfo.tcp with time_left per attempt (security minor of 18c, predates it).
- FakePG failover specs assume single-threaded fibers (a FATAL written before the client resumes); under -Dpreview_mt with CRYSTAL_WORKERS>1 the 16b termination example flaked 2/25 (CI is single-threaded).
- The native driver sends the CancelRequest in cleartext even with sslmode=require/verify-full, exposing the backend's pid and secret on each expiry; PostgreSQL 17 accepts a CancelRequest after SSLRequest (security minor of 14, predates it). Candidate slice in M3.
- CockroachDB strips an `experimental_`/`testing_` prefix before `ranges` in unquoted names, so `experimental_ranges` names `ranges`; the dumper's fold does not model it (security minor of 9e, very unlikely).
- SchemaDump: a SQLite declared column type that is not valid UTF-8 raises ArgumentError from map_sql_type_to_crystal's regex instead of SchemaDump::Error (code review minor of 9d; SQLite only, no security impact).
- SchemaDump accepts NFKC and cross-script lookalikes (ｕsers, Cyrillic а) and letters that look like punctuation (U+01C3 reads `!`); they build byte-exact, so no SQL runs (security minor of 9d): document or refuse later.
- QueryData keeps the full driver message of a statement recorded while include_params was on; turning it off later still exports it (to_h filters params only). Fix: store both and pick in to_h(include_params:), or clear the profiler on the switch (security minor of 8c, predates it).
- `CQL::DSL` `widen` (src/active_record/dsl/column.cr:95) quotes the caller's filter value in its overflow ArgumentError; optional: drop the value (security minor of 8d).
- Driver SQL errors (`SQLite3::Exception`, `PQ::PQError`, MySQL's) are not `DB::Error`: an association operation lets them through raw (values in the message). Wrapping them changes what callers rescue, so it needs its own slice and an upgrade note (found by the slice 8b tester).
- Polymorphic associations, has_many through: (S1.3c): features, not hardening.
- JSON/geo operator expansion, CTE on DML/MATERIALIZED, raw fragments beyond WHERE (S1.3b): features.
- Engine connect retry/backoff (S2.2a): fail fast suits request handlers.
- sslmode=allow/verify-ca: no demand reproduced (fails safe today).
- MT cache-stats atomics (P3#10): stats only.
- MySQL text -> TEXT (P5#7): strict mode raises; fix breaks `text ..., unique:` (Q7).
- MySQL/CockroachDB migration locks: cannot run live here; docs say migrate from one process.
- table on QueryEvent, copy_out event, N+1 call-site capture: nice-to-have.
- Unsupported association option messages (P1#13): DX polish.
- Soft delete with lock version; typed AdminShutdown error; Eloquent guide.
- Spec for the pg-shard PQ::PQError branch of lock_timed_out? (review of 4d).
- sslkey containing `:` is read by libpq/pg_dump as an OpenSSL engine spec (`engine:key`), while CQL reads it as a path; structure_dump forwards it as PGSSLKEY unchanged (security minor of 19b, libpq behaviour).
- pg_dump `--dbname` with `=` in the database name is parsed as a connection string by libpq (security minor of 19b, predates it).
- `Schema` `macro method_missing` turns any call with an unknown named argument into a confusing macro error ("space required before colon") and blocks symbol-to-enum autocast; slice 20 works around it with a Symbol overload. Restrict the macro to argument-less calls (tester of 20).
- MySQL isolation (slice 21) is unverified live: `SET TRANSACTION` runs as a prepared statement (SET is preparable; SQLCOM_SET_OPTION); a text-protocol run would match other drivers and multiplexing proxies better. Verify on a MySQL server.
- crystal-sqlite3 0.21: closing a connection whose last statement failed segfaults later in Pool#close (finalize re-raises the error, the connection stays half-closed); found writing slice 21's spec. Fixed in later sqlite3 shards.
- Fallback for ambiguous userinfo (several @ or :) should be ENV only (review of 10b, minor).
- AsyncEngine reset: that does not deallocate (e.g. RESET ALL) still forgets the client statement cache and leaks server prepared statements; repeated pool_reset keys (review of 12).
- Specs for SchemaDump check_rule raise, auto_sync warning on down, explicit update_schema_file still raising (review of 9c).
- SchemaDump on MySQL: FK query reads UPDATE_RULE/DELETE_RULE from KEY_COLUMN_USAGE, which lacks them (REFERENTIAL_CONSTRAINTS has them): MySQL dumps may fail (unverified, no server; review of 9c).
- SchemaDump on SQLite: a foreign key referencing the parent's primary key implicitly (`REFERENCES t`) has NULL `to` and `read(String)` raises (pre-existing; review of 9b).
- A savepoint rolled back by hand (`sp.rollback`) hands its hooks down as kept work: its records keep the rolled-back state when the outer transaction commits (documented; reviews of 24i, predates it). Run its hooks at that rollback instead.
- Key values still interpolated into error messages (against the "never the id" rule of slices 1/25): belongs_to.cr:100 (`... with id #{fk_value} not found`), repository.cr:91 (`No records found with id=#{id}`), exceptions.cr:51 (`RecordNotFoundError`, public, not raised in src). Keep the value on a getter instead (security review of 25, predates it).
- `Update#set(version: x).with_optimistic_lock(...)` assigns the version column twice (PostgreSQL rejects it; SQLite/MySQL take the lock's value): `build` could raise ArgumentError when the setters already assign it (security review of 26, predates it).
- `Collection#clear` with :destroy counts a record whose before_destroy halted (`delete!` false) in its return value though the row stays (review of 26b, predates it).
- In-memory collections after an enclosing transaction rolls back: only the destroy paths (26b) reload; `create`, `delete_all`, `ids=` etc. keep their post-change @records (review of 26b).
- `parent.delete!` hangs on PostgreSQL when the join model is on the parent's schema, the target on another schema over the same database, and the join table has an FK to the target: the parent's transaction holds the join-row locks the target's DELETE waits for (security review of 26b, predates it).
- `MigrationTable#print` computes `name_width` but never pads or truncates the name, so a long migration name misaligns its row (seen moving it in 26c, predates it).
- Cross-process version clash (review of slice 2): azu_cli runs schema and data migrations in separate processes that share cql_schema_migrations; a data migration sharing a schema migration's version is treated as applied. Follow-up: compare recorded name with the registered class, or give data migrations their own migration_table_name in azu_cli.

## Open questions
- Q10 (slice 24d): after a rollback, (a) docs only, (b) reset the id/new-record state of records inserted in the rolled-back transaction (rollback hooks, as ActiveRecord), (c) `update!` raises when no row matched (UPGRADE), or (b)+(c)?
- Q1 (slice 10): schema file strips only the password, or emits ENV.fetch("DATABASE_URL", ...)?
- Q2 (slice 14): leave CQL.configure pool.query_timeout unwired, or make it Time::Span? = nil (breaks readers)?
- Q3 (slice 27): non-transactional migrations run outside the advisory lock ("must be idempotent"), or session lock?
- Q4 (slice 22): SQLite read_only raises DialectError or toggles PRAGMA query_only?
- Q5 (slice 24): retry only native PG/CockroachDB, or also MySQL 1213, SQLite BUSY, pg shard?
- Q3 revised (slice 27, 2026-10-28): migrators take turns on a disable_ddl_transaction! migration (session advisory lock outside a transaction); "idempotent" was not enough for CREATE INDEX CONCURRENTLY.
- Q6 (slice 18): acceptable that connects can fail earlier?
- Q10 (slice 24d): reset + raise: records inserted in a rolled-back transaction get their new-record state back (rollback hooks), and update!/save! of an existing record raises when no row matched (UPGRADE note).
- Q7 (deferred P5#7): text -> TEXT on MySQL with unique:/index: raising?
- Q8 (slice 45): one (MAJOR) at the end, or breaking changes as 0.x releases along the way?
- Q9 (slice 34): virtual property marker: @[CQL::Virtual] annotation or virtual_attributes macro?

## Grounding issues
- migrate_up wraps the whole batch in one ddl_transaction (migrations.cr:380-389), not one per migration; lock covers the batch; disable_ddl_transaction! must split it.
- P5#1 root cause: `unless migration_applied?` guard in record_migration (migrations.cr:429-433) turns the unique violation into a silent skip.
- P4#1: native PG class-23 messages already value-free; leak real for MySQL and pg shard.
- P3#3: mapping 57P01 to ConnectionLost contradicts documented FATAL contract (session.cr:507) -> D4.
- query_timeout exists as an unused 30s config (connection_pooling_config.cr:8) -> D3.
- P5#6: docs admit the password is written (schema-dump-and-validation.md:65); azu_cli passes auto_sync: false; plain migrator defaults true (migrations.cr:94).
- P5#2: change_column drops null/default on every dialect (alter_table.cr:120-125).
- P3#6: OptimisticLockError fields exist (exceptions.cr:165-175) but are not populated.
- P3#8: also mutates the shared schema column (update.cr:322-336).
- CQL's dev dependencies (`pg ~> 0.29.0`) resolve crystal-db 0.13 / sqlite3 0.21 / mysql 0.16, while azu_cli-generated apps use db 0.15 / sqlite3 0.24 / pg 0.31 / mysql 0.18. Driver bugs fixed upstream (SQLite finalize re-raise on close) still show in CQL's own suite.
- Live PG specs exist under spec/postgres and go pending without DATABASE_URL; live-PG slices follow that pattern.

## Decisions (user, 2026-10-27)
- Scope: build all milestones; stop at slices blocked by open questions.
- Q8: user cuts (MAJOR) on merge; Slice 45 skipped.
- Q1: schema file emits ENV.fetch("DATABASE_URL", "<url without password>").
- Q9: virtual property marker is the @[CQL::Virtual] annotation.

- M2 approved by user (tier 3) on 2026-10-27.
- Q3: non-transactional migrations run outside the advisory lock; docs require them to be idempotent.
- Q4: SQLite read_only transaction raises DialectError.
- Q5: retrying_transaction retries native PG/CockroachDB 40001/40P01 only.

- Q2 (slice 14): wire `CQL.configure` `pool.query_timeout`, changed to `Time::Span? = nil` (unset changes nothing); upgrade note for readers.
- Q3 revised (slice 27, 2026-10-28): migrators take turns on a disable_ddl_transaction! migration (session advisory lock outside a transaction); "idempotent" was not enough for CREATE INDEX CONCURRENTLY.
- Q6 (slice 18): yes, a connect during checkout is bounded by the remaining `checkout_timeout`; upgrade note.

## Deviations
- Slices under ~40 lines (22b, 23) are built test-first by the orchestrator (spec seen failing, then the code), reviewed as usual.
- Orchestrator-applied review fixes are re-reviewed before commit (10b: an unreviewed minor fix opened a `;` bypass).
- Slices 9 and 10 built as one slice: both change the same generated `uri:` line (escape + strip password via ENV.fetch fallback).
- Slices 6 and 7 built as one slice: both are MySQL CHANGE/MODIFY dropping restated attributes (one root cause), under 150 lines together.
- Slice 4 got a second request_changes (SERIALIZABLE snapshot; waiting rollback cascading). Instead of stopping, applied the reviewers' fail-closed fixes and ran a confirmation review; reported to the user.
- Review runs on the staged diff BEFORE the slice commit (CQL CLAUDE.md), so refactor + review fixes land in the slice commit.
- Refactorer skipped when the slice adds < 40 non-test source lines (token economy); the code-reviewer covers design quality.
- Slice 9d: the security review raised two blockers that predate the slice (from 9c's NAME_PATTERN; the 9d diff neither causes nor widens them). They became slice 9e, run right after 9d, instead of blocking 9d's commit.
- Slice 18: the security review's major (the deadline bounds each read, not the whole connect; a slow-drip peer stretches it) predates the slice for connect_timeout and needs a watchdog that does not fit the slice's budget; the docs were corrected to per-read semantics and the total cap became slice 18c, run next.
