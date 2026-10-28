# Review brief: slice 24e (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human (design-level problem, ambiguous spec, auth, payments, PII, possible data loss).
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.

Slice (M4, from the security reviews of 24 and 24c; the bug predates them): on PostgreSQL a statement that fails inside a transaction aborts it (status 'E'); a block that rescues the error and returns made crystal-db send COMMIT, which the server answers with the ROLLBACK tag and no error, so `transaction`/`retrying_transaction` reported success with nothing committed. The native driver's `CQL::Postgres::Connection#perform_commit_transaction` now raises the new `CQL::Postgres::TransactionAborted` when the session was 'E' before COMMIT, after the COMMIT (so the connection is released by the rescue added in 24c, 05bcd81). Upgrade note: such blocks now raise. The pg shard is unchanged.
Tests written first: spec/postgres/live_spec.cr.
Diff: `cd /home/user/cql && git diff --cached`. `source /home/user/cql/.factory/env.sh` before crystal (live PG at DATABASE_URL); never git stash or touch the index/working tree; experiments in a scratchpad git worktree only. Run `git status --short` before replying.
