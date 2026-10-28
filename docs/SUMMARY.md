# Table of contents

- [CQL Documentation](README.md)
- [Installation](installation.md)

## Tutorials

- [Tutorials Overview](tutorials/README.md)

### Getting Started

- [Your First CQL App](tutorials/getting-started/your-first-cql-app.md)
- [Adding CQL to an Existing Project](tutorials/getting-started/adding-cql-to-existing-project.md)

### Building a Blog

- [Part 1: Project Setup](tutorials/building-a-blog/01-project-setup.md)
- [Part 2: Database Schema](tutorials/building-a-blog/02-database-schema.md)
- [Part 3: Models and Relationships](tutorials/building-a-blog/03-models-and-relationships.md)
- [Part 4: CRUD Operations](tutorials/building-a-blog/04-crud-operations.md)
- [Part 5: Adding Features](tutorials/building-a-blog/05-adding-features.md)

## How-to Guides

- [How-to Overview](how-to/README.md)

### Models

- [Define a Model](how-to/models/define-model.md)
- [Add Validations](how-to/models/add-validations.md)
- [Use Callbacks](how-to/models/use-callbacks.md)
- [Use Timestamps](how-to/models/timestamps.md)
- [Implement Soft Deletes](how-to/models/soft-delete.md)
- [Add Optimistic Locking](how-to/models/optimistic-locking.md)
- [Track Changes and Update Only Changed Columns](how-to/models/dirty-tracking.md)
- [Use UUID and ULID Primary Keys](how-to/models/uuid-ulid-primary-keys.md)

### Relationships

- [Set Up Belongs To](how-to/relationships/belongs-to.md)
- [Set Up Has One](how-to/relationships/has-one.md)
- [Set Up Has Many](how-to/relationships/has-many.md)
- [Set Up Many-to-Many](how-to/relationships/many-to-many.md)

### Querying

- [Find Records](how-to/querying/find-records.md)
- [Filter with Where Clauses](how-to/querying/filter-records.md)
- [Write Typed Queries](how-to/querying/typed-where-dsl.md)
- [Build Complex Queries](how-to/querying/complex-queries.md)
- [Create Query Scopes](how-to/querying/scopes.md)
- [Paginate Results](how-to/querying/pagination.md)
- [Use Cursor Pagination](how-to/querying/cursor-pagination.md)
- [Inspect Queries with to_sql and explain](how-to/querying/explain-and-to-sql.md)

### Advanced SQL

- [Use CTEs and Recursive CTEs](how-to/advanced-sql/ctes.md)
- [Use Window Functions](how-to/advanced-sql/window-functions.md)
- [Combine Queries with Set Operations](how-to/advanced-sql/set-operations.md)
- [Use FULL and CROSS Joins](how-to/advanced-sql/joins-full-cross.md)
- [Use Raw SQL Fragments Safely](how-to/advanced-sql/raw-fragments.md)
- [Query JSON and Geospatial Columns](how-to/advanced-sql/json-and-geo-predicates.md)

### Data Operations

- [Create Records](how-to/data-operations/create.md)
- [Update Records](how-to/data-operations/update.md)
- [Delete Records](how-to/data-operations/delete.md)
- [Upsert Records](how-to/data-operations/upsert.md)
- [Use Transactions](how-to/data-operations/transactions.md)
- [Lock Rows](how-to/data-operations/row-locking.md)

### Migrations

- [Create a Migration](how-to/migrations/create-migration.md)
- [Run Migrations](how-to/migrations/run-migrations.md)
- [Rollback Migrations](how-to/migrations/rollback.md)
- [Add Columns](how-to/migrations/add-columns.md)
- [Create Indexes](how-to/migrations/indexes.md)
- [Dump and Validate Your Schema](how-to/migrations/schema-dump-and-validation.md)

### Configuration

- [Configure CQL](how-to/configuration/configure-cql.md)
- [Configure Database Connection](how-to/configuration/database-connection.md)
- [Set Up Connection Pooling](how-to/configuration/connection-pooling.md)
- [Configure Multiple Environments](how-to/configuration/environments.md)
- [Enable SSL Connections](how-to/configuration/ssl.md)
- [Use MySQL 8.4 with Verified TLS](how-to/configuration/mysql.md)
- [Use CockroachDB](how-to/configuration/cockroachdb.md)

### Native PostgreSQL Driver

- [Native PostgreSQL Driver](how-to/postgres-native/README.md)
- [Use AsyncEngine and Its Connection Pool](how-to/postgres-native/async-engine.md)
- [Run a Schema on the AsyncEngine's Pool](how-to/postgres-native/schema-on-engine.md)
- [Stream Large Results and Pipeline Statements](how-to/postgres-native/streaming-and-pipelining.md)
- [Bulk Load with COPY and Send Binary Parameters](how-to/postgres-native/copy-and-binary-params.md)
- [Configure TLS, Poolers, Timeouts and Transactions](how-to/postgres-native/tls-and-poolers.md)

### Caching

- [Enable Query Caching](how-to/caching/query-cache.md)
- [Configure Redis Cache](how-to/caching/redis.md)
- [Use Per-Request Caching](how-to/caching/per-request.md)

### Performance

- [Optimizing Queries in CQL](how-to/performance/optimize-queries.md)
- [Avoid N+1 Queries](how-to/performance/n-plus-one.md)

### Observability

- [Telemetry](how-to/observability/telemetry.md)
- [Profile Queries and Detect N+1](how-to/observability/query-profiler.md)
- [Monitor Performance](how-to/observability/monitoring.md)

### Testing

- [Set Up Test Databases and Factories](how-to/testing/test-database.md)

### Troubleshooting

- [Fix Connection Errors](how-to/troubleshooting/connection-errors.md)
- [Fix Migration Errors](how-to/troubleshooting/migration-errors.md)
- [Fix Schema Mapping Errors](how-to/troubleshooting/schema-mapping-errors.md)
- [Fix Validation Errors](how-to/troubleshooting/validation-errors.md)

## Reference

- [Reference Overview](reference/README.md)
- [Quick Reference](reference/quick-reference.md)
- [Configuration Reference](reference/configuration.md)
- [Database Support](reference/database-support.md)
- [Error Codes](reference/error-codes.md)

### API Reference

- [Migration DSL Reference](reference/api/migration-dsl.md)
- [Validation Options Reference](reference/api/validation-options.md)
- [Callback Hooks Reference](reference/api/callback-hooks.md)

## Explanation

- [Explanation Overview](explanation/README.md)
- [Active Record Pattern](explanation/active-record-pattern.md)
- [Repository Pattern](explanation/repository-pattern.md)
- [Safety Guardrails](explanation/safety-guardrails.md)
- [How CQL Keeps Queries Fast](explanation/performance-design.md)

## Resources

- [Resources Overview](resources/README.md)
- [Frequently Asked Questions](resources/faq.md)
- [Contributing](resources/contributing.md)
