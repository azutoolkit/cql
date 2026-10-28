# Review brief: slice 22 (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human (design-level problem, ambiguous spec, auth, payments, PII, possible data loss).
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.

Slice (M4 transactions): `CQL::Schema#transaction(read_only: true)`. Slices 20 (5f405a8) and 21 (8c9ef5e) added `isolation:` with dialect hooks `isolation_level_sql(level)` and `isolation_before_begin?` (MySQL runs the statement just before BEGIN on the same connection, others as the transaction's first statement). Both hooks are unreleased, so this slice renames them to `transaction_modes_sql(isolation, read_only)` / `transaction_modes_before_begin?` and adds READ ONLY: PostgreSQL/CockroachDB/MySQL get `SET TRANSACTION [ISOLATION LEVEL x][, ]READ ONLY`; SQLite raises `CQL::DialectError` for read_only (user decision Q4), before anything begins. Nested `read_only:` raises ArgumentError like `isolation:`.
Tests written first: spec/core/transaction_options_spec.cr, spec/integration/dialects/mysql_dialect_spec.cr, spec/postgres/live_spec.cr (a write inside a read-only transaction fails with SQLSTATE 25006 on a live server).
Diff: `cd /home/user/cql && git diff --cached`. `source /home/user/cql/.factory/env.sh` before crystal (live PG at DATABASE_URL); never git stash or touch the index/working tree; experiments in a scratchpad git worktree only. Run `git status --short` before replying.
