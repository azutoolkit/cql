---
description: "One task per page, with code you can copy."
icon: "list-check"
---

# How-to Guides

New to CQL? Start with the [tutorials](../tutorials/README.md); for every option and method, see the [reference](../reference/README.md).

<table data-view="cards"><thead><tr><th></th><th></th><th data-hidden data-card-target data-type="content-ref"></th></tr></thead><tbody>
<tr><td><strong>Models</strong></td><td>Declare models, validate them and hook into their lifecycle.</td><td><a href="models/define-model.md">models/define-model.md</a></td></tr>
<tr><td><strong>Relationships</strong></td><td>Connect models and load associated records.</td><td><a href="relationships/belongs-to.md">relationships/belongs-to.md</a></td></tr>
<tr><td><strong>Querying</strong></td><td>Find, filter, page through and inspect records.</td><td><a href="querying/find-records.md">querying/find-records.md</a></td></tr>
<tr><td><strong>Advanced SQL</strong></td><td>SQL features beyond simple filters, on <code>CQL::Query</code>.</td><td><a href="advanced-sql/ctes.md">advanced-sql/ctes.md</a></td></tr>
<tr><td><strong>Data Operations</strong></td><td>Write, change and remove rows, alone or in bulk.</td><td><a href="data-operations/create.md">data-operations/create.md</a></td></tr>
<tr><td><strong>Migrations</strong></td><td>Evolve the schema and keep its file in sync.</td><td><a href="migrations/create-migration.md">migrations/create-migration.md</a></td></tr>
<tr><td><strong>Configuration</strong></td><td>Connect to a database and set CQL up per environment.</td><td><a href="configuration/configure-cql.md">configuration/configure-cql.md</a></td></tr>
<tr><td><strong>Native PostgreSQL Driver</strong></td><td>CQL's own PostgreSQL wire-protocol driver.</td><td><a href="postgres-native/README.md">postgres-native/README.md</a></td></tr>
<tr><td><strong>Caching</strong></td><td>Cache query results in memory, in Redis or per request.</td><td><a href="caching/query-cache.md">caching/query-cache.md</a></td></tr>
<tr><td><strong>Performance</strong></td><td>Send fewer, cheaper queries and measure the result.</td><td><a href="performance/optimize-queries.md">performance/optimize-queries.md</a></td></tr>
<tr><td><strong>Observability</strong></td><td>See every statement, profile queries and watch production.</td><td><a href="observability/telemetry.md">observability/telemetry.md</a></td></tr>
<tr><td><strong>Testing</strong></td><td>Run model specs against a disposable database.</td><td><a href="testing/test-database.md">testing/test-database.md</a></td></tr>
<tr><td><strong>Troubleshooting</strong></td><td>Read an error message, find the cause, apply the fix.</td><td><a href="troubleshooting/connection-errors.md">troubleshooting/connection-errors.md</a></td></tr>
</tbody></table>

## Models

- [Define a Model](models/define-model.md)
- [Add Validations](models/add-validations.md)
- [Use Callbacks](models/use-callbacks.md)
- [Use Timestamps](models/timestamps.md)
- [Implement Soft Deletes](models/soft-delete.md)
- [Add Optimistic Locking](models/optimistic-locking.md)
- [Track Changes and Update Only Changed Columns](models/dirty-tracking.md)
- [Use UUID and ULID Primary Keys](models/uuid-ulid-primary-keys.md)

## Relationships

- [Set Up Belongs To](relationships/belongs-to.md)
- [Set Up Has One](relationships/has-one.md)
- [Set Up Has Many](relationships/has-many.md)
- [Set Up Many-to-Many](relationships/many-to-many.md)

## Querying

- [Find Records](querying/find-records.md)
- [Filter with Where Clauses](querying/filter-records.md)
- [Write Typed Queries](querying/typed-where-dsl.md)
- [Build Complex Queries](querying/complex-queries.md)
- [Create Query Scopes](querying/scopes.md)
- [Paginate Results](querying/pagination.md)
- [Use Cursor Pagination](querying/cursor-pagination.md)
- [Inspect Queries with to_sql and explain](querying/explain-and-to-sql.md)

## Advanced SQL

- [Use CTEs and Recursive CTEs](advanced-sql/ctes.md)
- [Use Window Functions](advanced-sql/window-functions.md)
- [Combine Queries with Set Operations](advanced-sql/set-operations.md)
- [Use FULL and CROSS Joins](advanced-sql/joins-full-cross.md)
- [Use Raw SQL Fragments Safely](advanced-sql/raw-fragments.md)
- [Query JSON and Geospatial Columns](advanced-sql/json-and-geo-predicates.md)

## Data Operations

- [Create Records](data-operations/create.md)
- [Update Records](data-operations/update.md)
- [Delete Records](data-operations/delete.md)
- [Upsert Records](data-operations/upsert.md)
- [Use Transactions](data-operations/transactions.md)
- [Lock Rows](data-operations/row-locking.md)

## Migrations

- [Create a Migration](migrations/create-migration.md)
- [Run Migrations](migrations/run-migrations.md)
- [Rollback Migrations](migrations/rollback.md)
- [Add Columns](migrations/add-columns.md)
- [Create Indexes](migrations/indexes.md)
- [Dump and Validate Your Schema](migrations/schema-dump-and-validation.md)

## Configuration

- [Configure CQL](configuration/configure-cql.md)
- [Configure Database Connection](configuration/database-connection.md)
- [Set Up Connection Pooling](configuration/connection-pooling.md)
- [Configure Multiple Environments](configuration/environments.md)
- [Enable SSL Connections](configuration/ssl.md)
- [Use MySQL 8.4 with Verified TLS](configuration/mysql.md)
- [Use CockroachDB](configuration/cockroachdb.md)

## Native PostgreSQL Driver

- [Native PostgreSQL Driver](postgres-native/README.md)
- [Use AsyncEngine and Its Connection Pool](postgres-native/async-engine.md)
- [Run a Schema on the AsyncEngine's Pool](postgres-native/schema-on-engine.md)
- [Stream Large Results and Pipeline Statements](postgres-native/streaming-and-pipelining.md)
- [Bulk Load with COPY and Send Binary Parameters](postgres-native/copy-and-binary-params.md)
- [Configure TLS, Poolers, Timeouts and Transactions](postgres-native/tls-and-poolers.md)

## Caching

- [Enable Query Caching](caching/query-cache.md)
- [Configure Redis Cache](caching/redis.md)
- [Use Per-Request Caching](caching/per-request.md)

## Performance

- [Optimizing Queries in CQL](performance/optimize-queries.md)
- [Avoid N+1 Queries](performance/n-plus-one.md)

## Observability

- [Telemetry](observability/telemetry.md)
- [Profile Queries and Detect N+1](observability/query-profiler.md)
- [Monitor Performance](observability/monitoring.md)

## Testing

- [Set Up Test Databases and Factories](testing/test-database.md)

## Troubleshooting

- [Fix Connection Errors](troubleshooting/connection-errors.md)
- [Fix Migration Errors](troubleshooting/migration-errors.md)
- [Fix Schema Mapping Errors](troubleshooting/schema-mapping-errors.md)
- [Fix Validation Errors](troubleshooting/validation-errors.md)
