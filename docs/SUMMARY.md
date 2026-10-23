# Table of contents

- [CQL Documentation](README.md)
- [Installation](installation.md)

## Tutorials

- [Tutorials Overview](tutorials/README.md)
- [Getting Started](tutorials/getting-started/your-first-cql-app.md)
  - [Your First CQL App](tutorials/getting-started/your-first-cql-app.md)
  - [Adding CQL to Existing Project](tutorials/getting-started/adding-cql-to-existing-project.md)
- [Building a Blog](tutorials/building-a-blog/01-project-setup.md)
  - [Part 1: Project Setup](tutorials/building-a-blog/01-project-setup.md)
  - [Part 2: Database Schema](tutorials/building-a-blog/02-database-schema.md)
  - [Part 3: Models and Relationships](tutorials/building-a-blog/03-models-and-relationships.md)
  - [Part 4: CRUD Operations](tutorials/building-a-blog/04-crud-operations.md)
  - [Part 5: Adding Features](tutorials/building-a-blog/05-adding-features.md)
- [Real-World Examples](tutorials/real-world-examples/migration-workflows.md)
  - [Migration Workflows](tutorials/real-world-examples/migration-workflows.md)
  - [Performance Monitoring](tutorials/real-world-examples/performance-monitoring.md)

## How-to Guides

- [How-to Overview](how-to/README.md)

### Models

- [Define a Model](how-to/models/define-model.md)
- [Add Validations](how-to/models/add-validations.md)
- [Use Callbacks](how-to/models/use-callbacks.md)
- [Implement Soft Deletes](how-to/models/soft-delete.md)
- [Add Optimistic Locking](how-to/models/optimistic-locking.md)
- [Use Timestamps](how-to/models/timestamps.md)
- [Use UUID and ULID Primary Keys](how-to/models/uuid-ulid-primary-keys.md)

### Relationships

- [Set Up Belongs To](how-to/relationships/belongs-to.md)
- [Set Up Has One](how-to/relationships/has-one.md)
- [Set Up Has Many](how-to/relationships/has-many.md)
- [Set Up Many-to-Many](how-to/relationships/many-to-many.md)

### Querying

- [Find Records](how-to/querying/find-records.md)
- [Filter with Where Clauses](how-to/querying/filter-records.md)
- [Build Complex Queries](how-to/querying/complex-queries.md)
- [Create Query Scopes](how-to/querying/scopes.md)
- [Paginate Results](how-to/querying/pagination.md)
- [Use Cursor Pagination](how-to/querying/cursor-pagination.md)
- [Write Typed Queries](how-to/querying/typed-where-dsl.md)
- [Use CTEs and Recursive CTEs](how-to/querying/ctes.md)
- [Use Window Functions](how-to/querying/window-functions.md)
- [Combine Queries with Set Operations](how-to/querying/set-operations.md)
- [Upsert Records](how-to/querying/upsert.md)
- [Lock Rows](how-to/querying/row-locking.md)
- [Use FULL and CROSS Joins](how-to/querying/joins-full-cross.md)
- [Use Raw SQL Fragments Safely](how-to/querying/raw-fragments.md)
- [Inspect Queries with to_sql and explain](how-to/querying/explain-and-to-sql.md)
- [Query JSON and Geospatial Columns](how-to/querying/json-and-geo-predicates.md)

### Data Operations

- [Create Records](how-to/data-operations/create.md)
- [Update Records](how-to/data-operations/update.md)
- [Delete Records](how-to/data-operations/delete.md)
- [Use Transactions](how-to/data-operations/transactions.md)

### Migrations

- [Create a Migration](how-to/migrations/create-migration.md)
- [Run Migrations](how-to/migrations/run-migrations.md)
- [Rollback Migrations](how-to/migrations/rollback.md)
- [Add Columns](how-to/migrations/add-columns.md)
- [Create Indexes](how-to/migrations/indexes.md)
- [Dump and Validate Your Schema](how-to/migrations/schema-dump-and-validation.md)

### Configuration

- [Configure Database Connection](how-to/configuration/database-connection.md)
- [Set Up Connection Pooling](how-to/configuration/connection-pooling.md)
- [Configure Multiple Environments](how-to/configuration/environments.md)
- [Enable SSL Connections](how-to/configuration/ssl.md)
- [Use CockroachDB](how-to/configuration/cockroachdb.md)

### Native PostgreSQL Driver

- [Native PostgreSQL Driver](how-to/postgres-native/README.md)
- [Use AsyncEngine and Its Connection Pool](how-to/postgres-native/async-engine.md)
- [Stream Large Results and Pipeline Statements](how-to/postgres-native/streaming-and-pipelining.md)
- [Bulk Load with COPY and Send Binary Parameters](how-to/postgres-native/copy-and-binary-params.md)
- [Configure TLS, Poolers, Timeouts and Transactions](how-to/postgres-native/tls-and-poolers.md)

### Caching

- [Enable Query Caching](how-to/caching/query-cache.md)
- [Configure Redis Cache](how-to/caching/redis.md)
- [Use Per-Request Caching](how-to/caching/per-request.md)

### Performance

- [Optimize Queries](how-to/performance/optimize-queries.md)
- [Avoid N+1 Queries](how-to/performance/n-plus-one.md)
- [Monitor Performance](how-to/performance/monitoring.md)
- [Telemetry](how-to/performance/telemetry.md)
- [Profile Queries and Detect N+1](how-to/performance/query-profiler.md)

### Testing

- [Test Models](how-to/testing/test-models.md)
- [Set Up Test Databases](how-to/testing/test-database.md)

### Troubleshooting

- [Fix Connection Errors](how-to/troubleshooting/connection-errors.md)
- [Fix Migration Errors](how-to/troubleshooting/migration-errors.md)
- [Fix Validation Errors](how-to/troubleshooting/validation-errors.md)
- [Fix Schema Mapping Errors](how-to/troubleshooting/schema-mapping-errors.md)

## Reference

- [Reference Overview](reference/README.md)
- [Quick Reference](reference/quick-reference.md)

### API Reference

- [Migration DSL](reference/api/migration-dsl.md)
- [Validation Options](reference/api/validation-options.md)
- [Callback Hooks](reference/api/callback-hooks.md)
- [Database Support](reference/database-support.md)

### Resources

- [Glossary](reference/glossary.md)
- [Error Codes](reference/error-codes.md)

## Explanation

- [Explanation Overview](explanation/README.md)
- [Concepts](explanation/concepts/what-is-orm.md)
  - [What is an ORM?](explanation/concepts/what-is-orm.md)
- [Design Patterns](explanation/design-patterns/active-record.md)
  - [Active Record Pattern](explanation/design-patterns/active-record.md)
  - [Repository Pattern](explanation/design-patterns/repository.md)
- [Typed Query DSL: Before and After](explanation/dsl-before-after.md)
- [Safety Guardrails](explanation/safety-guardrails.md)

## Resources

- [Resources Overview](resources/README.md)
- [FAQ](resources/faq.md)
- [Community](resources/community.md)
- [Contributing](resources/contributing.md)
