# Review brief: slice 1 (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human (design-level problem, ambiguous spec, auth, payments, PII, possible data loss).
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.


Slice (tenant isolation): native-PostgreSQL URL key `pool_reset` = `discard_all` ("DISCARD ALL") / `reset_all` ("RESET ALL") sets the engine pool's reset statement (Pool::Options.from, RESET_STATEMENTS), so session state one borrower sets (set_config, SET ROLE, search_path) is cleared before the next borrower; unknown values raise ArgumentError. AsyncEngine.connect keeps the URL's reset unless `reset:` is passed. The crystal-db native driver refuses the key in connection_builder (its pool cannot run a reset) pointing to EngineSource. Default unchanged (opt-in). `pool_reset` re-added to SchemaDump::FALLBACK_URI_PARAMS.
Tests written first: spec/postgres/pool_reset_spec.cr (unit + live), spec/postgres/driver_spec.cr (refusal).
Diff: `cd /home/user/cql && git diff --cached`. `source /home/user/cql/.factory/env.sh` before crystal; never git stash or touch the index/working tree.

## Re-review round (after code-review major + security blockers)
Orchestrator decision: `pool_reset` accepts only `discard_all` (reset_all removed: RESET ALL leaves SET ROLE, session authorization, temp tables, LISTEN, advisory locks and PREPAREd statements, and leaked server-side prepared statements because the client cache is forgotten after every reset). AsyncEngine.connect uses `reset.presence || from_url.reset_sql`. Live spec now checks tenant, role, search_path and a temp table on the same backend pid (fails without the reset, verified); offline precedence spec; driver refusal spec no longer starts FakePG; pool_reset removed from SchemaDump fallback allowlist again; docs/CHANGELOG state what DISCARD ALL clears, its cost, CockroachDB untested. Diff `git diff --cached` (+102).
