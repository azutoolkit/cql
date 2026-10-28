---
description: "What each adapter supports and the SQL it generates, from the dialects in src/dialects/."
---

# Database Support

In the tables, "raises" means CQL raises `CQL::DialectError` (or the subclass named) when it generates the SQL.

## Adapters and dialects

| Adapter | Dialect | URL schemes | Driver |
| :--- | :--- | :--- | :--- |
| `CQL::Adapter::SQLite` | `Expression::SqliteDialect` | `sqlite3://path`, `sqlite3::memory:` | `sqlite3` shard |
| `CQL::Adapter::Postgres` | `Expression::PostgresDialect` | `postgres://`, `postgresql://` | native `CQL::Postgres` driver (or `pg` if it registers first) |
| `CQL::Adapter::MySql` | `Expression::MySqlDialect` | `mysql://` | `mysql` shard; `require "cql/mysql"` for modern authentication/TLS |
| `CQL::Adapter::CockroachDB` | `Expression::CockroachDialect` < `PostgresDialect` | `cockroachdb://` | native driver, as `postgres://` |

| Method | Returns |
| :--- | :--- |
| `adapter.dialect` | The shared dialect instance |
| `adapter.postgres_compatible?` | `true` for PostgreSQL and CockroachDB |
| `adapter.sql_type(Int64)` | The column type (see [Column types](api/migration-dsl.md#column-types)) |
| `adapter.driver_uri(uri)` | `cockroachdb://` rewritten to `postgres://`; others unchanged |
| `query.to_sql(for: CQL::Adapter::Postgres)` | `{sql, params}` for another adapter, without a connection |

```crystal
AppDB.query.from(:users).where(name: "Ada").to_sql(for: CQL::Adapter::Postgres)
# => {"SELECT users.id, users.name, users.email FROM users WHERE users.name = $1", ["Ada"]}
```

The main model suite uses SQLite, while native-driver specs use real PostgreSQL and CockroachDB servers when
configured. The release validation matrix adds live model and transaction contracts across all four dialects;
generated-SQL tests cover the broader dialect syntax. See the tested versions and limits below.

## Dialect properties

| Property | SQLite | PostgreSQL | MySQL | CockroachDB |
| :--- | :--- | :--- | :--- | :--- |
| `display_name` | `SQLite` | `PostgreSQL` | `MySQL` | `CockroachDB` |
| Placeholders | `?` | `$1`, `$2`, ... | `?` | `$1`, `$2`, ... |
| `max_bind_params` | 999 | 32767 | 32767 | 32767 |
| `supports_returning?` (`create!` reads the row from its INSERT) | `false` | `true` | `false` | `true` |
| `supports_transactional_ddl?` (`ddl_transaction`, used by `alter`, `build`, `create!`/`drop!`/`truncate!` and the migrator, rolls DDL back) | `true` | `true` | `false` | `false` |
| `current_timestamp` | `datetime('now')` | `CURRENT_TIMESTAMP` | `NOW(3)` | `CURRENT_TIMESTAMP` |
| `structure_dump(uri)` | `""` | the DDL `pg_dump` prints; `CQL::Error` when it fails. Password in `PGPASSWORD`, `sslmode` in `PGSSLMODE`; other query parameters ignored | the DDL `mysqldump` prints; `CQL::Error` when it fails. Password in a 0600 option file, never an argument; `--protocol=tcp` when the URI has a port | raises |
| Identifier quoting (`quote_identifiers: true`) | `"name"` | `"name"` | `` `name` `` | `"name"` |

## Queries

The release validation matrix exercises optimistic locking, nested savepoints and isolation on SQLite, PostgreSQL,
MySQL 8.0 with legacy `mysql_native_password`, MySQL 8.4 with default `caching_sha2_password` and verified TLS,
and CockroachDB 24.3. SQLite rejects explicit
`read_committed`; CockroachDB may strengthen a requested level to `serializable`. Server durability settings and
storage determine crash guarantees; CQL does not override them to claim ACID behavior.

The optional `require "cql/mysql"` integration adds modern authentication to the tested `crystal-mysql` 0.16 /
`crystal-db` 0.13 combination. It verifies TLS identity by default and rejects plaintext full-password authentication.
The original `require "mysql"` entry point alone does not gain this behavior. See
[MySQL authentication and TLS](../how-to/configuration/database-connection.md#mysql-authentication-and-tls)
for supported options and limitations. Do not weaken a deployment's authentication to match a legacy fixture.

| Feature | SQLite | PostgreSQL | MySQL | CockroachDB |
| :--- | :--- | :--- | :--- | :--- |
| `on_conflict(:email).do_update(:name)` | `ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name` (3.24+) | same | `ON DUPLICATE KEY UPDATE name = VALUES(name)`; any unique key fires it | same as PostgreSQL |
| `on_conflict(:email).do_nothing` | `ON CONFLICT (email) DO NOTHING` | same | `ON DUPLICATE KEY UPDATE email = email` | same as PostgreSQL |
| `back(:id)` on insert, update, delete | raises `SQLiteUnsupportedFeatureError` | `RETURNING users.id` | clause omitted | `RETURNING users.id` |
| `Insert#get(as:)`, `get!(as:)` | raises | yes | raises | yes |
| `distinct_on(:email)` | raises | `DISTINCT ON (users.email)` | raises | `DISTINCT ON (users.email)` |
| `lock(:update)`, `lock(:share, skip_locked: true)`, `lock(:update, nowait: true)` | raises | `FOR UPDATE`, `FOR SHARE SKIP LOCKED`, `FOR UPDATE NOWAIT` | same | same |
| `ilike` / `not_ilike` | `LOWER(col) LIKE LOWER(?)` | `ILIKE` / `NOT ILIKE` | `LOWER(col) LIKE LOWER(?)` | `ILIKE` / `NOT ILIKE` |
| `contains` / `starts_with` / `ends_with` | `col LIKE ? ESCAPE '!'`, the bound text's `%`, `_` and `!` escaped with `!`; ignores ASCII case | `col LIKE $1 ESCAPE '!'`; case-sensitive | `col LIKE ? ESCAPE '!'`; case follows the collation (the default ignores it) | as PostgreSQL |
| `json_eq(["a", "b"], v)` | `CAST(json_extract(col, ?) AS TEXT) = ?`, path `$.a.b`; booleans as `1` / `0` | `col #>> $1::text[] = $2`, path `{a,b}` | `JSON_UNQUOTE(JSON_EXTRACT(col, ?)) = ?`, path `$.a.b` | as PostgreSQL |
| `json_contains(value)` | raises | `col @> $1::jsonb` | `JSON_CONTAINS(col, ?)` | as PostgreSQL |
| `within_distance(lng, lat, meters)` | raises | `ST_DWithin(col::geography, ...)` | `ST_Distance_Sphere(col, ...) <= ?` (8.0.13+, SRID 4326, unverified live) | as PostgreSQL |
| `with`, `with_recursive` (CTEs) | 3.8.3+ | yes | 8.0+ | yes |
| `window(...)` | 3.25+ | yes | 8.0+ | yes |
| `union`, `union_all` | yes | yes | yes | yes |
| `intersect`, `except` | yes | yes | 8.0.31+ | yes |
| Set-operation operand with its own `limit` / `order` | `SELECT * FROM (...)` | `(...)` | `(...)` | `(...)` |
| `inner`, `left`, `right`, `cross` joins | yes | yes | yes | yes |
| `full(...)` join | emitted; needs SQLite 3.39+ | yes | raises | yes |
| `offset(n)` without `limit` | `LIMIT -1 OFFSET ?` | `OFFSET $1` | `LIMIT 18446744073709551615 OFFSET ?` | `OFFSET $1` |
| `explain` | `EXPLAIN QUERY PLAN` | `EXPLAIN` | `EXPLAIN` | `EXPLAIN` |
| `explain(analyze: true)` | raises | `EXPLAIN ANALYZE` | `EXPLAIN ANALYZE` (8.0.18+) | `EXPLAIN ANALYZE` |

CTEs and window functions are on `CQL::Query` (`AppDB.query`), not on `QueryBuilder`. On MySQL, quote aliases such as `rank` or `row_number` (`quote_identifiers: true`). `lock` raises `ArgumentError` for both `skip_locked:` and `nowait:`.

## Schema changes

| Feature | SQLite | PostgreSQL | MySQL | CockroachDB |
| :--- | :--- | :--- | :--- | :--- |
| `create!` | `CREATE TABLE IF NOT EXISTS` | same | same | same |
| Declared indexes | `CREATE INDEX IF NOT EXISTS` | same | `CREATE INDEX` | same as PostgreSQL |
| `drop!` | `DROP TABLE IF EXISTS` | same | same | same |
| `truncate!` | `DELETE FROM` | `TRUNCATE TABLE` | `TRUNCATE TABLE` | `TRUNCATE TABLE` |
| Auto-increment key | `INTEGER PRIMARY KEY AUTOINCREMENT` | `GENERATED ALWAYS AS IDENTITY` | `AUTO_INCREMENT` | `GENERATED ALWAYS AS IDENTITY` |
| `Bool` default | `1` / `0` | `TRUE` / `FALSE` | `TRUE` / `FALSE` | `TRUE` / `FALSE` |
| `check_constraint` | yes | yes | raises `MySqlUnsupportedFeatureError` | yes |
| Unnamed `foreign_key` in a table | unnamed | unnamed | `fk_<t>_<columns>` | unnamed |
| `add_column` | `ADD COLUMN`, with `DEFAULT`; `index: true` adds `CREATE INDEX` | same | same | same |
| `drop_column` | `DROP COLUMN` (3.35+) | yes | yes | yes |
| `rename_column` | `RENAME COLUMN` | `RENAME COLUMN` | `CHANGE old new <type> [DEFAULT ...] [NOT NULL] [AUTO_INCREMENT]` | `RENAME COLUMN` |
| `change_column` | raises `SQLiteUnsupportedFeatureError` | `ALTER COLUMN ... TYPE` | `MODIFY COLUMN <name> <type> [DEFAULT ...] [NOT NULL] [AUTO_INCREMENT]` | `ALTER COLUMN ... TYPE` |
| `foreign_key` in `schema.alter` | raises `SQLiteUnsupportedFeatureError` | `ADD CONSTRAINT` | `ADD CONSTRAINT` | `ADD CONSTRAINT` |
| `drop_foreign_key` | raises `SQLiteUnsupportedFeatureError` | `DROP CONSTRAINT` | `DROP FOREIGN KEY` | `DROP CONSTRAINT` |
| `drop_index` | `DROP INDEX IF EXISTS` | `DROP INDEX IF EXISTS` | `DROP INDEX ... ON <t>` | `DROP INDEX IF EXISTS` |
| `rename_table` | `ALTER TABLE ... RENAME TO` | same | `RENAME TABLE ... TO` | same as PostgreSQL |
| Schema change inside an open transaction | SAVEPOINT | SAVEPOINT | raises | raises |
| Failed migration run | rolled back | rolled back | earlier statements stay | earlier statements stay |

See the [Migration DSL](api/migration-dsl.md) for the full statements.

## See Also

- [Configure Database Connection](../how-to/configuration/database-connection.md)
- [Use CockroachDB](../how-to/configuration/cockroachdb.md)
- [Native PostgreSQL driver guides](../how-to/postgres-native/README.md)
- [Migration DSL](api/migration-dsl.md)
- [Error Codes](error-codes.md)
