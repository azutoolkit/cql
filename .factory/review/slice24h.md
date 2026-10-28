# Review brief: slice 24h (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human.
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.

Slice (M4, last record-state slice after 24d2 = 5d21b62 and 24g = 98cb44c, through the rollback hooks hardened in 80f1d05/fd081dc/26947c3): a DirtyTracking record updated inside a transaction that rolls back counts its changes as unsaved again (its pre-update snapshot comes back through `persistence_snapshot`), so a later `save!` sends the UPDATE instead of skipping it (before: the change was silently never written); a record with optimistic locking whose update rolled back gets its in-memory version back, so its next update is not refused with OptimisticLockError against the unchanged row. Built test-first by the orchestrator (small slice).
Diff: `cd /home/user/cql && git diff --cached`. `source /home/user/cql/.factory/env.sh` before crystal (live PG at DATABASE_URL); never git stash or touch the index/working tree; experiments in a scratchpad git worktree only. Run `git status --short` before replying.
