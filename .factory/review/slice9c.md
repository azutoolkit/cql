# Review brief: slice 1 (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human (design-level problem, ambiguous spec, auth, payments, PII, possible data loss).
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.


Slice (security fix to commit 1a2b174): `CQL::SchemaDump#generate_schema_content` refuses database-supplied table, column, referenced-table and referenced-column names that are not valid identifiers (`CQL::Identifier.valid?`), raising `SchemaDump::Error` naming them before writing anything. Reason: 1a2b174 wrote such names as escaped symbols, which compile, but CQL's DDL never quotes names, so building the dumped schema ran SQL in the name (proven on PG16 and SQLite by a security review). FK on_delete/on_update are mapped to CQL's five rules (SQLite's `NO ACTION` now omitted like on PG/MySQL; anything else raises). The previous spec asserting escaped-symbol output was replaced by refusal specs (deliberate).
Tests written first: spec/core/schema_dump_spec.cr (5 examples incl. live PG).
Diff: `cd /home/user/cql && git diff --cached`. `source /home/user/cql/.factory/env.sh` before crystal; never git stash or touch the index/working tree.

## Re-review round (after code-reviewer request_changes)
Applied: (1) auto_sync path: `sync_schema_file` logs one WARN and keeps the old file when the dump fails after the migrations committed; up/down return normally; explicit update_schema_file/bootstrap_schema still raise (pulled planned slice 29 in); (2) dump accepts letters of any script, digits and `_` (NAME_PATTERN), bare `:café` verified to compile; CQL::Identifier untouched; (3) FK rules validated in check_names (inspectors normalise; SQLite gsub " " -> "_"); (4) CHANGELOG/docs wording; (5) table-driven FK refusal spec. Each new spec verified failing without its fix. Diff `git diff --cached` (+147).
