# Review brief: slice 1 (staged, not yet committed)
Review this slice from a clean context. Return ONLY JSON:
{"verdict":"approve|request_changes|escalate","summary":"","findings":[{"file":"","line":0,"severity":"blocker|major|minor","note":"what is wrong and the fix"}]}
Approve when there are no blockers and no majors. Escalate only when the fix needs a human (design-level problem, ambiguous spec, auth, payments, PII, possible data loss).
Standards: /home/user/cql/.factory/standards.md. Repo rules: /home/user/cql/CLAUDE.md.


Slice: two registered migration classes with the same version make `CQL::Migrator.new(schema, config)` raise `CQL::Migrator::Error` naming every such class and the version, before anything is created, applied or recorded. (Before: `up` applied both and recorded one; a later rollback corrupted state.)
Criteria: (1) Migrator.new raises Migrator::Error with both class names and the version; (2) neither table created, no record row; (3) distinct versions unchanged.
Tests written first: spec/core/migration_duplicate_version_spec.cr (new). It removes its duplicate classes from the global registry at load and swaps them in per example.
Diff: `cd /home/user/cql && git diff --cached` (4 files, +60). Code: src/migrations.cr (Migrator#initialize, reject_duplicate_versions!).
Downstream: azu_cli-generated apps call CQL::Migrator.new in their db tasks.

## Re-review round (after security request_changes)
Changes made for the security findings: CHANGELOG upgrade note and create-migration.md now say to renumber the one the migrations table does NOT list (renumbering the recorded one runs it again) and, if both ran, insert a row for the new version before `up`; the error message says the same; `reject_duplicate_versions!` now also runs in `sorted_migrations`, so every up/down/up_to/down_to/pending listing re-checks the mutable registry; new spec "raises when a duplicate joins the registry after the migrator was built" (fails without the recheck, verified). Code-reviewer minors applied: error-codes.md row, spec asserts cql_schema_migrations was not created.
