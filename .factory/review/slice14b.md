# Review brief: slice 14b (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human (design-level problem, ambiguous spec, auth, payments, PII, possible data loss).
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.

Slice (review follow-ups of slice 14, commit 7e7ec5c, the native driver's `query_timeout`):
1. `CQL::Postgres::Connection` (src/postgres/connection.cr) overrides crystal-db's `perform_rollback_transaction` / `perform_rollback_savepoint` to skip the ROLLBACK when the session is already closed, so a QueryTimeout that dropped the session inside a transaction surfaces as itself instead of the ROLLBACK's DB::ConnectionLost (the server discards the transaction of a dropped connection).
2. `Config.positive_seconds` refuses a value whose span is not positive (`1e-10` parsed to zero).
3. The pg-shard warning (pg's driver ignores `query_timeout`) shares one helper, `CQL::Postgres::Driver.unread_query_timeout(scheme)`, and also fires when a `CQL::Schema` opens through crystal-db (`Schema#open_database`, src/schema.cr) with `query_timeout` in its URL; never with `source:`; the text names no URL.
4. `Session#with_deadline` is split so an unbounded request builds no closure (`watched` holds the old body).
Implemented by the implementer.
Tests written first: spec/postgres/query_timeout_spec.cr (FakePG BEGIN/SAVEPOINT then silent -> QueryTimeout; ping sends no cancel; 1e-10; schema-open warning, live PG) and spec/configure/configure_spec.cr (warning text).
Diff: `cd /home/user/cql && git diff --cached`. `source /home/user/cql/.factory/env.sh` before crystal (live PG at DATABASE_URL); never git stash or touch the index/working tree. Temp files in /tmp/claude-0/-home-user/448c1c81-04f8-5b52-9464-8cafcf121072/scratchpad only; run `git status --short` before replying.
