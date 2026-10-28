# Review brief: slice 1 (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human (design-level problem, ambiguous spec, auth, payments, PII, possible data loss).
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.


Slice: when the version of a migration being applied is recorded by another migrator during the run, `Migrator#up` raises and the batch rolls back (SQLite/PostgreSQL), instead of silently skipping the record and committing; that skip let two concurrent migrators both apply a data migration.
Root cause: `record_migration` guarded the insert with `unless migration_applied?`. Now: if the version is visible -> raise Migrator::Error (names class and version); otherwise insert unguarded so an uncommitted concurrent insert on PostgreSQL trips the unique index (driver error). The explicit check (rather than relying only on the unique violation) was chosen because on SQLite a failed insert leaves a stale error that sqlite3_finalize re-raises at Schema#close (separate slice 3b).
Criteria: (1) SQLite: a migration whose `up` creates a table then inserts its own version row (simulated other migrator) makes `up` raise Migrator::Error; (2) the table and every version row are rolled back.
Tests written first: spec/core/migration_transaction_spec.cr (TxMigrationRecordedConcurrently, example "rolls back the batch when another migrator records a migration's version during the run").
Diff: `cd /home/user/cql && git diff --cached` (5 files, +35/-5). Slice 4 (next) adds a PostgreSQL advisory lock; out of scope here.
