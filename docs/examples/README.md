# CQL Examples

A comprehensive collection of examples demonstrating CQL's features, from basic configuration to advanced performance monitoring and migration workflows.

## 🎯 What You'll Learn

These examples cover the full spectrum of CQL capabilities:

- **Configuration Management** - Centralized database configuration
- **Schema Definition** - Type-safe database schemas
- **Migration Workflows** - Version-controlled schema evolution
- **Active Record Models** - Intuitive ORM patterns
- **Performance Monitoring** - Real-time query analysis
- **CRUD Operations** - Complete database operations
- **Complex Queries** - Advanced query patterns
- **Production Patterns** - Real-world application patterns

## 📚 Example Categories

### 🚀 Getting Started Examples

| Example                                             | Description                                   | Learning Path     |
| --------------------------------------------------- | --------------------------------------------- | ----------------- |
| **[Configuration](configuration-example.md)**       | Database configuration and environment setup  | Basic → Advanced  |
| **[Blog Engine](blog-engine.md)**                   | Complete blog application with all features   | Beginner → Expert |
| **[Generated Schema](generated-schema-example.md)** | Auto-generate schemas from existing databases | Intermediate      |

### 🔄 Migration & Schema Examples

| Example                                                               | Description                            | Learning Path         |
| --------------------------------------------------------------------- | -------------------------------------- | --------------------- |
| **[Migration Configuration](migration-configuration-example.md)**     | Integrated migration workflow setup    | Basic → Advanced      |
| **[Migrator Configuration](migrator-config-example.md)**              | Advanced migrator customization        | Intermediate → Expert |
| **[Schema Migration Workflow](schema-migration-workflow.md)**         | Complete SQLite migration system       | Intermediate          |
| **[PostgreSQL Migration Workflow](postgresql-migration-workflow.md)** | PostgreSQL-specific migration patterns | Advanced              |

### 📊 Performance & Monitoring Examples

| Example                                                         | Description                            | Learning Path         |
| --------------------------------------------------------------- | -------------------------------------- | --------------------- |
| **[Performance Monitoring](performance-monitoring-example.md)** | Comprehensive performance analysis     | Intermediate → Expert |
| **[Logger Report](logger-report-example.md)**                   | Developer-friendly performance reports | Basic → Intermediate  |

## 🎯 Learning Paths

### 🚀 Beginner Path

1. **[Configuration Example](configuration-example.md)** - Start with basic setup
2. **[Blog Engine](blog-engine.md)** - Build a complete application
3. **[Generated Schema](generated-schema-example.md)** - Work with existing databases

### 🔄 Intermediate Path

1. **[Migration Configuration](migration-configuration-example.md)** - Learn migration workflows
2. **[Schema Migration Workflow](schema-migration-workflow.md)** - Master SQLite migrations
3. **[Logger Report](logger-report-example.md)** - Monitor performance during development

### 🏭 Advanced Path

1. **[Migrator Configuration](migrator-config-example.md)** - Customize migration behavior
2. **[PostgreSQL Migration Workflow](postgresql-migration-workflow.md)** - PostgreSQL-specific features
3. **[Performance Monitoring](performance-monitoring-example.md)** - Advanced performance analysis

## 🔧 Quick Start

### Prerequisites

```bash
# Install Crystal
# Install CQL shard
# Set up your preferred database (SQLite, PostgreSQL, MySQL)
```

### Run Examples

```bash
# Configuration example
crystal examples/configure_example.cr

# Blog engine example
crystal examples/blog/blog_demo.cr

# Migration workflow example
crystal examples/schema_migration_workflow.cr

# Performance monitoring example
crystal examples/performance_monitoring_example.cr
```

## 📊 Example Features Matrix

| Feature                    | Config | Blog | Migrations | Performance | Schema Gen |
| -------------------------- | ------ | ---- | ---------- | ----------- | ---------- |
| **Basic Setup**            | ✅     | ✅   | ✅         | ✅          | ✅         |
| **Configuration**          | ✅     | ✅   | ✅         | ✅          | ✅         |
| **Schema Definition**      | ✅     | ✅   | ✅         | ✅          | ✅         |
| **Active Record**          | ✅     | ✅   | ✅         | ✅          | ✅         |
| **Migrations**             | ✅     | ✅   | ✅         | ❌          | ❌         |
| **Performance Monitoring** | ❌     | ❌   | ❌         | ✅          | ❌         |
| **Relationships**          | ✅     | ✅   | ✅         | ✅          | ✅         |
| **Complex Queries**        | ✅     | ✅   | ✅         | ✅          | ✅         |
| **Production Patterns**    | ✅     | ✅   | ✅         | ✅          | ✅         |

## 🎯 Use Cases

### 🏢 Enterprise Applications

- **[Configuration Example](configuration-example.md)** - Multi-environment setup
- **[Migrator Configuration](migrator-config-example.md)** - Complex migration workflows
- **[Performance Monitoring](performance-monitoring-example.md)** - Production monitoring

### 🚀 Rapid Prototyping

- **[Blog Engine](blog-engine.md)** - Complete application template
- **[Generated Schema](generated-schema-example.md)** - Work with existing databases
- **[Logger Report](logger-report-example.md)** - Development-friendly monitoring

### 🔄 Database Evolution

- **[Migration Configuration](migration-configuration-example.md)** - Version-controlled changes
- **[Schema Migration Workflow](schema-migration-workflow.md)** - SQLite migration patterns
- **[PostgreSQL Migration Workflow](postgresql-migration-workflow.md)** - PostgreSQL-specific features

## 📚 Related Documentation

### Core Concepts

- **[Schema Management](../core-concepts/schemas.md)** - Schema definition and management
- **[Migrations](../core-concepts/migrations.md)** - Database migration system
- **[Active Record](../core-concepts/crud-operations.md)** - ORM patterns and operations

### Guides

- **[Getting Started](../guides/getting-started.md)** - First steps with CQL
- **[Configuration](../guides/configuration.md)** - Complete configuration guide
- **[Performance Optimization](../guides/performance-optimization.md)** - Performance best practices

### Advanced Topics

- **[Architecture Overview](../guides/architecture-overview.md)** - System architecture
- **[Best Practices](../guides/best-practices.md)** - Development best practices
- **[Testing Strategies](../guides/testing-strategies.md)** - Testing with CQL

## 🔧 Troubleshooting

### Common Issues

1. **Database Connection** - Check configuration and database setup
2. **Migration Errors** - Verify migration versions and dependencies
3. **Performance Issues** - Use performance monitoring to identify bottlenecks
4. **Schema Conflicts** - Regenerate schemas after database changes

### Getting Help

- Check the **[Troubleshooting Guide](../troubleshooting.md)**
- Review **[FAQs](../faqs.md)** for common questions
- Explore **[Community Resources](../guides/community.md)**

## 🚀 Next Steps

### After Examples

1. **Build Your Application** - Use examples as templates
2. **Customize Configuration** - Adapt to your environment
3. **Implement Monitoring** - Add performance tracking
4. **Deploy to Production** - Follow production guidelines

### Advanced Learning

1. **Explore Source Code** - Study the example implementations
2. **Read Core Documentation** - Deep dive into CQL internals
3. **Join Community** - Connect with other CQL developers
4. **Contribute** - Share your own examples and improvements

---

## 🏁 Summary

These examples provide a comprehensive foundation for learning and using CQL:

- ✅ **Progressive Learning** - From basic setup to advanced features
- ✅ **Real-World Patterns** - Production-ready code and practices
- ✅ **Multiple Databases** - SQLite, PostgreSQL, and MySQL support
- ✅ **Performance Focus** - Built-in monitoring and optimization
- ✅ **Team Collaboration** - Migration workflows and schema management
- ✅ **Production Ready** - Configuration, monitoring, and deployment patterns

Ready to build amazing applications with CQL? Start with the examples and let your imagination guide you! 🚀
