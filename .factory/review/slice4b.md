# Review brief: slice 1 (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human (design-level problem, ambiguous spec, auth, payments, PII, possible data loss).
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.


Slice: `Migrator#pending_migrations` and the applied list (used by up/down/rollback/down_to) read the applied versions with ONE query (`repo.query.select(:version).all(Int64).to_set`) instead of `ensure_schema_migrations_table` + `repo.exists?` per registered migration (~4N statements); listing runs no DDL (the table is ensured in `Migrator.new` under the migration lock). `record_migration` keeps its single-version check.
Consequence: on MySQL/CockroachDB, listing inside an open schema.transaction no longer raises DialectError (it only reads). The old spec "refuses to list pending migrations inside a caller's transaction without transactional DDL" encoded the old side effect (listing created the table); the orchestrator flipped it to assert listing works there and runs no CREATE. Docs (run-migrations.md, error-codes.md, telemetry.md) updated.
Tests written first: spec/core/migrator_queries_spec.cr (statement count constant for 1 vs 20 registered, no CREATE).
Diff: `cd /home/user/cql && git diff --cached`. `source /home/user/cql/.factory/env.sh` before crystal; never git stash or touch the index/working tree.
