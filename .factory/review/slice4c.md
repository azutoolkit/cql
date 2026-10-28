# Review brief: slice 1 (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human (design-level problem, ambiguous spec, auth, payments, PII, possible data loss).
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.


Slice: `CQL::SchemaDump` writes `unique: true` for a column covered by a single-column UNIQUE constraint or unique index on SQLite and PostgreSQL (not the primary key, not multi-column, partial or expression indexes, not plain indexes). MySQL unchanged (no server to test; documented). Before: dumps dropped every UNIQUE, so a schema rebuilt from the dump (azu_cli db:schema:load, the migrations table's UNIQUE(version)) lost it.
Tests written first: spec/core/schema_dump_spec.cr `describe "unique constraints"` (SQLite, migrations-table round trip, live PG).
Diff: `cd /home/user/cql && git diff --cached`. `source /home/user/cql/.factory/env.sh` before crystal; never git stash or touch the index/working tree. Note: src/schema_dump.cr is now ~516 lines (pre-existing file over the 400-line standard).
