# Review brief: slice 1 (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human (design-level problem, ambiguous spec, auth, payments, PII, possible data loss).
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.


Slice: the PostgreSQL migration advisory lock wait is bounded. `CQL::MigratorConfig#lock_timeout : Time::Span?` (default 60 s; nil leaves the wait to the server's own lock_timeout). `within_lock_timeout` (src/migrations.cr) reads the connection's lock_timeout, sets it (transaction-local, set_config(..., true)) to the bound in whole ms, takes the lock, then restores the previous value so migrations run under their usual lock_timeout. A timeout (SQLSTATE 55P03, from CQL's native driver or the pg shard) raises `CQL::Migrator::Error` naming the migrations table and `MigratorConfig#lock_timeout`; nothing is applied. Dialect hooks: `lock_timeout_sql`, `set_lock_timeout_sql`, `lock_timed_out?` (nil/false default; PostgreSQL implements; CockroachDB never reaches them since its lock SQL is nil). Also docs/CHANGELOG wording fixes from the slice 4 security confirmation (waiting up re-picks; lock before table creation; listing takes no lock; SQLite "database is locked"; down raises when picks differ; DialectError only when there is work).
Tests written first: spec/postgres/migrator_lock_live_spec.cr ("gives up after lock_timeout ..."), spec/core/migration_spec.cr (MigratorConfig defaults).
Diff: `cd /home/user/cql && git diff --cached` (+135/-15). `source /home/user/cql/.factory/env.sh` before crystal (live PG16 at DATABASE_URL); never git stash or touch the index/working tree; use your own migrations table name for live probes (not cql_lock_spec_migrations).

## Re-review round (after both reviewers' major: no spec for the restore)
Applied: live example "keeps the connection's own lock_timeout ..." (pool of one, SET lock_timeout='7s', up with lock_timeout 0.5 s: the migration and the connection afterwards see '7s'; fails with "500ms" when the restore line is deleted, verified); dialect hook unit specs (PG $1/true, nil on SQLite/MySQL, 55P03 true, 57014/plain Exception false); docs: <1 ms raised to 1 ms, bound replaces even a shorter server lock_timeout, CQL.configure has no setting (pass a MigratorConfig). Committed split for size: hooks + their unit specs as 1 commit (HEAD), the migrator change staged now.
Diff to re-review: `git show HEAD` plus `git diff --cached`.
