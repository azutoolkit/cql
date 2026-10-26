# CQL Docs Style Guide

Rules for every page under `docs/`. `docs/how-to/performance/optimize-queries.md` is the reference
how-to page.

## Every page

- **Accurate first.** Every class, method, option and output a page shows exists in `src/` and behaves
  as described. Copy call shapes from `spec/`. Every Crystal example compiles and runs against the
  current code. SQL quoted in comments is the SQL CQL emits. Fix wrong docs; never document an API
  that does not exist.
- **No fluff.** No "In this guide we will...", no marketing, no unsourced performance claims. The first
  line after the H1 says what the page does in one sentence, or the page goes straight to code.
- **Same URL.** Never move, rename or delete a page. Keep the H1 unless it is wrong. A changed H1 must
  also change the labels in `docs/SUMMARY.md` and the section `README.md`.
- **Headings others link to.** These anchors are linked from other pages. Keep their heading text:
  `tls-and-poolers#poolers`, `#tls`, `#transactions-isolation-and-savepoints`;
  `has-many#when-the-parent-is-deleted`; `define-model#primary-key-on-another-column`;
  `telemetry#transactions`, `#connection-pool`; `redis#configure-from-the-environment`;
  `query-profiler#what-monitoring-costs`, `#log-sql`, `#health-and-metrics`;
  `query-cache#fragment-cache-and-tag-invalidation`; `async-engine#pool-options`;
  `schema-mapping-errors#fix-primary-key-mismatches`;
  `configure-cql#build_migrator-versus-schemamigrator`; `performance-design#what-is-off-by-default`.
- **Callouts** are GitBook hints. Use at most four per page and keep each one to one or two sentences:

  ```
  {% hint style="info" %}
  Text.
  {% endhint %}
  ```

  `info` is for notes, `success` for tips, `warning` for pitfalls, `danger` for data loss or security.
  Never use `> [!NOTE]` or bold-quote notes.
- **Code blocks** are fenced with a language (`crystal`, `sql`, `bash`, `yaml`, `text`). Use the shared
  names: schema `AppDB`, models `User`, `Post`, `Comment`, `Profile`. Use `# ❌` / `# ✅` comments for
  bad/good pairs; use no other emoji.
- **Tables** for options, comparisons and anti-pattern/fix pairs. Use **bold inline code** only for the
  API a sentence or row is about.
- **Names:** CQL, PostgreSQL, SQLite, MySQL, CockroachDB, `QueryBuilder` (what `Model.query` and
  `Model.where` return), `CQL::Query` (what `AppDB.query` returns).
- **Links** are relative and must resolve. End how-to and reference pages with `## See Also` (6 links
  at most).

## By page type (Diátaxis)

| Type | Shape | Limits |
| :--- | :--- | :--- |
| **How-to** (`docs/how-to/`) | H1 (imperative) → one-line goal → task sections, each led by code → hints → See Also | ≤ 450 prose words outside code blocks; ≥ 60% code by lines. A page whose subject is not code (e.g. troubleshooting) may go to 600 words. |
| **Reference** (`docs/reference/`) | Tables listing every option or method with signature, default and meaning, plus one example per item | No narrative. Terse cells. No word cap. |
| **Tutorial** (`docs/tutorials/`) | Numbered steps. Each step: what to do, the code, and how to check it worked (command and expected output) | Keep the story; cut prose 30–50%. The code must run end to end in order. |
| **Explanation** (`docs/explanation/`, `docs/resources/`) | Short paragraphs under claim-style headings; tables or diagrams where they help | Prose is fine; ≤ 1,200 words. No step-by-step instructions (link to the how-to instead). |

## Verifying examples

- Use the Crystal version CI uses (`.github/workflows/crystal.yml`) and run `shards install
  --ignore-crystal-version`. Build from the repo root so `lib/` resolves.
- Put the page's snippets in a scratch script outside the repo that requires `src/cql` by a relative
  path, plus `require "sqlite3"`. Run it against a SQLite file next to the script, and print the SQL
  (a `CQL::Telemetry.subscribe` block collects `event.sql`) so the comments can be checked.
- Without a PostgreSQL, MySQL, CockroachDB or Redis server, verify those examples with generated SQL
  (`query.to_sql(for: CQL::Adapter::Postgres)`, or `Expression::Generator.new(CQL::Adapter::Postgres)`)
  or with `crystal build --no-codegen`, and say which examples could not run.
