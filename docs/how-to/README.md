# How-to Guides

**Task-oriented** guides that provide step-by-step instructions for accomplishing specific goals. Each guide focuses on a single task and assumes you have basic CQL knowledge.

## Models

- [Define a Model](models/define-model.md)
- [Add Validations](models/add-validations.md)
- [Use Callbacks](models/use-callbacks.md)
- [Implement Soft Deletes](models/soft-delete.md)
- [Add Optimistic Locking](models/optimistic-locking.md)
- [Use Timestamps](models/timestamps.md)
- [Use UUID and ULID Primary Keys](models/uuid-ulid-primary-keys.md)

## Relationships

- [Set Up Belongs To](relationships/belongs-to.md)
- [Set Up Has One](relationships/has-one.md)
- [Set Up Has Many](relationships/has-many.md)
- [Set Up Many-to-Many](relationships/many-to-many.md)

## Querying

- [Find Records](querying/find-records.md)
- [Filter with Where Clauses](querying/filter-records.md)
- [Build Complex Queries](querying/complex-queries.md)
- [Create Query Scopes](querying/scopes.md)
- [Paginate Results](querying/pagination.md)
- [Use Cursor Pagination](querying/cursor-pagination.md)
- [Write Typed Queries](querying/typed-where-dsl.md)
- [Use CTEs and Recursive CTEs](querying/ctes.md)
- [Use Window Functions](querying/window-functions.md)
- [Combine Queries with Set Operations](querying/set-operations.md)
- [Upsert Records](querying/upsert.md)
- [Lock Rows](querying/row-locking.md)
- [Use FULL and CROSS Joins](querying/joins-full-cross.md)
- [Use Raw SQL Fragments Safely](querying/raw-fragments.md)
- [Inspect Queries with to_sql and explain](querying/explain-and-to-sql.md)
- [Query JSON and Geospatial Columns](querying/json-and-geo-predicates.md)

## Data Operations

- [Create Records](data-operations/create.md)
- [Update Records](data-operations/update.md)
- [Delete Records](data-operations/delete.md)
- [Use Transactions](data-operations/transactions.md)

## Migrations

- [Create a Migration](migrations/create-migration.md)
- [Run Migrations](migrations/run-migrations.md)
- [Rollback Migrations](migrations/rollback.md)
- [Add Columns](migrations/add-columns.md)
- [Create Indexes](migrations/indexes.md)
- [Dump and Validate Your Schema](migrations/schema-dump-and-validation.md)

## Configuration

- [Configure Database Connection](configuration/database-connection.md)
- [Set Up Connection Pooling](configuration/connection-pooling.md)
- [Configure Multiple Environments](configuration/environments.md)
- [Enable SSL Connections](configuration/ssl.md)
- [Use CockroachDB](configuration/cockroachdb.md)

## Native PostgreSQL Driver

- [Native PostgreSQL Driver](postgres-native/README.md)
- [Use AsyncEngine and Its Connection Pool](postgres-native/async-engine.md)
- [Stream Large Results and Pipeline Statements](postgres-native/streaming-and-pipelining.md)
- [Bulk Load with COPY and Send Binary Parameters](postgres-native/copy-and-binary-params.md)
- [Configure TLS, Poolers, Timeouts and Transactions](postgres-native/tls-and-poolers.md)

## Caching

- [Enable Query Caching](caching/query-cache.md)
- [Configure Redis Cache](caching/redis.md)
- [Use Per-Request Caching](caching/per-request.md)

## Performance

- [Optimize Queries](performance/optimize-queries.md)
- [Avoid N+1 Queries](performance/n-plus-one.md)
- [Monitor Performance](performance/monitoring.md)
- [Profile Queries and Detect N+1](performance/query-profiler.md)

## Testing

- [Test Models](testing/test-models.md)
- [Set Up Test Databases](testing/test-database.md)

## Troubleshooting

- [Fix Connection Errors](troubleshooting/connection-errors.md)
- [Fix Migration Errors](troubleshooting/migration-errors.md)
- [Fix Validation Errors](troubleshooting/validation-errors.md)

---

**Need more context?** Check out the [Explanation](../explanation/README.md) section to understand the concepts behind these tasks.
