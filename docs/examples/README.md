---
icon: code
---

# Examples & Tutorials

> **Learn by doing** - Complete, working examples to help you master CQL

Welcome to the CQL Examples section! Here you'll find comprehensive, working examples that demonstrate real-world usage of CQL. Each example is tested, documented, and designed to help you understand how to use CQL effectively in your Crystal applications.

## What You'll Find

Our examples are organized by complexity and use case to help you find exactly what you need:

### Getting Started Examples

Perfect for beginners and those new to CQL:

- **[Configuration Example](configuration-example.md)** - Database setup patterns for different environments
- **[Blog Engine](blog-engine.md)** - Complete blog application with Active Record
- **[Generated Schema Example](generated-schema-example.md)** - Working with existing database schemas

### Migration & Schema Examples

Database management and schema evolution:

- **[Migration Configuration](migration-configuration-example.md)** - Setting up migrations for your project
- **[Migrator Configuration](migrator-config-example.md)** - Advanced migration workflows
- **[Schema Migration Workflow](schema-migration-workflow.md)** - End-to-end schema management
- **[PostgreSQL Migration Workflow](postgresql-migration-workflow.md)** - PostgreSQL-specific patterns

### Performance & Monitoring Examples

Optimization and monitoring techniques:

- **[Performance Monitoring](performance-monitoring-example.md)** - Query analysis and optimization
- **[Logger Report](logger-report-example.md)** - Performance reporting and logging

## Learning Paths

### New to CQL? Start Here

1. **[Configuration Example](configuration-example.md)** - Set up your database
2. **[Blog Engine](blog-engine.md)** - Build a complete application
3. **[Generated Schema Example](generated-schema-example.md)** - Work with existing databases

### Working with Migrations?

1. **[Migration Configuration](migration-configuration-example.md)** - Basic migration setup
2. **[Schema Migration Workflow](schema-migration-workflow.md)** - Complete workflow
3. **[PostgreSQL Migration Workflow](postgresql-migration-workflow.md)** - PostgreSQL specifics

### Optimizing Performance?

1. **[Performance Monitoring](performance-monitoring-example.md)** - Monitor your queries
2. **[Logger Report](logger-report-example.md)** - Generate performance reports

## Example Details

### Getting Started Examples

#### [Configuration Example](configuration-example.md)

**Complexity**: Beginner
**Time**: 15 minutes
**What you'll learn**: Database configuration patterns for development, testing, and production environments.

```crystal
# Environment-specific database setup
case ENV["CRYSTAL_ENV"]?
when "production"
  MyDB = CQL::Schema.define(
    :production,
    adapter: CQL::Adapter::Postgres,
    uri: ENV["DATABASE_URL"]
  )
when "test"
  MyDB = CQL::Schema.define(
    :test,
    adapter: CQL::Adapter::SQLite,
    uri: "sqlite3://:memory:"
  )
end
```

#### [Blog Engine](blog-engine.md)

**Complexity**: Intermediate
**Time**: 45 minutes
**What you'll learn**: Complete Active Record application with relationships, validations, and performance monitoring.

```crystal
# Complete blog with users, posts, and comments
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :users

  has_many :posts, foreign_key: :user_id
  has_many :comments, foreign_key: :user_id

  validate :email, presence: true
end
```

#### [Generated Schema Example](generated-schema-example.md)

**Complexity**: Intermediate
**Time**: 30 minutes
**What you'll learn**: Working with existing database schemas and generating CQL models from them.

### Migration & Schema Examples

#### [Migration Configuration](migration-configuration-example.md)

**Complexity**: Beginner
**Time**: 20 minutes
**What you'll learn**: Setting up migrations for your project and managing schema changes.

#### [Schema Migration Workflow](schema-migration-workflow.md)

**Complexity**: Intermediate
**Time**: 35 minutes
**What you'll learn**: Complete workflow for managing schema changes in team environments.

#### [PostgreSQL Migration Workflow](postgresql-migration-workflow.md)

**Complexity**: Intermediate
**Time**: 40 minutes
**What you'll learn**: PostgreSQL-specific migration patterns and optimizations.

### Performance & Monitoring Examples

#### [Performance Monitoring](performance-monitoring-example.md)

**Complexity**: Advanced
**Time**: 50 minutes
**What you'll learn**: Query analysis, N+1 detection, and performance optimization techniques.

```crystal
# Monitor query performance
CQL::Performance::Monitor.start do |monitor|
  users = User.where(active: true).all

  # Generate performance report
  report = monitor.generate_report
  puts report.to_html
end
```

#### [Logger Report](logger-report-example.md)

**Complexity**: Advanced
**Time**: 30 minutes
**What you'll learn**: Generating and customizing performance reports for your application.

## How to Use These Examples

### Choose the Right Example

- **Beginner**: Start with [Configuration Example](configuration-example.md)
- **Intermediate**: Try [Blog Engine](blog-engine.md) or [Schema Migration Workflow](schema-migration-workflow.md)
- **Advanced**: Explore [Performance Monitoring](performance-monitoring-example.md)

### Follow Along

1. **Read the overview** - Understand what the example demonstrates
2. **Set up the environment** - Follow the prerequisites and setup steps
3. **Run the code** - Execute the example and see it in action
4. **Experiment** - Modify the code to explore different scenarios
5. **Apply to your project** - Adapt the patterns to your own application

### Combine with Guides

- Use examples alongside the [Guides](../guides/README.md) for deeper understanding
- Reference [Core Concepts](../core-concepts/README.md) for theoretical background
- Check [Troubleshooting](../troubleshooting.md) if you encounter issues

## What Makes These Examples Special

Each example is designed to be:

- **Complete** - Full working code that you can run immediately
- **Tested** - Verified to work with the latest CQL version
- **Documented** - Clear explanations of what each part does
- **Progressive** - Build complexity gradually
- **Real-world** - Based on actual use cases and patterns

## Related Resources

- **[Guides](../guides/README.md)** - Detailed explanations of CQL features
- **[Core Concepts](../core-concepts/README.md)** - Fundamental concepts and theory
- **[Troubleshooting](../troubleshooting.md)** - Solutions to common problems
- **[Community](../guides/community.md)** - Get help from other developers

---

> Don't just read the examples - run them! The best way to learn CQL is by experimenting with the code and seeing how it behaves.

> If you get stuck with an example, check the [Troubleshooting Guide](../troubleshooting.md) or ask the [Community](../guides/community.md) for help.

Ready to start building? Pick an example that matches your current needs and dive in!
