# CQL Docs Style Guide

Rules for every page under `docs/`. `docs/how-to/performance/optimize-queries.md` is the reference
how-to page.

## Every page

- **Accurate first.** Every class, method, option and output a page shows exists in `src/` and behaves
  as described. Copy call shapes from `spec/`. Every Crystal example compiles and runs against the
  current code. SQL quoted in comments is the SQL CQL emits. Fix wrong docs; never document an API
  that does not exist.
- **No fluff.** No "In this guide we will...", no marketing, no unsourced performance claims. The page's
  one-sentence purpose is its frontmatter `description` (see GitBook features); the body goes straight to
  the task.
- **Stable URLs.** Move or delete a page only with a redirect from its old path in `docs/.gitbook.yaml`
  and updates to `docs/SUMMARY.md` and the section `README.md`. Keep the H1 unless it is wrong; a
  changed H1 also changes those labels.
- **No duplicates.** Each topic has one owning page; other pages link to it instead of repeating it. A
  how-to keeps the steps of its own task even when another page covers them in depth.
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
  at most). GitBook publishes only `docs/`, so a link to anything outside it (the repo `README.md`,
  `examples/`, `benchmarks/`, `CHANGELOG.md`, `src/`) is an absolute `https://github.com/azutoolkit/cql/...`
  URL. Files outside `docs/` render on GitHub, so they use GitHub alerts (`> [!NOTE]`), not hints.
- **Redirects** in `docs/.gitbook.yaml` are `old/path: new/path.md`, relative to `docs/`, with no
  leading slash and no `.md` on the key.

## GitBook features

GitBook publishes `docs/`, so pages use its blocks. They show as raw tags on GitHub; that is accepted.
Never nest a block inside one of the same kind, and never put `<details>` inside tabs or a stepper.

- **Frontmatter on every page.** `description` is the one-sentence purpose GitBook shows under the title;
  always quote it. `icon` (a Font Awesome name) goes only on landing pages: `docs/README.md`,
  `installation.md`, section `README.md` files.

  ```
  ---
  description: "Load associations for many records with one extra query each."
  ---
  ```
- **Tabs** for mutually exclusive variants the reader picks one of: database or adapter, web framework,
  cache store. Not for ❌/✅ pairs and not for steps.

  ```
  {% tabs %}
  {% tab title="SQLite" %}
  ...
  {% endtab %}
  {% tab title="PostgreSQL" %}
  ...
  {% endtab %}
  {% endtabs %}
  ```
- **Stepper** for every tutorial's numbered steps. Each step starts with a `###` heading and ends with its
  "Check:" line. End each tutorial part with a `content-ref` card to the next part.

  ```
  {% stepper %}
  {% step %}
  ### Create the project
  ...
  {% endstep %}
  {% endstepper %}

  {% content-ref url="02-database-schema.md" %}
  [02-database-schema.md](02-database-schema.md)
  {% endcontent-ref %}
  ```
- **Code titles** for a snippet that is a whole file the reader creates or edits (tutorial files,
  migrations, specs, `shard.yml`, config). The title replaces a file-name comment on the first line.

  ````
  {% code title="src/app.cr" %}
  ```crystal
  ...
  ```
  {% endcode %}
  ````
- **Expandables** for long optional material: full error output, a complete example, a long sub-table.

  ```
  <details>
  <summary>Complete example</summary>

  ...

  </details>
  ```
- **Cards** on landing pages, one per destination page:

  ```
  <table data-view="cards"><thead><tr><th></th><th></th><th data-hidden data-card-target data-type="content-ref"></th></tr></thead><tbody>
  <tr><td><strong>Tutorials</strong></td><td>Learn CQL step by step.</td><td><a href="tutorials/README.md">tutorials/README.md</a></td></tr>
  </tbody></table>
  ```
- Every `{% x %}` has its `{% endx %}`, frontmatter is valid YAML, and every `url=` / `href=` target exists.

## By page type (Diátaxis)

| Type | Shape | Limits |
| :--- | :--- | :--- |
| **How-to** (`docs/how-to/`) | frontmatter description → H1 (imperative) → task sections, each led by code → hints → See Also | ≤ 450 prose words outside code blocks; ≥ 60% code by lines. A page whose subject is not code (e.g. troubleshooting) may go to 600 words. |
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
