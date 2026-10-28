# Review brief: slice 1 (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human (design-level problem, ambiguous spec, auth, payments, PII, possible data loss).
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.


Slice: `CQL::SchemaDump` handles database-supplied names safely. (a) Generated Crystal writes every table/column/foreign-key name through a `symbol(name)` helper: bare when `Symbol.needs_quotes?` is false, else `:#{name.inspect}` (escaped). (b) SQLite inspection uses bound `pragma_table_info(?)` / `pragma_foreign_key_list(?)` instead of interpolated PRAGMA statements; MySQL `DESCRIBE` quotes the table name with the dialect (not testable here). Before: a crafted name broke/injected into the schema file and an unquoted PRAGMA silently lost the table's columns.
Tests written first: spec/core/schema_dump_spec.cr `describe "names read from the database"`.
Diff: `cd /home/user/cql && git diff --cached`. `source /home/user/cql/.factory/env.sh` before crystal; never git stash or touch the index/working tree.
