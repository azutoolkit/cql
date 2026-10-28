# Review brief: slice 8d (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human (design-level problem, ambiguous spec, auth, payments, PII, possible data loss).
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.

Slice (PII, follow-up of 8b): `CQL::ActiveRecord::Scopes.evaluate` (src/active_record/scopes.cr) turned any non-ArgumentError raised in a scope body into `ArgumentError.new("Error in scope '#{name}': #{ex.message}")`, copying a message that can quote row values and dropping the error. Now it raises the new `CQL::ActiveRecord::Scopes::Error < ArgumentError` with "Error in scope '<name>' (<error class>)" and the error as `cause` (Crystal's ArgumentError#initialize takes no cause, hence the subclass setting @cause after super). ArgumentError raised in the body still passes through unchanged. Implemented by the orchestrator.
Tests written first: spec/patterns/active_record/scopes_spec.cr, "raises ArgumentError naming the scope and the error class, keeping the error as its cause" (failed before: message contained the marker), with a `leaky` scope on the spec-private ScopesArchivedPost.
Diff: `cd /home/user/cql && git diff --cached`. `source /home/user/cql/.factory/env.sh` before crystal; never git stash or touch the index/working tree. Temp files go in /tmp/claude-0/-home-user/448c1c81-04f8-5b52-9464-8cafcf121072/scratchpad (only delete files you created).
