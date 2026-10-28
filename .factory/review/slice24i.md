# Review brief: slice 24i (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human.
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.

Slice (M4, from the security review of 24h = 0bfa438; predates it): `Schema#on_rollback` appended a hook to the innermost OPEN frame (`active_frame` skips closed frames). After a savepoint released by hand (`sp.commit`) whose block goes on, new hooks went to the enclosing frame at once while the savepoint's own older hooks reached it only when its block ended, so they ran in the wrong order (newest first broke): a DirtyTracking record changed before and after the release ended with the older snapshot after a rollback. Now `on_rollback` first hands the hooks of closed frames above the open one (same connection only) down to it, in stack order, then appends. Built test-first by the orchestrator (small slice).
Diff: `cd /home/user/cql && git diff --cached`. `source /home/user/cql/.factory/env.sh` before crystal (live PG at DATABASE_URL); never git stash or touch the index/working tree; experiments in a scratchpad git worktree only. Run `git status --short` before replying.
