# CQL Documentation

Welcome to **CQL (Crystal Query Language)** - the most comprehensive, type-safe ORM for Crystal! 🚀

CQL combines the power of raw SQL with Crystal's compile-time type safety, offering an intuitive Active Record pattern while maintaining flexibility for Repository and Data Mapper patterns. Built for performance and developer experience.

## 🎯 Quick Start Paths

Choose your learning path based on your experience level:

### 🆕 New to CQL?

1. **[What is CQL?](introduction.md)** - Understand the core concepts
2. **[Installation Guide](installation.md)** - Get up and running in 5 minutes
3. **[Your First App](guides/getting-started.md)** - Build a complete example
4. **[Core Concepts](core-concepts/README.md)** - Master the fundamentals

### 🔄 Migrating from Another ORM?

1. **[Migration Guide](guides/migration-guide.md)** - Coming from ActiveRecord, Eloquent, or others
2. **[Feature Comparison](guides/feature-comparison.md)** - See what CQL offers
3. **[Best Practices](guides/best-practices.md)** - Do it right from the start

### 🚀 Building Production Apps?

1. **[Performance Guide](guides/performance-optimization.md)** - Scale to millions of records
2. **[Deployment Guide](guides/deployment-guide.md)** - Production-ready setups
3. **[Monitoring & Debugging](guides/monitoring-debugging.md)** - Keep your app healthy

## 📚 Core Documentation

### Foundation

- **[Introduction](introduction.md)** - Why CQL and what it offers
- **[Installation](installation.md)** - Setup for all supported databases
- **[Architecture Overview](guides/architecture-overview.md)** - How CQL works under the hood

### Core Concepts

- **[Schema Definition](core-concepts/schemas.md)** - Design your database structure
- **[Database Initialization](core-concepts/initializing-the-database.md)** - Get your database ready
- **[Schema Evolution](core-concepts/altering-the-schema.md)** - Modify your schema safely
- **[Migrations](core-concepts/migrations.md)** - Version control your database
- **[CRUD Operations](core-concepts/crud-operations/README.md)** - Create, Read, Update, Delete
- **[Design Patterns](core-concepts/patterns/README.md)** - Active Record vs Repository patterns

## 🏗️ Active Record with CQL

### Getting Started

- **[Defining Models](guides/active-record-with-cql/defining-models.md)** - Create your first models
- **[CRUD Operations](guides/active-record-with-cql/crud-operations.md)** - Basic data operations
- **[Persistence Details](guides/active-record-with-cql/persistence-details.md)** - How saving works

### Querying & Data Retrieval

- **[Basic Querying](guides/active-record-with-cql/queryable.md)** - Find what you need
- **[Complex Queries](guides/active-record-with-cql/complex-queries.md)** - Advanced query techniques
- **[Scopes](guides/active-record-with-cql/scopes.md)** - Reusable query logic

### Data Integrity & Validation

- **[Validations](guides/active-record-with-cql/validations.md)** - Ensure data quality
- **[Callbacks](guides/active-record-with-cql/callbacks.md)** - Hook into model lifecycle
- **[Optimistic Locking](guides/active-record-with-cql/optimistic-locking.md)** - Handle concurrent updates

### Relationships

- **[Relations Overview](guides/active-record-with-cql/relations/README.md)** - Connect your data
- **[belongs_to](guides/active-record-with-cql/relations/belongsto.md)** - Many-to-one relationships
- **[has_one](guides/active-record-with-cql/relations/hasone.md)** - One-to-one relationships
- **[has_many](guides/active-record-with-cql/relations/hasmany.md)** - One-to-many relationships
- **[many_to_many](guides/active-record-with-cql/relations/manytomany.md)** - Many-to-many relationships

### Advanced Features

- **[Transactions](guides/active-record-with-cql/transactions.md)** - Maintain data consistency
- **[Database Migrations](guides/active-record-with-cql/migrations.md)** - Evolve your schema
- **[Touch Operations](guides/active-record-with-cql/touch.md)** - Update timestamps efficiently

## 🔧 Advanced Topics

### Alternative Patterns

- **[Repository Pattern](core-concepts/patterns/repository.md)** - Alternative to Active Record
- **[Data Mapper Pattern](core-concepts/patterns/data-mapper.md)** - Separate your domain from persistence
- **[Service Layer Pattern](guides/patterns/service-layer.md)** - Organize complex business logic

### Performance & Scaling

- **[Query Optimization](guides/performance/query-optimization.md)** - Make your queries fast
- **[Connection Pooling](guides/performance/connection-pooling.md)** - Manage database connections
- **[Caching Strategies](guides/performance/caching-strategies.md)** - Speed up your app
- **[Database Indexing](guides/performance/indexing-guide.md)** - Optimize your database

### Database Management

- **[Schema Dumping](guides/schema-dump.md)** - Export your schema
- **[Migration Strategies](guides/handling-migrations.md)** - Deploy schema changes safely
- **[Backup & Recovery](guides/backup-recovery.md)** - Protect your data

### Testing & Quality Assurance

- **[Testing Guide](guides/testing-guide.md)** - Test your database code
- **[Test Data Management](guides/test-data-management.md)** - Manage test data effectively
- **[Performance Testing](guides/performance-testing.md)** - Ensure your app scales

## 🎨 Real-World Examples

### Complete Applications

- **[Blog Engine](examples/blog-engine/README.md)** - Posts, comments, users, and tags
- **[E-commerce Platform](examples/ecommerce/README.md)** - Products, orders, payments
- **[Social Network](examples/social-network/README.md)** - Users, posts, followers, messages

### Common Patterns

- **[Multi-tenancy](examples/patterns/multi-tenancy.md)** - SaaS application architecture
- **[Audit Logging](examples/patterns/audit-logging.md)** - Track data changes
- **[Soft Deletes](examples/patterns/soft-deletes.md)** - Keep deleted records
- **[Content Versioning](examples/patterns/content-versioning.md)** - Track content changes

## 🌍 Database-Specific Guides

### PostgreSQL

- **[PostgreSQL Features](guides/databases/postgresql-features.md)** - JSONB, arrays, custom types
- **[PostgreSQL Performance](guides/databases/postgresql-performance.md)** - Optimize for PostgreSQL
- **[PostgreSQL Extensions](guides/databases/postgresql-extensions.md)** - Use PostgreSQL extensions

### MySQL

- **[MySQL Features](guides/databases/mysql-features.md)** - MySQL-specific optimizations
- **[MySQL Performance](guides/databases/mysql-performance.md)** - Tune for MySQL
- **[MySQL Compatibility](guides/databases/mysql-compatibility.md)** - Version compatibility

### SQLite

- **[SQLite Features](guides/databases/sqlite-features.md)** - Lightweight database features
- **[SQLite Limitations](guides/databases/sqlite-limitations.md)** - What to watch out for
- **[SQLite in Production](guides/databases/sqlite-production.md)** - Using SQLite at scale

## 🛠️ Tools & Utilities

### Development Tools

- **[CQL CLI](tools/cql-cli.md)** - Command-line interface
- **[Schema Inspector](tools/schema-inspector.md)** - Analyze your schema
- **[Query Analyzer](tools/query-analyzer.md)** - Optimize your queries

### IDE Integration

- **[VS Code Setup](tools/vscode-setup.md)** - Crystal and CQL extensions
- **[Vim/Neovim Setup](tools/vim-setup.md)** - Syntax highlighting and completion

## 🆘 Help & Troubleshooting

### Common Issues

- **[Troubleshooting Guide](troubleshooting.md)** - Solve common problems
- **[Error Reference](guides/error-reference.md)** - Understand error messages
- **[FAQ](faqs.md)** - Frequently asked questions

### Getting Help

- **[Community](guides/community.md)** - Connect with other developers
- **[Contributing](guides/contributing.md)** - Help improve CQL
- **[Support](guides/support.md)** - Get professional support

## 📊 Quick Reference

### Cheat Sheets

- **[Query Methods](reference/query-methods.md)** - All query methods at a glance
- **[Model Methods](reference/model-methods.md)** - Model lifecycle methods
- **[Migration Methods](reference/migration-methods.md)** - Schema modification methods
- **[Validation Rules](reference/validation-rules.md)** - All built-in validators

### API Reference

- **[Core API](reference/core-api.md)** - Schema, Query, Migration classes
- **[Active Record API](reference/active-record-api.md)** - Model methods and callbacks
- **[Validation API](reference/validation-api.md)** - Validation methods and custom validators

---

## 🏁 Where to Start?

**New to ORMs?** → Start with [Introduction](introduction.md) → [Installation](installation.md) → [Getting Started](guides/getting-started.md)

**Experienced with ORMs?** → [Feature Comparison](guides/feature-comparison.md) → [Migration Guide](guides/migration-guide.md) → [Best Practices](guides/best-practices.md)

**Building for Production?** → [Performance Guide](guides/performance-optimization.md) → [Deployment Guide](guides/deployment-guide.md) → [Monitoring](guides/monitoring-debugging.md)

**Need Specific Feature?** → Use the search function or browse the [Complete Table of Contents](SUMMARY.md)

---

> 💡 **Tip**: All examples in this documentation are tested and verified to work with the latest version of CQL. Every code sample you see here runs successfully in our test suite!

Ready to build something amazing? Let's get started! 🎉
