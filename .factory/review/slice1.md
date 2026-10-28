# Review brief: slice 1 (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human (design-level problem, ambiguous spec, auth, payments, PII, possible data loss).
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.

Slice: `delete!` on a stale record of a model using `optimistic_locking` raises `CQL::OptimisticLockError` instead of deleting a row someone else changed (or returning false when the row is gone). Fresh records still delete and return true. A raise rolls back `dependent:` deletes. SoftDeletable unchanged.
Criteria: (1) stale copy delete! raises and the row survives with the other copy's values; (2) fresh delete! deletes, returns true; (3) row already deleted -> raises; (4) dependent rows survive a raising stale delete; (5) SoftDeletable unchanged.
Design (agreed): Template Method: Deleteable#delete! calls overridable delete_row!; optimistic_locking overrides it.
Tests written first: spec/patterns/active_record/optimistic_locking_spec.cr (`when deleting` examples).
Diff: run `cd /home/user/cql && git diff --cached` (5 files, +102/-1). Read surrounding code as needed (src/active_record/deleteable.cr, optimistic_locking.cr, soft_deletable.cr, src/update.cr with_optimistic_lock, src/exceptions.cr).
