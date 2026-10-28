# Review brief: slice 1 (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human (design-level problem, ambiguous spec, auth, payments, PII, possible data loss).
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.


Slice (merged 6+7): MySQL column redefinitions (`CHANGE` for rename_column, `MODIFY COLUMN` for change_column) restate DEFAULT and NOT NULL, never UNIQUE (restating UNIQUE in MySQL adds a duplicate unique index); `change_column` keeps null/default/unique/index/version_number in the schema declaration on every dialect. Before: MySQL rename/change made the column nullable with no default; change_column dropped null/default from the declaration everywhere.
Design: dialect hook `redefines_whole_column?` (false default, MySQL true); generator `redefined_column_type` passes type + DEFAULT/NOT NULL (from `column_definition(column, unique: false)` minus the leading name) to MySQL only; PG `ALTER COLUMN TYPE` gets the type alone; abstract dialect signatures unchanged.
Criteria: MySQL CHANGE/MODIFY SQL pinned (DEFAULT + NOT NULL, no UNIQUE); declaration keeps null/default after change_column; existing size-kept rename now expects `VARCHAR(12) NOT NULL` (old expectation encoded the bug).
Tests written first: spec/core/alter_table_spec.cr.
Diff: `cd /home/user/cql && git diff --cached` (+73/-12). `source /home/user/cql/.factory/env.sh` before crystal. Do not use git stash or touch the index/working tree.

## Re-review round (after code-reviewer major + security request_changes)
Applied: undeclared column redeclared `null: true` (keeps old `MODIFY COLUMN missing INT`); primary key: `redeclared` returns `PrimaryKey(T)` keeping auto_increment/default, MySQL redefinition appends ` AUTO_INCREMENT` (never PRIMARY KEY/UNIQUE); the Bool hook was replaced by one dialect hook `column_redefinition(type, definition, auto_increment)` (base returns type; MySQL returns definition + AUTO_INCREMENT); ChangeColumn name validated with Identifier.validate!; lchop guarded (raises CQL::Error if the definition does not start with the name); comment/docs: size resets, alias dropped; docs warning hint on unmodelled attributes (COMMENT, charset, ON UPDATE, generated), NULL backfill, default valid for new type; CHANGELOG Fixed extended + Upgrade note. 5 new specs, each verified failing without its fix. Diff `git diff --cached` (+122).
