# Review brief: slice 23 (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human.
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.

Slice (M4): `Model.transaction` (src/active_record/transactional.cr, a macro-included class method) forwards `isolation:` and `read_only:` to `CQL::Schema#transaction` (slices 20-22b: `git show 5f405a8 8c9ef5e aee8dbf 27a780d`). Existing `Model.transaction { |tx| }` and `Model.transaction(existing_tx) { }` keep working. Symbol literals (`isolation: :serializable`) autocast to `CQL::IsolationLevel` here (models have no `method_missing`, unlike Schema). Built by the orchestrator test-first (small slice).
Diff: `cd /home/user/cql && git diff --cached`. `source /home/user/cql/.factory/env.sh` before crystal; never git stash or touch the index/working tree. Run `git status --short` before replying.
