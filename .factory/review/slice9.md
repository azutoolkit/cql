# Review brief: slice 1 (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human (design-level problem, ambiguous spec, auth, payments, PII, possible data loss).
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.


Slice (merged 9+10, user-approved design): the schema file `SchemaDump#generate_schema_content` writes (the migrator's auto_sync too) emits `uri: ENV.fetch("DATABASE_URL", <fallback>.inspect)` instead of `uri: "#{@uri}"`; the fallback is the URI without the userinfo password and without a `password` query param; if URI.parse raises, `ENV["DATABASE_URL"]` with no fallback. Before: the password went into a committed file, and a `"`/`#{` in the URI broke or injected into the generated Crystal.
Tests written first: spec/core/schema_dump_spec.cr `describe "the uri: line"` (live PG with password + password query param; SQLite with `"` and `#{x}` in the path/fragment; SQLite credential-free).
Diff: `cd /home/user/cql && git diff --cached`. `source /home/user/cql/.factory/env.sh` before crystal; never git stash or touch the index/working tree.
