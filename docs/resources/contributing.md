# Contributing

Bug reports, fixes, features and documentation improvements are welcome. This page lists the checks CI runs and the conventions a pull request is reviewed against.

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
| Format | `crystal tool format --check src spec` | CI checks `./src`; keep `spec` formatted too. `crystal tool format src spec` applies it. |
| Lint | `crystal run lib/ameba/bin/ameba.cr -- -f progress ./src ./spec` | What CI runs. To keep a binary, `crystal build lib/ameba/bin/ameba.cr -o bin/ameba`, then run `bin/ameba`. |

Without a MySQL client, one spec errors because `mysqldump` is not installed (`spec/integration/dialects/mysql_dialect_spec.cr`). That is an environment issue, not a regression.

## What CI Runs

`.github/workflows/crystal.yml` runs on every push and pull request to `master`, in the `crystallang/crystal:1.22.0` image:

1. Installs SQLite, the PostgreSQL client and the MySQL client.
2. `shards install --ignore-crystal-version`.
3. `crystal tool format --check ./src`.
4. `crystal run lib/ameba/bin/ameba.cr -- -f progress ./src ./spec`.
5. `crystal spec` against a PostgreSQL service, with `DATABASE_URL=postgres://example:example@postgres:5432/example`.

After a green build on `master`, the same workflow bumps the version in `shard.yml` and tags a release. `.github/workflows/db-compat.yml` compiles CQL against every supported `crystal-db` version with `script/check_db_compat 0.13.1 0.14.0 0.15.0 latest`, also weekly.

To run the PostgreSQL specs locally, start the server from `docker-compose.yaml` and point `DATABASE_URL` at it; without it, the specs try `postgres://localhost/cql_test`:

```bash
docker compose up -d postgres
DATABASE_URL=postgres://example:example@localhost:5432/example crystal spec
```

## Conventions a Change Is Reviewed Against

**Design.** Apply SOLID and the patterns already in use: Visitor for SQL generation, Builder for queries and conditions, Strategy for dialects, Template Method for dialect defaults. Add a feature as a new AST node, a visitor method and a dialect hook, not as `if`/`case` branches on the adapter. Keep classes and methods small, and let names carry the meaning instead of comments.

**Safety.** Values are always bound as parameters; identifiers go through `CQL::Identifier` or `Dialect#quote_identifier`. Never interpolate user input into SQL.

**Tests.** A bug fix lands with a regression spec that fails without the fix. SQL assertions follow `spec/core/query_spec.cr`: `query.to_sql.should eq({sql, params})`. Only SQLite runs live in specs; other dialects are verified with generated-SQL specs, through `Expression::Generator.new(CQL::Adapter::Postgres)` and `query.to_sql(generator)`.

**Changelog and docs.** Record behavior changes under `[Unreleased]` in `CHANGELOG.md`. A behavior change updates the matching page in `docs/` in the same change. The docs follow Diátaxis (tutorials, how-to, reference, explanation); every page is listed in `docs/SUMMARY.md` and linked from its section `README.md`, and every class, method and option a page cites must exist in `src/`.

**Review before committing.** `CLAUDE.md` requires every commit that changes `src/`, `spec/`, `playground/` or `benchmarks/` to be reviewed by the `code-reviewer` agent (`.claude/agents/code-reviewer.md`) on the staged diff first, and every blocking finding to be fixed. Docs-only and changelog-only commits are exempt.

## Open a Pull Request

1. Fork the repository and create a branch from `master`.
2. Make the change with its specs, changelog entry and docs.
3. Run the checks above.
4. Push the branch and open a pull request against `master`. It is merged after review and a green CI run.

Questions about a contribution can go in an [issue](https://github.com/azutoolkit/cql/issues).
