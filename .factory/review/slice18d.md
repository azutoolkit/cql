# Review brief: slice 18d (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors.
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.

Slice (spec-only, review minors of 18b): unit specs pinning `CQL::CheckoutBudget` (src/checkout_budget.cr) scoping and sharing rules in a new spec/core/checkout_budget_spec.cr (nested/raise restore, no inheritance in spawned fibers, claims share the first deadline in a scope, zero timeout, health checks share one half, MIN_CHECK_WAIT, cap), and the `checkout_timeout=inf` check moved into its own example in spec/postgres/driver_spec.cr (inf, nan, -1, > 1 year). Each example was mutation-checked in a worktree (14 mutations, all caught). Check: timing tolerances stable under load (shared 4-core box), no leaked fiber state between examples, names say what they pin, no duplication with spec/postgres/checkout_budget_spec.cr.
Diff: `cd /home/user/cql && git diff --cached`. `source /home/user/cql/.factory/env.sh` before crystal; never git stash or touch the index/working tree. Run `git status --short` before replying.
