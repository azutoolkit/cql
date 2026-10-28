# Review brief: slice 1 (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human (design-level problem, ambiguous spec, auth, payments, PII, possible data loss).
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.


Slice: concurrent PostgreSQL migrators serialise on a transaction-scoped advisory lock and apply each migration exactly once; the pending/applied list is computed under the lock. Also rewords the previous commit (c656c4d) whose comment/CHANGELOG/doc claimed the unique index on version catches an uncommitted concurrent record (not guaranteed: a migrations table built from a dumped schema lacks UNIQUE(version)); MySQL/CockroachDB still apply twice when run concurrently -> docs say run from one process.
Design (agreed): Dialect hook `migration_lock_sql : String?` (nil default; PG `SELECT pg_advisory_xact_lock($1)`; CockroachDB overrides back to nil). Key = CRC32 of the migrations table name, bound. `migrate_up`/`migrate_down` take the list as a block evaluated after `lock_migrations` inside `ddl_transaction`.
Criteria: (1) dialect hook pinned for PG (contains pg_advisory_xact_lock) and nil for CockroachDB/MySQL/SQLite; (2) live PG: two schemas run `up` concurrently on a sleeping data migration -> no error, counter n == 1, 2 version rows.
Tests written first: spec/postgres/migrator_lock_live_spec.cr (new; pending without DATABASE_URL), spec/integration/dialects/cockroach_dialect_spec.cr (new example).
Diff: `cd /home/user/cql && git diff --cached` (8 files, +118/-14).
Open point for reviewers: `Migrator.new` runs `ensure_schema_migrations_table` in its own ddl_transaction WITHOUT the lock; two processes constructing a migrator for the first time at once may race on CREATE TABLE IF NOT EXISTS on PostgreSQL (pg_type unique violation). Judge whether this slice should also lock there.

## Re-review round (after request_changes from all three reviewers)
Applied: (1) Migrator#initialize takes the lock before creating the migrations table; (2) live spec builds each Migrator inside its fiber (fails without (1): pg_class/pg_type unique violation, verified); (3) double-checked locking: `with_migration_lock(pick)` picks once unlocked and returns when empty (no-op boots take no lock), else locks and re-picks; (4) fail closed under REPEATABLE READ via new dialect hook `transaction_isolation_sql` (PG `SHOW transaction_isolation`), raising Migrator::Error; new live example (caller transaction at REPEATABLE READ -> raises, applies nothing; fails without the check, verified); (5) lock key = ("CQLM" salt << 32) | CRC32(downcased, schema-stripped table name); (6) CHANGELOG/docs wording: down/rollback concurrency, redo locks each half, MySQL/CockroachDB mechanism, unbounded wait, READ COMMITTED requirement; upgrade note for the REPEATABLE READ refusal. Lock timeout is a planned follow-up slice (4d).
The slice is 171 added lines; at commit time it will be split into two green commits (lock, then REPEATABLE READ guard).
Diff: `git diff --cached` (staged).

## Confirmation round (after second request_changes)
Applied: (1) dialect predicate `migration_lock_isolation_safe?(level)` (PG: only read committed/uncommitted) + `transaction_isolation_sql`; Migrator `require_read_committed!` asks the dialect, so SERIALIZABLE is refused too; (2) wording READ COMMITTED only; (3) `migrate_down` picks unlocked, re-picks under the lock, and raises Migrator::Error rolling back nothing when the picks differ (`require_unchanged!`); `up` still re-picks; (4) constructor lock kept, docs/CHANGELOG say building a migrator waits while another process runs migrations (no table-exists check in src); (5) live examples: REPEATABLE READ and SERIALIZABLE caller transactions raise and apply nothing; two concurrent rollback(1) -> exactly one Migrator::Error, only the newest rolled back. Fail-without-fix verified for both new examples.
Diff: `git diff HEAD` (unstaged + staged; +238/-17, 8 files). Will be committed as 2-3 green commits.
Note for running checks: `source /home/user/cql/.factory/env.sh` first (puts crystal on PATH, sets DATABASE_URL).
