# CQL - Claude Code Guide

CQL is a type-safe query DSL and ORM for Crystal (SQLite, PostgreSQL, MySQL, CockroachDB).

## Commands

```bash
shards install --ignore-crystal-version   # install dependencies
crystal spec                              # full suite (Postgres/Redis specs go pending without servers)
crystal spec spec/core/query_spec.cr      # one file
crystal tool format --check src spec      # CI format check
crystal run lib/ameba/bin/ameba.cr -- -f progress ./src ./spec   # CI lint, as CI runs it
python3 script/docs/check_links.py && python3 script/docs/check_nav.py && python3 script/docs/gitbook_lint.py  # CI docs
python3 script/docs/compile_snippets.py docs/how-to/models/timestamps.md   # compile a page's programs (CI: all pages)
```

## Required: code review before every commit

Every commit that changes `src/`, `spec/`, `playground/` or `benchmarks/` must be reviewed by the
`code-reviewer` agent (`.claude/agents/code-reviewer.md`, Claude Sonnet 5.5, high effort) **before**
it is created:

1. Stage the change and run the fast checks (`crystal spec` for the affected area, format check).
2. Launch the `code-reviewer` agent on the staged diff (`git diff --cached`).
3. Fix every **Blocking** finding, re-stage, and re-run the reviewer until it reports nothing
   blocking. Address or consciously reject each **Should fix**, and say why in the commit message
   or PR if you reject one.
4. Commit. Docs-only and changelog-only commits are exempt.

## Conventions

- Design for readability: apply SOLID and the patterns already in use (Visitor for SQL generation,
  Builder for queries/conditions, Strategy for dialects, Template Method for dialect defaults).
  Add a feature as a new AST node + visitor method + dialect hook, not as adapter `if`/`case`
  branches. Keep classes and methods small and single-purpose, avoid duplication and verbosity,
  and let names carry the meaning instead of comments.
- Values are always bound as parameters; identifiers go through `CQL::Identifier` or
  `Dialect#quote_identifier`. Never interpolate user input into SQL.
- A bug fix lands with a regression spec that fails without the fix.
- SQL assertions follow `spec/core/query_spec.cr`: `query.to_sql.should eq({sql, params})`.
- Only SQLite runs live in specs. Other dialects are verified with generated-SQL specs via
  `Expression::Generator.new(CQL::Adapter::Postgres)` and `query.to_sql(generator)`.
- Behavior changes are recorded under `[Unreleased]` in `CHANGELOG.md`.

## Documentation

- `docs/` follows Diátaxis (tutorials, how-to, reference, explanation). Every page must be listed in
  `docs/SUMMARY.md` and linked from its section `README.md`.
- A behavior change updates the matching docs page in the same change. Every class, method and option
  a page cites must exist in `src/`; prefer call shapes copied from `spec/`.
- Page shape, length limits per Diátaxis type, callout syntax (GitBook `{% hint %}`) and how to verify
  examples: `.claude/docs-style-guide.md`.
