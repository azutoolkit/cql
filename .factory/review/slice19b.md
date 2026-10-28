# Review brief: slice 19b (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors.
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.

Slice (follow-ups of 5779063, sslcert/sslkey): (1) src/postgres/config.cr warns once per process per key path (class-level Set behind a Mutex), at parse, when the sslkey file has group/other bits by libpq's rule (0o077, or 0o037 for a root-owned file), via Session::Log ("cql.postgres"), naming sslkey, the path and the mode; warns, does not refuse (k8s secret mounts); Unix only. (2) src/dialects/postgres_dialect.cr `dump_env` passes sslrootcert/sslcert/sslkey to pg_dump as PGSSLROOTCERT/PGSSLCERT/PGSSLKEY (unset when absent). (3) docs: certs only sent when TLS is negotiated, atomic rotation, the warning, the pg shard still prompts for an encrypted key; troubleshooting line; a comment on the reopened lib LibSSL. Implemented by the implementer.
Tests written first: spec/postgres/transport_spec.cr (warning once per path for 0644, none for 0600 or root-owned 0640; sslmode=disable guard), spec/integration/dialects/postgres_dialect_spec.cr (PGSSL* variables).
Diff: `cd /home/user/cql && git diff --cached`. `source /home/user/cql/.factory/env.sh` before crystal; never git stash or touch the index/working tree; experiments in a scratchpad git worktree only. Run `git status --short` before replying.
