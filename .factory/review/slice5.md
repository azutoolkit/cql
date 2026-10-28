# Review brief: slice 1 (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human (design-level problem, ambiguous spec, auth, payments, PII, possible data loss).
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.


Slice: `default: "CURRENT_TIMESTAMP"` (any case) on ANY `Time` column is emitted as the dialect's current-time expression (SQLite `DEFAULT (datetime('now'))`, PG/CockroachDB `DEFAULT CURRENT_TIMESTAMP`, MySQL `DEFAULT NOW(3)`), not a quoted string; a String column keeps it quoted. Before, only columns NAMED created_at/updated_at with the dialect's own spelling got the expression: SQLite stored the text, PG rejected CREATE TABLE (22007), MySQL rejected the default. Backward compatibility: created_at/updated_at of any type still get the dialect-spelling expression (orchestrator kept the name rule so `text :created_at, default: "datetime('now')"` on SQLite keeps working).
Criteria: (1) generated SQL per dialect for `timestamp :published_at, default: "CURRENT_TIMESTAMP"`; (2) live SQLite row gets a timestamp; (3) live PG create! succeeds, row gets a timestamp; (4) String column stays quoted.
Tests written first: spec/core/column_types_spec.cr (`describe "a CURRENT_TIMESTAMP default"`).
Diff: `cd /home/user/cql && git diff --cached` (4 files, +66/-8). `source /home/user/cql/.factory/env.sh` before running crystal.

## Re-review round (after code-reviewer request_changes; security approved with minors)
Applied: (1) SQLite `add_column` with a current-time default raises `CQL::SQLiteUnsupportedFeatureError` (new optional `current_time_default` arg on `Dialect#add_column`, default false; generator passes it); PG/MySQL add_column SQL pinned; (2) `time_column?` excludes `CQL::DateColumn`; (3) MySQL guard `/\ANOW\([0-6]?\)\z/`; (4) CHANGELOG + migration-dsl.md state the kept created_at/updated_at rule, "not date", and the SQLite add_column error; (5) specs: lowercase, other-string-stays-quoted, MySQL-schema DATETIME(3) DEFAULT NOW(3), date stays quoted. Fail-without-fix verified by mutation. Diff `git diff --cached` (+117/-13).
