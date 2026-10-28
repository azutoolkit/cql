# Review brief: slice 24 (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human (design-level problem, ambiguous spec, auth, payments, PII, possible data loss).
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.

Slice (M4): `CQL::Schema#retrying_transaction(attempts = 3, isolation:, read_only:) { }` runs the block in a transaction and, when the transaction fails with a serialization failure or a deadlock, rolls it back and runs the whole block again, up to *attempts* times. User decision Q5: only the native PostgreSQL driver's errors are retried (`CQL::Postgres::SerializationFailure` 40001, `CQL::Postgres::DeadlockDetected` 40P01, on PostgreSQL and CockroachDB) through a dialect hook; MySQL 1213, SQLite BUSY and the pg shard's `PQ::PQError` are not. Inside a transaction it raises ArgumentError (a savepoint cannot be retried alone). The block must be safe to run again: side effects outside the database run once per attempt.
Tests written first: spec/core/transaction_retry_spec.cr, spec/postgres/live_spec.cr (a real 40001 between two connections).
Diff: `cd /home/user/cql && git diff --cached`. `source /home/user/cql/.factory/env.sh` before crystal (live PG at DATABASE_URL); never git stash or touch the index/working tree; experiments in a scratchpad git worktree only. Run `git status --short` before replying.
