<div align="center">

<img width="1038" alt="CQL, the Crystal Query Language" src="https://github.com/user-attachments/assets/ed4e733a-3d37-4d03-a4d8-d15bfd7e6f25">

# CQL

**A type-safe query builder and Active Record ORM for Crystal**<br>
SQLite · PostgreSQL · MySQL · CockroachDB

[![Crystal CI](https://github.com/azutoolkit/cql/actions/workflows/crystal.yml/badge.svg)](https://github.com/azutoolkit/cql/actions/workflows/crystal.yml)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/a85e29e6b78849c28fb813397cc3eb1a)](https://app.codacy.com/gh/azutoolkit/cql/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
[![Latest release](https://img.shields.io/github/v/release/azutoolkit/cql?sort=semver)](https://github.com/azutoolkit/cql/releases)
[![Crystal ≥ 1.12.2](https://img.shields.io/badge/crystal-%E2%89%A5%201.12.2-000000?logo=crystal)](https://crystal-lang.org/install/)
[![License: MIT](https://img.shields.io/github/license/azutoolkit/cql)](LICENSE)
[![Docs on GitBook](https://img.shields.io/badge/docs-GitBook-3884FF?logo=gitbook&logoColor=white)](https://azutopia.gitbook.io/cql)
[![API reference](https://img.shields.io/badge/API-reference-2E1052)](https://azutoolkit.github.io/cql/)

[Documentation](https://azutopia.gitbook.io/cql) ·
[Tutorials](docs/tutorials/README.md) ·
[How-to guides](docs/how-to/README.md) ·
[Reference](docs/reference/README.md) ·
[API](https://azutoolkit.github.io/cql/) ·
[Examples](examples/README.md) ·
[Changelog](CHANGELOG.md)

</div>

> [!TIP]
> The full guide is at **[azutopia.gitbook.io/cql](https://azutopia.gitbook.io/cql)**: tutorials, task guides, the
> reference and the design notes. Its source is in [`docs/`](docs/README.md), but it reads best on the site.

## Why CQL

- **Mistakes stop the build.** Schemas, models and queries are Crystal code, so a misspelled column or a value of
  the wrong type is a compiler error instead of a runtime one.
- **Values are always bound.** Every value reaches the database as a parameter, and names that can't be bound, such
  as index and alias names, are validated.
- **PostgreSQL needs no extra shard.** CQL ships its own wire-protocol driver, with a fiber-safe pool, streaming,
  pipelining and `COPY`.

Take a `users` table with a text `name` and an integer `age`. Neither of these lines compiles:

```crystal
User.where { nmae == "Ada" }  # misspelled column
User.where { age == "forty" } # a String compared with an Int32 column
```

```text
Error: undefined local variable or method 'nmae' for User::Columns (with ... yield) and top-level (current scope)
Error: CQL: cannot compare a Int32 column with String using `==`; use a Int32 value or another Int32 column
```

## Features

| Area | What you get | Guide |
| :--- | :--- | :--- |
| Schema and migrations | Tables, indexes and foreign keys in `CQL::Schema.define`. Versioned `CQL::Migration(N)` classes that apply, roll back and redo. `CQL::SchemaDump` reads an existing database back into a schema. | [Create a migration](docs/how-to/migrations/create-migration.md) |
| Models | `CQL::ActiveRecord::Model(Int64)`, or `Int32`, `UUID` and `ULID` keys, with validations, callbacks, scopes, timestamps, soft deletes, optimistic locking and opt-in dirty tracking. | [Define a model](docs/how-to/models/define-model.md) |
| Associations | `belongs_to`, `has_one`, `has_many` and `many_to_many`, with `preload` for the first three. A foreign key whose type doesn't match the target's key fails to compile. | [Has many](docs/how-to/relationships/has-many.md) |
| Typed queries | `where { (age >= 18) & (status == "active") }`, checked at compile time. Joins, CTEs, window functions, set operations, upsert, row locking, JSON and geospatial predicates, raw fragments with bound values, `explain`, and `to_sql(for: adapter)`. | [Typed where DSL](docs/how-to/querying/typed-where-dsl.md) |
| Bulk work | `insert_all`, `upsert_all` and `insert_<association>_all` send multi-row statements. `find_each`, `find_in_batches` and `pluck` keep large reads small. | [Optimize queries](docs/how-to/performance/optimize-queries.md) |
| Transactions | Nested savepoints on every adapter. | [Transactions](docs/how-to/data-operations/transactions.md) |
| Guardrails | Validated identifiers, and `CQL_VALIDATE_SCHEMA_MAPPINGS=1 crystal spec` to check model attribute types against the schema. | [Safety guardrails](docs/explanation/safety-guardrails.md) |
| Caching | Memory and Redis stores, a fragment cache with tag invalidation, and a per-request query cache with middleware for Kemal, Azu, Lucky, Amber, SpiderGazelle and `HTTP::Server`. | [Query cache](docs/how-to/caching/query-cache.md) |
| Observability | `CQL::Telemetry.subscribe` sees every statement. `CQL::Performance` adds a profiler, N+1 detection and reports. Both stay off until you enable them or run in development. | [Telemetry](docs/how-to/observability/telemetry.md) |
| PostgreSQL driver | Protocol 3.2 with fallback to 3.0, TLS, an `AsyncEngine` pool, streaming, pipelining, `COPY` and `LISTEN`/`NOTIFY`. | [Native driver](#native-postgresql-driver) |

## Installation

Add CQL and your database's driver to `shard.yml`, then run `shards install`:

```yaml
dependencies:
  cql:
    github: azutoolkit/cql
    version: ~> 0.0.861
  sqlite3: # for SQLite
    github: crystal-lang/crystal-sqlite3
  mysql: # for MySQL
    github: crystal-lang/crystal-mysql
```

> [!NOTE]
> PostgreSQL and CockroachDB need nothing more, because CQL ships the driver. CQL needs Crystal 1.12.2 or later; CI
> tests Crystal 1.19.1 and 1.22.0.

## Quick Start

Save this as `src/app.cr`:

```crystal
require "cql"
require "sqlite3"

AppDB = CQL::Schema.define(:app_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://./app.db") do
  table :users do
    primary :id, Int64, auto_increment: true
    text :name
  end
  table :posts do
    primary :id, Int64, auto_increment: true
    text :title
    bigint :user_id
  end
end

class User
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :users
  property name : String
  has_many :posts, Post, foreign_key: :user_id
  validate :name, presence: true

  def initialize(@name : String)
  end
end

class Post
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :posts
  property title : String
  property user_id : Int64?
  belongs_to :user, User, foreign_key: :user_id

  def initialize(@title : String, @user_id : Int64? = nil)
  end
end

AppDB.users.create! # CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL)
AppDB.posts.create!

ada = User.create!(name: "Ada")                           # INSERT INTO users (name) VALUES (?)
ada.posts.create(title: "Notes on the Analytical Engine") # INSERT INTO posts (title, user_id) VALUES (?, ?)

# Two queries: SELECT ... FROM posts, then SELECT ... FROM users WHERE users.id IN (?)
Post.preload(:user).all.each { |post| puts "#{post.title} by #{post.user.try(&.name)}" }

puts User.where { name == "Ada" }.count # SELECT COUNT(*) FROM users WHERE users.name = ?
puts User.new("").valid?                # the presence validation fails on a blank name
```

Run it:

```bash
crystal run src/app.cr
```

```text
Notes on the Analytical Engine by Ada
1
false
```

Next, [Your First CQL App](docs/tutorials/getting-started/your-first-cql-app.md) adds migrations, updates, deletes
and transactions.

## How It Works

```mermaid
flowchart LR
    models["Schema and models<br/>CQL::Schema.define"] --> build["Build<br/>QueryBuilder(T) → CQL::Query"]
    build --> render["Render<br/>AST → Expression::Generator<br/>with the adapter's dialect"]
    render --> execute["Execute<br/>SQL and bound values on the pool<br/>or the open transaction"]
    execute --> db[("SQLite · PostgreSQL<br/>MySQL · CockroachDB")]
    db --> hydrate["Hydrate<br/>DB::Serializable models"]
```

Each query method records one clause. At execution, `Query#build` turns the clauses into an AST, and the
`Expression::Generator` visitor writes SQL in the adapter's dialect, with placeholders (`?` or `$1`) where the values
go. [How CQL Keeps Queries Fast](docs/explanation/performance-design.md) walks through each stage and what it costs.

## Database Support

| Database | Adapter | URL | Driver | How CQL checks it |
| :--- | :--- | :--- | :--- | :--- |
| SQLite | `CQL::Adapter::SQLite` | `sqlite3://` | `sqlite3` shard | the spec suite runs live |
| PostgreSQL | `CQL::Adapter::Postgres` | `postgres://`, `postgresql://` | built in | generated-SQL specs; driver live specs on PostgreSQL 11 to 18 |
| MySQL | `CQL::Adapter::MySql` | `mysql://` | `mysql` shard | generated-SQL specs |
| CockroachDB | `CQL::Adapter::CockroachDB` | `cockroachdb://` | built in | generated-SQL specs; driver live specs on CockroachDB 24.3 |

Feature differences, such as upsert, `RETURNING`, `DISTINCT ON`, locking, JSON and the minimum versions for CTEs and
window functions, are listed in [Database Support](docs/reference/database-support.md).

## Native PostgreSQL Driver

`require "cql"` registers CQL's driver with crystal-db for `postgres://` and `postgresql://` URLs, so `CQL::Schema`
and `DB.open` use it without the `pg` shard. The [native driver guide](docs/how-to/postgres-native/README.md) covers
running alongside `pg` and opting in to `cockroachdb://` for `DB.open`.

`CQL::Postgres::AsyncEngine` has its own fiber-safe pool and is a `CQL::Executor`, so any statement runs on it with
`using`:

```crystal
DATABASE_URL = "postgres://app:secret@db.internal/app?sslmode=verify-full&pool_size=10"
engine = CQL::Postgres::AsyncEngine.connect(DATABASE_URL)

User.query.where(name: "Ada").using(engine).to_a                                         # ... WHERE users.name = $1
AppDB.query.from(:users).select(:name).where("id > ?", 10).using(engine).all(as: String) # ... WHERE id > $1

engine.transaction(isolation: :serializable) do |tx|
  AppDB.insert.into(:users).values(name: "Ada").using(tx).commit
  tx.savepoint { |inner| AppDB.insert.into(:posts).values(title: "Draft", user_id: 1_i64).using(inner).commit }
end

# 500 rows per fetch through a portal, not the whole result in memory
engine.stream(AppDB.query.from(:users).select(:id), fetch_size: 500) do |rows|
  rows.each { puts rows.read(Int64) }
end

# Several statements, one round trip
results = engine.pipeline([AppDB.query.from(:users).select(:name), AppDB.query.from(:posts).select(:title)])
results[0].as(CQL::Postgres::PipelineResult).all(as: String)

# A whole schema (models, migrations, transactions) on the engine's pool
ShopDB = CQL::Schema.new(:shop, DATABASE_URL, CQL::Adapter::Postgres, source: CQL::Postgres::EngineSource.connect(DATABASE_URL))
```

| Guide | Covers |
| :--- | :--- |
| [Native PostgreSQL Driver](docs/how-to/postgres-native/README.md) | entry points, switching from the `pg` shard |
| [AsyncEngine and pool options](docs/how-to/postgres-native/async-engine.md) | `pool_size`, health checks, `setup:`/`reset:`, errors |
| [A Schema on the engine's pool](docs/how-to/postgres-native/schema-on-engine.md) | `EngineSource` |
| [Streaming and pipelining](docs/how-to/postgres-native/streaming-and-pipelining.md) | `stream`, `pipeline`, timeouts |
| [COPY and binary parameters](docs/how-to/postgres-native/copy-and-binary-params.md) | `copy_in`, `copy_out`, `binary_params=true` |
| [TLS, poolers and timeouts](docs/how-to/postgres-native/tls-and-poolers.md) | `sslmode`, PgBouncer and other poolers, cancel, isolation |
| [Use CockroachDB](docs/how-to/configuration/cockroachdb.md) | CockroachDB differences |

### Measured Compatibility

The driver passes its live specs on PostgreSQL 11 to 18 and CockroachDB 24.3, and has been run behind PgBouncer,
Odyssey, pgcat and pgpool-II.[^live] CI also runs `spec/postgres/live_spec.cr` against a `postgres` service container
on every push.

<details>
<summary><b>PostgreSQL versions, CockroachDB, poolers and TLS</b></summary>

<br>

| PostgreSQL | Protocol used | Cancel key | SCRAM, MD5, cleartext | `live_spec.cr` |
| :--- | :--- | :--- | :--- | :--- |
| 11.22, 12.22, 13.23, 14.24, 15.19, 16.15, 17.11 | 3.0 (server answers `NegotiateProtocolVersion`) | 4 bytes | pass | pass |
| 18.6 | 3.2 | 32 bytes | pass | pass |

- **Versions**: `script/pg-matrix` runs `spec/postgres/matrix_spec.cr` and `live_spec.cr` (23 examples) against each
  server. Every version also passed re-preparing after a schema change, pipelining, `COPY` in and out, cancel after a
  statement timeout, and per-transaction `synchronous_commit: false`. PostgreSQL 19rc1, built from source, passed the
  matrix (7 of 7), `live_spec.cr` and `streaming_spec.cr` (35 examples). Untested: a final PostgreSQL 19, non-Linux or
  non-x86_64 hosts, distribution-patched builds.
- **CockroachDB** 24.3.5, insecure and with TLS plus a password: `live_spec.cr` and `streaming_spec.cr` pass except
  the `LISTEN`/`NOTIFY` example (CockroachDB has no `LISTEN`).
- **Poolers**: PgBouncer 1.22, 1.24 and 1.26 (`script/pgbouncer-matrix`), Odyssey 1.5.2, pgcat 1.2.0 and pgpool-II
  4.3.7 (`script/pooler_probes.cr`); see [Poolers](docs/how-to/postgres-native/tls-and-poolers.md#poolers) for what
  works on each.
- **TLS refusal**: `script/tls-probes` checks that a TLS requirement that cannot be met raises
  `CQL::Postgres::TLSRefused` and that crystal-db's pool does not retry it. `spec/postgres/blackhole_spec.cr` drops a
  TLS connection on a path that stops answering: 50 timed-out requests, 50 pings and 10 writes finished without
  hanging. Other TLS modes and Unix sockets were tried by hand against PostgreSQL 16; beyond that they have byte-level
  fixture and fake-server specs only.

</details>

<details>
<summary><b>Benchmarks: streaming and binary parameters</b></summary>

<br>

Two measurements on PostgreSQL 16 over loopback.[^pgbench]

- `benchmarks/pg_wire_bench.cr`, 200,000 rows of two columns: streaming 1000 rows per fetch held 1000 rows at once
  (+1.7 MB peak memory) and took 125 ms because of its 200 round trips; reading the whole result held 200,000 rows
  (+45 MB) and took 82 ms.
- `benchmarks/pg_binary_params_bench.cr`, statements per second with `binary_params` off / on (medians of 7 rounds of
  5000 statements, encoding included):

| Workload | Text | Binary |
| :--- | ---: | ---: |
| six scalars | 15,751 | 18,358 |
| one `int8` / `timestamptz` / `numeric` | 19,958 / 18,431 / 19,176 | 19,509 / 18,717 / 19,385 |
| seven-column insert | 12,902 | 13,654 |
| `int8[1000]` / `text[200]` / `numeric[200]` | 1,944 / 7,224 / 5,113 | 3,009 / 8,339 / 5,877 |
| `timestamptz[500]` | 904 | 4,929 |

A single value is within run-to-run noise, so `binary_params` stays off by default. To run both scripts on your own
server, see [benchmarks/README.md](benchmarks/README.md).

</details>

## Performance

Model reads and writes on in-memory SQLite, from `benchmarks/sqlite_bench.cr`:[^sqlite]

| Operation | Time | Allocated |
| :--- | ---: | ---: |
| `ArUser.find(id)` | 1.13 µs | 480 B |
| `ArUser.last` | 3.31 µs | 3.25 kB |
| `ArUser.query.exists?(age: 30)` | 2.78 µs | 3.1 kB |
| `create!` | 3.57 µs | 2.44 kB |
| `update!` | 3.32 µs | 2.05 kB |
| `query.from(:users).where(id: 42).to_sql` | 1.27 µs | 1.89 kB |
| join with `order` and `limit`, `to_sql` | 2.28 µs | 3.73 kB |
| 100 parents, `preload(:posts)` | 222 µs | 165 kB |

Bytes per operation repeat from run to run; time per operation depends on the machine.
[How CQL Keeps Queries Fast](docs/explanation/performance-design.md) explains what each query costs and what is off
by default.

## Documentation

The guide is published at **[azutopia.gitbook.io/cql](https://azutopia.gitbook.io/cql)** and organized by what you
need:

| Section | For | Start here |
| :--- | :--- | :--- |
| Tutorials | learning CQL step by step, from a first app to a blog | [docs/tutorials/](docs/tutorials/README.md) |
| How-to guides | one task each: models, queries, migrations, caching, performance, PostgreSQL | [docs/how-to/](docs/how-to/README.md) |
| Reference | every option, DSL method and error, and a one-page cheat sheet | [docs/reference/](docs/reference/README.md) |
| Explanation | why CQL works the way it does: Active Record, guardrails, performance | [docs/explanation/](docs/explanation/README.md) |
| Resources | FAQ and contributing | [docs/resources/](docs/resources/README.md) |

Every public type and method is in the [API reference](https://azutoolkit.github.io/cql/), generated from the doc
comments in `src/` for each release. There are also [installation notes](docs/installation.md),
[runnable examples](examples/README.md) and a [playground](playground/README.md).

## Project Status

> [!IMPORTANT]
> CQL is pre-1.0 (`0.0.x`). CI tags and releases every merge to `master`, and a release can change behavior. Read
> the [changelog](CHANGELOG.md) before you upgrade.

## Contributing

Bug reports, questions and pull requests are welcome. Open an [issue](https://github.com/azutoolkit/cql/issues) to
report a problem or discuss a change. To work on CQL itself:

```bash
shards install --ignore-crystal-version
crystal spec                                                    # SQLite runs live; PostgreSQL specs need DATABASE_URL
crystal tool format --check src spec
crystal run lib/ameba/bin/ameba.cr -- -f progress ./src ./spec  # lint, as CI runs it
```

> [!NOTE]
> Without a server, the PostgreSQL and Redis specs are pending. Without `mysqldump`, one spec in
> `spec/integration/dialects/mysql_dialect_spec.cr` errors; that is the environment, not a regression.

A bug fix comes with a spec that fails without it. A behavior change adds a `CHANGELOG.md` entry under
`[Unreleased]` and updates the matching page in `docs/`. [Contributing](docs/resources/contributing.md) has the full
workflow.

## License

CQL is released under the [MIT License](LICENSE).

[^live]: Live specs and probe scripts run against real servers on one Linux x86_64 machine. Details are in the
    collapsed sections below.
[^pgbench]: One machine, one run each.
[^sqlite]: One run of `crystal run --release benchmarks/sqlite_bench.cr`: one fiber, on a shared 4-core Linux VM.
