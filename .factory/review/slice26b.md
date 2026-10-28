# Review brief: slice 26b (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human.
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.

Slice (M4, last): association destroy paths run in one transaction (plan criteria: ManyCollection#delete with dependent: :destroy, clear_with_destroy and Collection#clear(:destroy) roll back their join/target deletes when a target's delete! raises, e.g. a stale locked target).
- src/active_record/relations/many_collection.cr: `delete(id)` runs the old body (now private `unlink`) inside `Through.schema.transaction` when dependent is :destroy or :delete_all (other strategies keep no transaction: one join DELETE plus a find); `clear_with_destroy` deletes the join rows and destroys the targets inside `Through.schema.transaction`.
- src/active_record/relations/collection.cr: `clear` with :destroy runs the delete! loop inside `Target.schema.transaction`.
- Not changed: `clear_with_delete` (:delete_all clear: join DELETE + chunked target deletes) stays outside a transaction.
- Specs: new spec/patterns/active_record/relations/destroy_transaction_spec.cr (spec-local SQLite schema; three stale-target cases plus a :delete_all delete refused by a trigger). All four fail without the change (verified). Docs: has-many.md, many-to-many.md; CHANGELOG Fixed.
Check in particular: the join table and the target living in different schemas (Through.schema vs Target.schema: which statements the transaction covers, and whether that is worse than before); behaviour when already inside a transaction (savepoint) and when a target's before_destroy halts (delete! returns false: rows kept or deleted, consistent with before?); the in-memory state after a rollback (@records, @loaded, the targets' destroyed/id, restored by the rollback hooks of 24g); `return`/`break` paths inside the new blocks; whether leaving clear_with_delete out is acceptable or inconsistent; the records_affected count in Collection#clear when it raises.
Diff: `cd /home/user/cql && git diff --cached`. `source /home/user/cql/.factory/env.sh` before crystal (live PG at DATABASE_URL); never git stash or touch the index/working tree; experiments in a scratchpad git worktree only. Run `git status --short` before replying.
