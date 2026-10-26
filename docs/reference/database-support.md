# Database Support

Which CQL features work on which database. Each row is derived from the dialect classes in `src/dialects/` and the
query builders; unsupported features either raise `CQL::DialectError` when SQL is generated or are noted below.

Dialects: `Expression::SqliteDialect`, `Expression::MySqlDialect`, `Expression::PostgresDialect` and
`Expression::CockroachDialect` (which inherits PostgreSQL's).

Only SQLite runs live in CQL's own specs. The other dialects are checked with generated-SQL specs; the native
PostgreSQL driver and CockroachDB 24.3 were additionally verified against real servers (see the
[native PostgreSQL driver guides](../how-to/postgres-native/README.md)). The MySQL geospatial form is unverified against
a live server.

## Matrix

Legend: yes, no (raises `CQL::DialectError` unless stated), or a note.

| Feature | SQLite | PostgreSQL | MySQL | CockroachDB |
| --- | --- | --- | --- | --- |
| Placeholders | `?` | `$1`, `$2`, ... | `?` | `$1`, `$2`, ... |
| Identifier quoting (`quote_identifiers: true`) | `"name"` | `"name"` | `` `name` `` | `"name"` |
| Upsert (`on_conflict`, `upsert`) | `ON CONFLICT`, SQLite 3.24+ | `ON CONFLICT` | `ON DUPLICATE KEY UPDATE`; the conflict target is ignored, any unique key triggers it | `ON CONFLICT` |
| `RETURNING` on insert, update, delete (`back`) | no: requesting columns raises `CQL::SQLiteUnsupportedFeatureError` | yes | no, the clause is omitted | yes |
| `distinct_on` | no | yes | no | yes |
| Row locking (`lock(:update \| :share, skip_locked:, nowait:)`) | no | yes | yes | yes |
| `ilike` / `not_ilike` | emulated with `LOWER(...) LIKE LOWER(...)` | native `ILIKE` | emulated with `LOWER()` | native `ILIKE` |
| `json_eq(path, value)` | yes (`json_extract`) | yes (`#>>`) | yes (`JSON_UNQUOTE(JSON_EXTRACT(...))`) | yes |
| `json_contains(json)` | no | yes (`@>`) | yes (`JSON_CONTAINS`) | yes |
| `within_distance(lng, lat, meters)` | no | yes (`ST_DWithin` on geography) | `ST_Distance_Sphere`, MySQL 8.0.13+ | yes (as PostgreSQL) |
| CTEs (`with`, `with_recursive`) | SQLite 3.8.3+ | yes | MySQL 8.0+ | yes |
| Window functions (`window`) | SQLite 3.25+ | yes | MySQL 8.0+ | yes |
| `union`, `union_all` | yes | yes | yes | yes |
| `intersect`, `except` | yes | yes | MySQL 8.0.31+ | yes |
| Grouped set-operation operands | derived table (`SELECT * FROM (...)`) | parentheses | parentheses | parentheses |
| `INNER`, `LEFT`, `RIGHT`, `CROSS` joins | yes | yes | yes | yes |
| `FULL` join (`full`) | not blocked by CQL; needs a SQLite version that supports it | yes | no | yes |
| Bare `OFFSET` (no `LIMIT`) | `LIMIT -1 OFFSET n` | `OFFSET n` | `LIMIT 18446744073709551615 OFFSET n` | `OFFSET n` |
| `explain` | `EXPLAIN QUERY PLAN` | `EXPLAIN` | `EXPLAIN` | `EXPLAIN` |
| `explain(analyze: true)` | no | yes | MySQL 8.0.18+ | yes |
| `structure_dump` | returns an empty string | via `pg_dump` | via `mysqldump` | no |
| `Int32` column type | `INTEGER` | `INTEGER` | `INT` | `INT4` |
| `JSON::Any` column type | `TEXT` | `JSONB` | `JSON` | `JSONB` |

## Notes by Feature

### Structure Dumps

`Dialect#structure_dump(uri)` runs the database's own dump tool with the connection settings from the URI, waits for it
and returns the DDL it printed; when the tool fails it raises `CQL::Error` with the tool's error output. See
[Dump and Validate Your Schema](../how-to/migrations/schema-dump-and-validation.md#raw-structure-dumps).

### Upsert

```crystal
AppDB.insert.into(:users).values(email: "ada@example.com", name: "Ada")
  .on_conflict(:email).do_update(:name)
AppDB.insert.into(:users).values(email: "ada@example.com", name: "Ada")
  .on_conflict(:email).do_nothing
```

Not supported together with `INSERT ... SELECT`. On MySQL the generated `ON DUPLICATE KEY UPDATE` fires for any unique
key, not only the columns you name.

### Returning

`back(:id, :name)` on `Insert`, `Update` and `Delete` emits `RETURNING` where supported. MySQL drops the clause. On
SQLite, requesting columns raises `CQL::SQLiteUnsupportedFeatureError` whatever the version, with a workaround (run a
separate `SELECT`). `Insert#get(as:)`/`get!(as:)` run the insert and read the returned row. `Dialect#supports_returning?`
tells whether `Model.create!` can read the new row from its INSERT: true on PostgreSQL and CockroachDB, false on SQLite
and MySQL, which read it back with a `SELECT`. `Dialect#supports_transactional_ddl?` (used by
`Schema#ddl_transaction`, which `alter`, `build`, `Table#create!`/`drop!`/`truncate!` and the migrator go through) tells
whether a schema change rolls back with its transaction: true on SQLite and PostgreSQL,
false on MySQL, which commits DDL implicitly, and CockroachDB, which does not run it atomically in an explicit transaction.

### DISTINCT ON

PostgreSQL and CockroachDB only. Elsewhere the error suggests `ROW_NUMBER() OVER (PARTITION BY ...)` and keeping row
number 1.

### Row Locking

`query.lock(:update)` or `query.lock(:share, skip_locked: true)`; `skip_locked:` and `nowait:` are mutually exclusive
(`ArgumentError`). SQLite raises `CQL::DialectError` ("SQLite serializes writers; use a transaction instead").

### JSON and Geospatial Predicates

The JSON path is always bound as a parameter. On PostgreSQL and CockroachDB it is a `text[]` literal; on MySQL and
SQLite a `$.a.b[0]` path. On SQLite, JSON booleans compare as `1` and `0`. `within_distance` expects a geography
column on PostgreSQL and CockroachDB, and an SRID 4326 column on MySQL.

### CTEs, Window Functions and Set Operations

CTEs and window functions are available on `CQL::Query` (not on `QueryBuilder` or models yet). On MySQL, avoid window
function names such as `rank` and `row_number` as aliases unless `quote_identifiers` is on. Ordering a combined
set-operation result is not supported yet.

### Joins

`full(:t) { |j| ... }` on MySQL raises with the workaround of combining a `LEFT JOIN` and a `RIGHT JOIN` with `UNION`.

## Which Adapter Maps to Which Dialect

| Adapter | Dialect | URL schemes |
| --- | --- | --- |
| `CQL::Adapter::SQLite` | `Expression::SqliteDialect` | `sqlite3://` |
| `CQL::Adapter::Postgres` | `Expression::PostgresDialect` | `postgres://`, `postgresql://` |
| `CQL::Adapter::MySql` | `Expression::MySqlDialect` | `mysql://` |
| `CQL::Adapter::CockroachDB` | `Expression::CockroachDialect` | `cockroachdb://` |

`adapter.postgres_compatible?` is true for PostgreSQL and CockroachDB. Render SQL for another dialect without a
connection with `query.to_sql(for: CQL::Adapter::Postgres)`.

## See Also

- [Configure Database Connection](../how-to/configuration/database-connection.md)
- [Use CockroachDB](../how-to/configuration/cockroachdb.md)
- [Native PostgreSQL driver guides](../how-to/postgres-native/README.md)
