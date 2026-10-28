# Review brief: slice 25 (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human.
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.

Slice (M4): `CQL::OptimisticLockError` carries the model, id and expected version (plan criteria: fields populated by update! and delete!; message names model and versions, never the id, because keys can be natural/PII).
- src/exceptions.cr: `id` widened from `DB::Any?` to `(DB::Any | UUID)?` (a UUID key did not fit); message drops `##{id}`, shows `(Model)` when model_class is set, and `Expected version: N[, actual: M]` whenever expected_version is set (before: only when both versions were).
- src/active_record/optimistic_locking.cr: `update_with_lock!` rescues the builder's OptimisticLockError and raises one with model_class (`name`), id (`record.id.as?(DB::Any | UUID)`, nil for a key type outside that union), expected_version; `delete_row!` adds the id.
- src/update.cr: `Update#commit` sets expected_version from `with_optimistic_lock(version:)`.
- Specs in spec/patterns/active_record/optimistic_locking_spec.cr ("the error" context) and error_handling_spec.cr; docs error-codes.md and how-to/models/optimistic-locking.md; CHANGELOG Added.
Check in particular: anything else that still puts an id or key value into an OptimisticLockError (or other lock-related) message or log; whether the rescue in update_with_lock! can swallow or relabel an error that is not a version mismatch; whether the widened `id` type breaks compilation of callers (exhaustive `case`), and whether that needs an Upgrade note; the message wording when only actual_version is set; that Model(UUID)/Model(String)/custom-key models with optimistic_locking still compile and fill `id`.
Diff: `cd /home/user/cql && git diff --cached`. `source /home/user/cql/.factory/env.sh` before crystal (live PG at DATABASE_URL); never git stash or touch the index/working tree; experiments in a scratchpad git worktree only. Run `git status --short` before replying.
