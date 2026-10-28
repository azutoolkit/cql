# Review brief: slice 24g (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human.
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.

Slice (M4, mirror of 24d2 = 5d21b62, through the rollback hooks hardened in 80f1d05/fd081dc/26947c3): a record deleted with `delete!` (or soft-delete's `force_delete!`) inside a transaction that rolls back gets its id back (and, with DirtyTracking, its saved snapshot, via `persistence_snapshot`) and `destroyed?` false, so a later `save!` updates its row instead of inserting a second one (before: the id was cleared, so save! inserted a duplicate of the restored row). A soft-delete (`delete!` on a SoftDeletable model) that rolls back restores `deleted_at` and `destroyed?`. Built test-first by the orchestrator (small slice).
Diff: `cd /home/user/cql && git diff --cached`. `source /home/user/cql/.factory/env.sh` before crystal (live PG at DATABASE_URL); never git stash or touch the index/working tree; experiments in a scratchpad git worktree only. Run `git status --short` before replying.
