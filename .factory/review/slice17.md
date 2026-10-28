# Review brief: slice 17 (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human (design-level problem, ambiguous spec, auth, payments, PII, possible data loss).
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.

Slice (operability): the native engine pool's checkout timeout (`CQL::Postgres::PoolTimeout`, src/postgres/pool.cr `wait_for_slot`; copied into `DB::PoolTimeout` by EngineSource) now names the server: "no connection to #{@config.address} became free within ...". Connect errors already named `host:port` / the socket path (transport.cr "cannot connect to #{config.address}"); the new spec pins all of them and that no password appears. Implemented by the orchestrator (one line).
Tests written first: spec/postgres/server_address_spec.cr (new: pool timeout fails before the fix; AsyncEngine/EngineSource/DB.open refused connects and a UNIX-socket path are guards).
Diff: `cd /home/user/cql && git diff --cached`. `source /home/user/cql/.factory/env.sh` before crystal; never git stash or touch the index/working tree; experiments in a scratchpad git worktree only. Run `git status --short` before replying.
