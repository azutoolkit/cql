# Review brief: slice 1 (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human (design-level problem, ambiguous spec, auth, payments, PII, possible data loss).
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.


Slice: tighten the schema file's `uri:` line. (1) The fallback keeps only query params on an allowlist of known non-secret keys (`FALLBACK_URI_PARAMS`, case-insensitive, order kept) and drops the fragment (before: only a lowercase `password` param was stripped, so `sslpassword`, `Password`, `api_key`, `app.token`, `options` and a fragment reached the committed file). (2) The env var name is configurable: `dump_to_file(..., env_var:)`, `generate_schema_content(..., env_var:)`, `MigratorConfig#schema_url_env` (default "DATABASE_URL"), passed to auto_sync and verify_schema_consistency; emitted via inspect. The previous escaping spec appended `#{x}` as a URL fragment, which is now dropped; the orchestrator moved the `#{`/`"` escaping check onto the env var name (a raw `#` cannot appear in a URI path or query value).
Tests written first: spec/core/schema_dump_spec.cr (`describe "the uri: line"`), spec/core/migrator_schema_file_spec.cr.
Diff: `cd /home/user/cql && git diff --cached`. `source /home/user/cql/.factory/env.sh` before crystal; never git stash or touch the index/working tree.
