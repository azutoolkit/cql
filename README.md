[![Crystal CI](https://github.com/azutoolkit/cql/actions/workflows/crystal.yml/badge.svg)](https://github.com/azutoolkit/cql/actions/workflows/crystal.yml)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/a85e29e6b78849c28fb813397cc3eb1a)](https://app.codacy.com/gh/azutoolkit/cql/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)

# CQL (Crystal Query Language)

<img width="1038" alt="cql-banner" src="https://github.com/user-attachments/assets/ed4e733a-3d37-4d03-a4d8-d15bfd7e6f25">

CQL is a query builder and Active Record ORM for Crystal that runs on SQLite, PostgreSQL, MySQL and CockroachDB.
Schemas, models and queries are Crystal code, so a misspelled column or a value of the wrong type fails at compile
time, and every value reaches the database as a bound parameter. It ships its own PostgreSQL wire-protocol driver.

Full documentation: [azutopia.gitbook.io/cql](https://azutopia.gitbook.io/cql) (source in [`docs/`](docs/README.md)).

## Features

- **Schema and migrations**: tables, columns, indexes and foreign keys in `CQL::Schema.define`; versioned
  `CQL::Migration(N)` classes run by a migrator that applies, rolls back and redoes them and can keep a schema file in
  sync; `CQL::SchemaDump` turns an existing database into a schema definition.
- **Active Record models**: `CQL::ActiveRecord::Model(Int64)` (also `Int32`, `UUID` and `ULID` keys) with validations,
  callbacks, scopes, timestamps, soft deletes, optimistic locking and opt-in dirty tracking.
- **Associations**: `belongs_to`, `has_one`, `has_many` and `many_to_many`, with `preload` for the first three. A foreign
  key whose type does not match the target's primary key fails at compile time.
- **Typed queries**: `User.where { (age >= 18) & (status == "active") }` checks column names and value types at compile
  time. Association joins, CTEs, window functions, set operations, upsert, row locking, JSON and geospatial
  predicates, raw fragments with bound values, `explain`, and `to_sql(for: adapter)` for any dialect.
- **Bulk work**: `insert_all`, `upsert_all` and `insert_<association>_all` send multi-row statements; `find_each`,
  `find_in_batches` and `pluck` keep large reads small.
- **Transactions** with nested savepoints on every adapter.
- **Guardrails**: identifiers that cannot be bound (index, constraint and alias names) are validated, and
  `CQL_VALIDATE_SCHEMA_MAPPINGS=1` checks model attribute types against the schema at boot.
- **Caching**: memory and Redis stores, a fragment cache with tag invalidation, and a per-request query cache with
  middleware for Kemal, Azu, Lucky, Amber, SpiderGazelle and plain `HTTP::Server`.
- **Observability**: `CQL::Telemetry.subscribe` sees every statement; the `CQL::Performance` monitor adds a query
  profiler, N+1 detection and text, JSON and HTML reports. Both are off until you enable them or run in development.
- **[Native PostgreSQL driver](#native-postgresql-driver)**: protocol 3.2 with fallback to 3.0, TLS, an `AsyncEngine`
  connection pool, streaming, pipelining, `COPY` and `LISTEN`/`NOTIFY`, without the `pg` shard.

## Installation

Add CQL and the driver for your database to `shard.yml`:

```yaml
dependencies:
  cql:
    github: azutoolkit/cql
    version: ~> 0.0.798
  sqlite3: # SQLite
    github: crystal-lang/crystal-sqlite3
  mysql: # MySQL
    github: crystal-lang/crystal-mysql
  # PostgreSQL and CockroachDB need nothing more: CQL ships the driver.
```

```bash
shards install
```

CQL needs Crystal 1.12.2 or later (`shard.yml`); CI builds with Crystal 1.22.0.

## Quick Start

```crystal
require "cql"
require "sqlite3"

AppDB = CQL::Schema.define(:app_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://./app.db") do
  table :users do
    primary :id, Int64, auto_increment: true
    text :name
    text :email
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
  property email : String

  has_many :posts, Post, foreign_key: :user_id
  validate :email, presence: true

  def initialize(@name : String, @email : String)
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

AppDB.users.create! # CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, ...)
AppDB.posts.create!

ada = User.create!(name: "Ada", email: "ada@example.com")  # INSERT INTO users (name, email) VALUES (?, ?)
ada.posts.create(title: "Notes on the Analytical Engine")  # INSERT INTO posts (title, user_id) VALUES (?, ?)

# Two queries: SELECT ... FROM posts, then SELECT ... FROM users WHERE users.id IN (?)
Post.preload(:user).all.each do |post|
  puts "#{post.title} by #{post.user.try(&.name)}" # => Notes on the Analytical Engine by Ada
end

puts User.where { name == "Ada" }.count # => 1   SELECT COUNT(*) FROM users WHERE users.name = ?
puts User.new("Grace", "").valid?       # => false (email is blank)
```

```bash
crystal run src/app.cr
```

Next: [Your First CQL App](docs/tutorials/getting-started/your-first-cql-app.md) adds migrations, updates, deletes and
transactions.

## Database Support

| Database | Adapter | URL | Driver | How CQL checks it |
| --- | --- | --- | --- | --- |
| SQLite | `CQL::Adapter::SQLite` | `sqlite3://` | `sqlite3` shard | the spec suite runs live |
| PostgreSQL | `CQL::Adapter::Postgres` | `postgres://`, `postgresql://` | built in | generated-SQL specs; driver live specs on PostgreSQL 11 to 18 |
| MySQL | `CQL::Adapter::MySql` | `mysql://` | `mysql` shard | generated-SQL specs |
| CockroachDB | `CQL::Adapter::CockroachDB` | `cockroachdb://` | built in | generated-SQL specs; driver live specs on CockroachDB 24.3 |

Feature differences (upsert, `RETURNING`, `DISTINCT ON`, locking, JSON, minimum versions for CTEs and window
functions) are listed in [Database Support](docs/reference/database-support.md).

## Native PostgreSQL Driver

`require "cql"` registers CQL's driver with crystal-db for `postgres://` and `postgresql://` URLs, so
`CQL::Schema` and `DB.open` use it. If your app also requires the `pg` shard, that shard serves those URLs instead;
compile with `-Dcql_no_postgres_driver` to keep CQL's driver out of crystal-db's registry. `cockroachdb://` for
`DB.open` is opt-in: call `CQL::Postgres::Driver.register_cockroachdb` or compile with
`-Dcql_postgres_driver_cockroachdb`.

`CQL::Postgres::AsyncEngine` has its own fiber-safe pool and is a `CQL::Executor`, so any statement runs on it with
`using`:

```crystal
url = "postgres://app:secret@db.internal/app?sslmode=verify-full&pool_size=10"
engine = CQL::Postgres::AsyncEngine.connect(url)

User.query.where(name: "Ada").using(engine).to_a
AppDB.query.from(:users).select(:name).where("id > ?", 10).using(engine).all(as: String)

engine.transaction(isolation: :serializable) do |tx|
  AppDB.insert.into(:users).values(name: "Ada", email: "ada@example.com").using(tx).commit
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
ShopDB = CQL::Schema.new(:shop, url, CQL::Adapter::Postgres, source: CQL::Postgres::EngineSource.connect(url))
```

| Guide | Covers |
| --- | --- |
| [Native PostgreSQL Driver](docs/how-to/postgres-native/README.md) | entry points, switching from the `pg` shard |
| [AsyncEngine and pool options](docs/how-to/postgres-native/async-engine.md) | `pool_size`, health checks, `setup:`/`reset:`, errors |
| [A Schema on the engine's pool](docs/how-to/postgres-native/schema-on-engine.md) | `EngineSource` |
| [Streaming and pipelining](docs/how-to/postgres-native/streaming-and-pipelining.md) | `stream`, `pipeline`, timeouts |
| [COPY and binary parameters](docs/how-to/postgres-native/copy-and-binary-params.md) | `copy_in`, `copy_out`, `binary_params=true` |
| [TLS, poolers and timeouts](docs/how-to/postgres-native/tls-and-poolers.md) | `sslmode`, PgBouncer and other poolers, cancel, isolation |
| [Use CockroachDB](docs/how-to/configuration/cockroachdb.md) | CockroachDB differences |

### Measured Compatibility

These results come from running the live specs and scripts against real servers on one Linux x86_64 machine. CI
also sets `DATABASE_URL` to a `postgres` service container, so `spec/postgres/live_spec.cr` runs there on every push.

| PostgreSQL | Protocol used | Cancel key | SCRAM, MD5, cleartext | `live_spec.cr` |
| --- | --- | --- | --- | --- |
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
  hanging.

Two measurements on PostgreSQL 16 over loopback, one machine, one run each:

- `benchmarks/pg_wire_bench.cr`, 200,000 rows of two columns: streaming 1000 rows per fetch held 1000 rows at once
  (+1.7 MB peak memory) and took 125 ms because of its 200 round trips; reading the whole result held 200,000 rows
  (+45 MB) and took 82 ms.
- `benchmarks/pg_binary_params_bench.cr`, statements per second with `binary_params` off / on (medians of 7 rounds of
  5000 statements, encoding included):

| Workload | Text | Binary |
| --- | --- | --- |
| six scalars | 15,751 | 18,358 |
| one `int8` / `timestamptz` / `numeric` | 19,958 / 18,431 / 19,176 | 19,509 / 18,717 / 19,385 |
| seven-column insert | 12,902 | 13,654 |
| `int8[1000]` / `text[200]` / `numeric[200]` | 1,944 / 7,224 / 5,113 | 3,009 / 8,339 / 5,877 |
| `timestamptz[500]` | 904 | 4,929 |

A single value is within run-to-run noise, so `binary_params` stays off by default. Run both scripts on your own
server: [benchmarks/README.md](benchmarks/README.md).

## Performance

One run of `crystal run --release benchmarks/sqlite_bench.cr` (in-memory SQLite, one fiber, a shared 4-core Linux
VM). Bytes per operation repeat from run to run; time per operation depends on the machine.

| Operation | Time | Allocated |
| --- | --- | --- |
| `ArUser.find(id)` | 1.13 µs | 480 B |
| `ArUser.last` | 3.31 µs | 3.25 kB |
| `ArUser.query.exists?(age: 30)` | 2.78 µs | 3.1 kB |
| `create!` | 3.57 µs | 2.44 kB |
| `update!` | 3.32 µs | 2.05 kB |
| `query.from(:users).where(id: 42).to_sql` | 1.27 µs | 1.89 kB |
| join with `order` and `limit`, `to_sql` | 2.28 µs | 3.73 kB |
| 100 parents, `preload(:posts)` | 222 µs | 165 kB |

What each query costs, and what is off by default: [How CQL Keeps Queries Fast](docs/explanation/performance-design.md).

## Documentation

| Section | Start here | For |
| --- | --- | --- |
| Tutorials | [docs/tutorials/](docs/tutorials/README.md) | learning CQL step by step, from a first app to a blog |
| How-to guides | [docs/how-to/](docs/how-to/README.md) | one task each: models, queries, migrations, caching, performance, PostgreSQL |
| Reference | [docs/reference/](docs/reference/README.md) | every option, DSL method and error, plus the [quick reference](docs/reference/quick-reference.md) |
| Explanation | [docs/explanation/](docs/explanation/README.md) | why CQL works the way it does: Active Record, guardrails, performance |
| Resources | [docs/resources/](docs/resources/README.md) | FAQ, community, contributing |

Also: [Installation](docs/installation.md), [runnable examples](examples/README.md),
[playground](playground/README.md), [changelog](CHANGELOG.md).

## Contributing

```bash
shards install --ignore-crystal-version
crystal spec                                                    # SQLite live; PostgreSQL specs need DATABASE_URL
crystal tool format --check src spec
crystal run lib/ameba/bin/ameba.cr -- -f progress ./src ./spec  # lint, as CI runs it
```

> [!NOTE]
> Without a server, the PostgreSQL and Redis specs are pending. Without `mysqldump`, one spec in
> `spec/integration/dialects/mysql_dialect_spec.cr` errors; that is the environment, not a regression.

A bug fix comes with a spec that fails without it, and a behavior change updates `CHANGELOG.md` under `[Unreleased]`
and the matching page in `docs/`. See [Contributing](docs/resources/contributing.md) for the full workflow.

## License

MIT, see [LICENSE](LICENSE).
