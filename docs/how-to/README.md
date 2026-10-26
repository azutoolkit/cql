# How-to Guides

Each guide solves one task with code you can copy. New to CQL? Start with the [tutorials](../tutorials/README.md); for every option and method, see the [reference](../reference/README.md).

## Models

Declare models, validate them and hook into their lifecycle.

- [Define a Model](models/define-model.md)
- [Add Validations](models/add-validations.md)
- [Use Callbacks](models/use-callbacks.md)
- [Use Timestamps](models/timestamps.md)
- [Implement Soft Deletes](models/soft-delete.md)
- [Add Optimistic Locking](models/optimistic-locking.md)
- [Track Changes and Update Only Changed Columns](models/dirty-tracking.md)
- [Use UUID and ULID Primary Keys](models/uuid-ulid-primary-keys.md)

## Relationships

Connect models and load associated records.

- [Set Up Belongs To](relationships/belongs-to.md)
- [Set Up Has One](relationships/has-one.md)
- [Set Up Has Many](relationships/has-many.md)
- [Set Up Many-to-Many](relationships/many-to-many.md)

## Querying

Find, filter, page through and inspect records.

- [Find Records](querying/find-records.md)
- [Filter with Where Clauses](querying/filter-records.md)
- [Write Typed Queries](querying/typed-where-dsl.md)
- [Build Complex Queries](querying/complex-queries.md)
- [Create Query Scopes](querying/scopes.md)
- [Paginate Results](querying/pagination.md)
- [Use Cursor Pagination](querying/cursor-pagination.md)
- [Inspect Queries with to_sql and explain](querying/explain-and-to-sql.md)

## Advanced SQL

SQL features beyond simple filters, on `CQL::Query`.

- [Use CTEs and Recursive CTEs](advanced-sql/ctes.md)
- [Use Window Functions](advanced-sql/window-functions.md)
- [Combine Queries with Set Operations](advanced-sql/set-operations.md)
- [Use FULL and CROSS Joins](advanced-sql/joins-full-cross.md)
- [Use Raw SQL Fragments Safely](advanced-sql/raw-fragments.md)
- [Query JSON and Geospatial Columns](advanced-sql/json-and-geo-predicates.md)

## Data Operations

Write, change and remove rows, alone or in bulk.

- [Create Records](data-operations/create.md)
- [Update Records](data-operations/update.md)
- [Delete Records](data-operations/delete.md)
- [Upsert Records](data-operations/upsert.md)
- [Use Transactions](data-operations/transactions.md)
- [Lock Rows](data-operations/row-locking.md)

## Migrations

Evolve the schema and keep its file in sync.

- [Create a Migration](migrations/create-migration.md)
- [Run Migrations](migrations/run-migrations.md)
- [Rollback Migrations](migrations/rollback.md)
- [Add Columns](migrations/add-columns.md)
- [Create Indexes](migrations/indexes.md)
- [Dump and Validate Your Schema](migrations/schema-dump-and-validation.md)

## Configuration

Connect to a database and set CQL up per environment.

- [Configure CQL](configuration/configure-cql.md)
- [Configure Database Connection](configuration/database-connection.md)
- [Set Up Connection Pooling](configuration/connection-pooling.md)
- [Configure Multiple Environments](configuration/environments.md)
- [Enable SSL Connections](configuration/ssl.md)
- [Use CockroachDB](configuration/cockroachdb.md)

## Native PostgreSQL Driver

CQL's own PostgreSQL wire-protocol driver.

- [Native PostgreSQL Driver](postgres-native/README.md)
- [Use AsyncEngine and Its Connection Pool](postgres-native/async-engine.md)
- [Run a Schema on the AsyncEngine's Pool](postgres-native/schema-on-engine.md)
- [Stream Large Results and Pipeline Statements](postgres-native/streaming-and-pipelining.md)
- [Bulk Load with COPY and Send Binary Parameters](postgres-native/copy-and-binary-params.md)
- [Configure TLS, Poolers, Timeouts and Transactions](postgres-native/tls-and-poolers.md)

## Caching

Cache query results in memory, in Redis or per request.

- [Enable Query Caching](caching/query-cache.md)
- [Configure Redis Cache](caching/redis.md)
- [Use Per-Request Caching](caching/per-request.md)

## Performance

Send fewer, cheaper queries and measure the result.

- [Optimizing Queries in CQL](performance/optimize-queries.md)
- [Avoid N+1 Queries](performance/n-plus-one.md)
- [Benchmark CQL](performance/benchmark.md)

## Observability

See every statement, profile queries and watch production.

- [Telemetry](observability/telemetry.md)
- [Profile Queries and Detect N+1](observability/query-profiler.md)
- [Monitor Performance](observability/monitoring.md)

## Testing

Run model specs against a disposable database.

- [Set Up Test Databases](testing/test-database.md)
- [Test Models](testing/test-models.md)

## Troubleshooting

Read an error message, find the cause, apply the fix.

- [Fix Connection Errors](troubleshooting/connection-errors.md)
- [Fix Migration Errors](troubleshooting/migration-errors.md)
- [Fix Schema Mapping Errors](troubleshooting/schema-mapping-errors.md)
- [Fix Validation Errors](troubleshooting/validation-errors.md)
