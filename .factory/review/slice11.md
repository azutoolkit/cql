# Review brief: slice 1 (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human (design-level problem, ambiguous spec, auth, payments, PII, possible data loss).
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.


Slice (PII): CQL::Postgres::Statement (native driver) overrides crystal-db's `emit_log`: the `db` Debug "Executing query" entry carries `query` and `args_count` only; the bound values (crystal-db's `args`) appear only when `CQL::Telemetry.capture_params` is on. Before, binding the `db` source at Debug logged every bound value. (Implemented by the orchestrator: a 4-line override.)
Tests written first: spec/postgres/statement_log_spec.cr (live PG; pending without DATABASE_URL).
Diff: `cd /home/user/cql && git diff --cached`. `source /home/user/cql/.factory/env.sh` before crystal; never git stash or touch the index/working tree.
