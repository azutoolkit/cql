# Review brief: slice 21 (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human (design-level problem, ambiguous spec, auth, payments, PII, possible data loss).
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.

Slice (M4 transactions): `Schema#transaction(isolation:)` on MySQL. Slice 20 (5f405a8) added the option with a dialect hook `isolation_level_sql(level)` whose statement runs as the transaction's first statement; MySQL raised DialectError. MySQL's `SET TRANSACTION ISOLATION LEVEL X` (no GLOBAL/SESSION) applies to the NEXT transaction only and is refused inside one (error 1568), so it must run on the checked-out connection before BEGIN. Now MySqlDialect returns that statement and a dialect predicate `isolation_before_begin?` (false by default, true for MySQL) makes the Schema run it before BEGIN on the same connection. MySQL cannot run live here: generated SQL is pinned, and the ordering is pinned live on SQLite with a spec-local dialect.
Tests written first: spec/integration/dialects/mysql_dialect_spec.cr, spec/core/transaction_options_spec.cr.
Diff: `cd /home/user/cql && git diff --cached`. `source /home/user/cql/.factory/env.sh` before crystal (live PG at DATABASE_URL); never git stash or touch the index/working tree; experiments in a scratchpad git worktree only. Run `git status --short` before replying.
