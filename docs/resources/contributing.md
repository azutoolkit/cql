---
description: "How to report a bug, the checks CI runs, and the conventions a pull request is reviewed against."
---

# Contributing

## Report a Bug or Request a Feature

Open an issue from the [issue templates](https://github.com/azutoolkit/cql/issues/new/choose). A useful bug report names the CQL, Crystal and database versions, the smallest code that reproduces the problem, and the expected and actual behavior with any error output. A feature request describes the problem first, then the proposed solution and the alternatives you considered.

## Set Up and Run the Checks

```bash
git clone https://github.com/azutoolkit/cql.git
cd cql
shards install --ignore-crystal-version
```

| Check | Command | Notes |
| :--- | :--- | :--- |
| Tests | `crystal spec` | The full suite. PostgreSQL and Redis specs are marked pending when no server is reachable. |
| One spec file | `crystal spec spec/core/query_spec.cr` | |
| Format | `crystal tool format --check src spec` | `crystal tool format src spec` applies it. |
| Lint | `crystal run lib/ameba/bin/ameba.cr -- -f progress ./src ./spec` | What CI runs. To keep a binary, `crystal build lib/ameba/bin/ameba.cr -o bin/ameba`, then run `bin/ameba`. |
| Docs | `python3 script/docs/check_links.py`, `check_nav.py`, `gitbook_lint.py` | Links and anchors, navigation and redirects, GitBook markup. The last two need PyYAML. |
| Docs programs | `python3 script/docs/compile_snippets.py [PAGE.md ...]` | Compiles the programs and tutorials in `README.md` and `docs/`. The script's header explains which blocks count. |

Without a MySQL client, one spec errors because `mysqldump` is not installed (`spec/integration/dialects/mysql_dialect_spec.cr`). That is an environment issue, not a regression.

## What CI Runs

`.github/workflows/crystal.yml` runs on every push and pull request to `master`, in the `crystallang/crystal:1.22.0` image:

- installs SQLite, the PostgreSQL client and the MySQL client;
- `shards install --ignore-crystal-version`;
- `crystal tool format --check ./src ./spec`;
- `crystal run lib/ameba/bin/ameba.cr -- -f progress ./src ./spec`;
- `crystal spec` against a PostgreSQL service, with `DATABASE_URL=postgres://example:example@postgres:5432/example`;
- `crystal spec` again on Crystal 1.19.1, the oldest version CI tests;
- the docs checks and `compile_snippets.py` from `script/docs/`.

After a green build on `master`, `script/release` sets the next version in `shard.yml`, moves the `[Unreleased]` changelog entries under it, commits both, tags that commit and publishes a GitHub release with those entries as notes. `script/api-docs` then builds the API reference, which is deployed to GitHub Pages (the repository's Pages source must be set to GitHub Actions). `.github/workflows/db-compat.yml` compiles CQL against every supported `crystal-db` version with `script/check_db_compat 0.13.1 0.14.0 0.15.0 latest`, also weekly.

To run the PostgreSQL specs locally, start the server from `docker-compose.yaml` and point `DATABASE_URL` at it; without it, the specs try `postgres://localhost/cql_test`:

```bash
docker compose up -d postgres
DATABASE_URL=postgres://example:example@localhost:5432/example crystal spec
```

## Conventions a Change Is Reviewed Against

**Design.** Apply SOLID and the patterns already in use: Visitor for SQL generation, Builder for queries and conditions, Strategy for dialects, Template Method for dialect defaults. Add a feature as a new AST node, a visitor method and a dialect hook, not as `if`/`case` branches on the adapter. In `Expression::Generator`, a node that appears inside statements writes its SQL with a private `write(node, io)` overload and gets its String `visit` from `visit_through_write`; a node without one falls back to its String `visit`. Keep classes and methods small, and let names carry the meaning instead of comments.

**Safety.** Values are always bound as parameters; identifiers go through `CQL::Identifier` or `Dialect#quote_identifier`. Never interpolate user input into SQL.

**Tests.** A bug fix lands with a regression spec that fails without the fix. SQL assertions follow `spec/core/query_spec.cr`: `query.to_sql.should eq({sql, params})`. Only SQLite runs live in specs; other dialects are verified with generated-SQL specs, through `Expression::Generator.new(CQL::Adapter::Postgres)` and `query.to_sql(generator)`.

**Changelog and docs.** Record behavior changes under `[Unreleased]` in `CHANGELOG.md`. A behavior change updates the matching page in `docs/` in the same change. The docs follow Diátaxis (tutorials, how-to, reference, explanation); every page is listed in `docs/SUMMARY.md` and linked from its section `README.md`, and every class, method and option a page cites must exist in `src/`.

## Benchmark a Change

For a change that may affect speed, build the benchmark from `master` and from your branch into separate binaries, then run them alternately so both see the same machine conditions:

```bash
git worktree add ../cql-base master
(cd ../cql-base && shards install --ignore-crystal-version && crystal build --release -o /tmp/bench_base benchmarks/sqlite_bench.cr)
crystal build --release -o /tmp/bench_new benchmarks/sqlite_bench.cr

for i in 1 2; do
  BENCH_ONLY=join /tmp/bench_base
  BENCH_ONLY=join /tmp/bench_new
done
```

Always build with `--release`. Timings drift by several percent between runs, so trust a difference that shows in every round, and in bytes per iteration where it applies. The [benchmarks README](https://github.com/azutoolkit/cql/blob/master/benchmarks/README.md) lists every benchmark and setting.

## Open a Pull Request

Branch from `master` in your fork, ship the change with its specs, changelog entry and docs, run the checks above, and open the pull request against `master`. It is merged after review and a green CI run.

Questions about a contribution can go in an [issue](https://github.com/azutoolkit/cql/issues).
