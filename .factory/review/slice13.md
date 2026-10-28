# Review brief: slice 13 (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human (design-level problem, ambiguous spec, auth, payments, PII, possible data loss).
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.

Slice (security: LIKE wildcard injection): new `contains(text)`, `starts_with(text)`, `ends_with(text)` on column expressions (src/expression/base_expression.cr) and on the typed DSL's `CQL::DSL::TextCol` (src/active_record/dsl/column.cr). A new AST node `Expression::EscapedLike` (src/expression/comparison_operators.cr) escapes `!`, `%`, `_` with `!`, wraps the text for its position, and is bound; the generator emits `<col> LIKE ? ESCAPE '!'` via the dialect hook `format_like_escape` (default in src/dialects/dialect.cr). `!` rather than backslash: MySQL NO_BACKSLASH_ESCAPES, SQLite has no default escape. Existing `like` unchanged. The tutorial (docs/tutorials/building-a-blog/04-crud-operations.md) used `like("%#{term}%")` with user input and now uses `contains`.
Tests written first: spec/expression/predicates_spec.cr (generated SQL for SQLite/PG/MySQL + live SQLite literal matching), spec/patterns/active_record/typed_dsl_spec.cr.
Diff: `cd /home/user/cql && git diff --cached`. `source /home/user/cql/.factory/env.sh` before crystal; never git stash or touch the index/working tree. Put any temp files in /tmp/claude-0/-home-user/448c1c81-04f8-5b52-9464-8cafcf121072/scratchpad and delete them.
