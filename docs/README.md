# CQL Documentation

Welcome to **CQL (Crystal Query Language)** - the most comprehensive, type-safe ORM for Crystal! 🚀

CQL combines the power of raw SQL with Crystal's compile-time type safety, offering an intuitive Active Record pattern while maintaining flexibility for Repository and Data Mapper patterns. Built for performance and developer experience, with comprehensive monitoring tools for query optimization and N+1 detection.

## 🎯 Quick Start Paths

Choose your learning path based on your experience level:

### 🆕 New to CQL?

1. **[What is CQL?](introduction.md)** - Understand the core concepts
2. **[Installation Guide](installation.md)** - Get up and running in 5 minutes
3. **[Configuration Guide](guides/configuration.md)** - Configure CQL for your environment
4. **[Your First App](guides/getting-started.md)** - Build a complete example
5. **[Core Concepts](core-concepts/README.md)** - Master the fundamentals

### 🔄 Migrating from Another ORM?

1. **[Migration Guide](guides/migration-guide.md)** - Coming from ActiveRecord, Eloquent, or others
2. **[Feature Comparison](guides/feature-comparison.md)** - See what CQL offers
3. **[Best Practices](guides/best-practices.md)** - Do it right from the start

### 🚀 Building Production Apps?

1. **[Performance Guide](guides/performance-optimization.md)** - Scale to millions of records
2. **[Performance Monitoring](guides/performance-tools.md)** - Query analysis and N+1 detection
3. **[Monitoring Architecture](guides/performance-monitoring-architecture.md)** - Advanced monitoring patterns

## 📚 Core Documentation

### Foundation

- **[Introduction](introduction.md)** - Why CQL and what it offers
- **[Installation](installation.md)** - Setup for all supported databases
- **[Configuration](guides/configuration.md)** - Configure CQL for all environments
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
- **[Soft Deletes](guides/active-record-with-cql/soft-deletes.md)** - Keep deleted records
- **[Integrated Migration Workflow](guides/active-record-with-cql/integrated-migration-workflow.md)** - Streamlined schema management

## 🔧 Advanced Topics

### Alternative Patterns

- **[Repository Pattern](core-concepts/patterns/repository.md)** - Alternative to Active Record
- **[Active Record Pattern](core-concepts/patterns/active-record.md)** - Traditional ORM approach
- **[Entity Framework Pattern](core-concepts/patterns/entity-framework.md)** - .NET-style patterns

### Performance & Scaling

- **[Performance Optimization](guides/performance-optimization.md)** - Make your queries fast
- **[Performance Monitoring Architecture](guides/performance-monitoring-architecture.md)** - Advanced monitoring system design
- **[Performance Tools](guides/performance-tools.md)** - Query analysis, N+1 detection, and profiling

### Database Management

- **[Configuration](guides/configuration.md)** - Configure CQL for all environments
- **[Schema Dumping](guides/schema-dump.md)** - Export your schema
- **[Migration Strategies](guides/handling-migrations.md)** - Deploy schema changes safely
- **[Migration Workflow Enhancements](MIGRATION_WORKFLOW_ENHANCEMENTS.md)** - Enhanced migration features

### Testing & Quality Assurance

- **[Testing Strategies](guides/testing-strategies.md)** - Test your database code

## 🆘 Help & Troubleshooting

### Common Issues

- **[Troubleshooting Guide](troubleshooting.md)** - Solve common problems
- **[FAQ](faqs.md)** - Frequently asked questions

### Getting Help

- **[Community](guides/community.md)** - Connect with other developers

## 📊 Quick Reference

- **[API Reference](guides/api-reference.md)** - Complete API documentation

---

## 🏁 Where to Start?

**New to ORMs?** → Start with [Introduction](introduction.md) → [Installation](installation.md) → [Configuration](guides/configuration.md) → [Getting Started](guides/getting-started.md)

**Experienced with ORMs?** → [Feature Comparison](guides/feature-comparison.md) → [Migration Guide](guides/migration-guide.md) → [Best Practices](guides/best-practices.md)

**Building for Production?** → [Configuration](guides/configuration.md) → [Performance Guide](guides/performance-optimization.md) → [Performance Monitoring](guides/performance-tools.md) → [Security Guide](guides/security-guide.md) → [Testing Strategies](guides/testing-strategies.md)

**Need Specific Feature?** → Use the search function or browse the [Complete Table of Contents](SUMMARY.md)

---

> 💡 **Tip**: All examples in this documentation are tested and verified to work with the latest version of CQL. Every code sample you see here runs successfully in our test suite!

Ready to build something amazing? Let's get started! 🎉
