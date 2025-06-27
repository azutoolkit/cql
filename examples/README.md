# CQL Examples

Welcome to the CQL (Crystal Query Language) examples directory! This collection demonstrates the powerful features and capabilities of the CQL ORM framework through practical, real-world examples.

## 📁 Directory Structure

The examples are organized into logical categories for easy navigation:

### 🚀 **[basic/](basic/)**

Simple getting-started examples perfect for newcomers to CQL:

- **simple_cache_demo.cr** - Basic caching operations and features
- **simple_caching_demo.cr** - Fundamental caching concepts
- **simple_redis_demo.cr** - Redis cache integration basics

### 💾 **[caching/](caching/)**

Advanced caching examples showcasing CQL's enterprise-grade caching system:

- **active_record_cache_demo.cr** - ActiveRecord integration with caching
- **activerecord_cache_demo.cr** - Model-level caching demonstrations
- **advanced_caching_example.cr** - Complex caching patterns and strategies
- **cache_configuration_example.cr** - Cache configuration and setup
- **redis_cache_demo.cr** - Redis backend integration
- **per_request_query_cache_demo.cr** - Request-scoped query caching

### ⚙️ **[configuration/](configuration/)**

Configuration examples showing how to set up CQL for different environments:

- **configuration_showcase.cr** - Developer-friendly configuration patterns
- **migrator_config_example.cr** - Migration system configuration

### 🗄️ **[migrations/](migrations/)**

Database migration and schema management examples:

- **schema_migration_workflow.cr** - SQLite migration workflows
- **schema_migration_workflow_pg.cr** - PostgreSQL migration workflows
- **generated_schema.cr** - Auto-generated schema examples

### 📊 **[performance/](performance/)**

Performance monitoring and optimization examples:

- **performance_monitoring_example.cr** - Comprehensive performance analysis
- **logger_report_example.cr** - Development debugging with logger reports

### 🌐 **[framework-integration/](framework-integration/)**

Examples showing CQL integration with popular Crystal web frameworks:

- **azu_query_cache_demo.cr** - Azu framework integration

### 🎯 **[blog/](blog/)**

Comprehensive blog application demonstrating all CQL features:

- Complete MVC structure with models, migrations, and seeders
- Advanced query patterns, relationships, and performance monitoring
- Production-ready example showcasing best practices

### 🛠️ **[utilities/](utilities/)**

Helper modules and utilities used across examples:

- **beautify.cr** - Console output formatting and styling utilities

## 🚀 Getting Started

> **Important:** Always run examples from the **project root directory** (not from within the examples/ directory). The examples use relative paths to find the CQL source files.

### Prerequisites

- Crystal programming language (1.16.3+)
- SQLite3 (for most examples)
- PostgreSQL (for PostgreSQL-specific examples)
- Redis (for Redis caching examples)

### Quick Start

1. **Interactive Runner (Recommended):**

   ```bash
   # Run from the project root directory
   crystal examples/run_examples.cr
   ```

2. **Start with Basic Examples:**

   ```bash
   # Run from the project root directory
   crystal examples/basic/simple_cache_demo.cr
   ```

3. **Try the Blog Application:**

   ```bash
   crystal examples/blog/blog_demo.cr
   ```

4. **Explore Advanced Caching:**

   ```bash
   crystal examples/caching/advanced_caching_example.cr
   ```

5. **Performance Monitoring:**
   ```bash
   crystal examples/performance/performance_monitoring_example.cr
   ```

## 📋 Example Categories by Use Case

### 🎓 **Learning CQL**

Start here if you're new to CQL:

1. `basic/simple_cache_demo.cr` - Core concepts
2. `blog/blog_demo.cr` - Complete application structure
3. `configuration/configuration_showcase.cr` - Setup and configuration

### 🏗️ **Building Applications**

Production-ready patterns and best practices:

1. `blog/` - Full MVC application structure
2. `migrations/schema_migration_workflow.cr` - Database evolution
3. `performance/performance_monitoring_example.cr` - Monitoring and optimization

### ⚡ **Performance Optimization**

Make your application fast and efficient:

1. `caching/advanced_caching_example.cr` - Advanced caching strategies
2. `caching/per_request_query_cache_demo.cr` - Request-scoped caching
3. `performance/performance_monitoring_example.cr` - Performance analysis

### 🔧 **DevOps and Deployment**

Configuration and deployment examples:

1. `configuration/configuration_showcase.cr` - Environment-specific configs
2. `migrations/` - Database migration workflows
3. `framework-integration/` - Web framework integration

## 🎯 Key Features Demonstrated

### Core ORM Features

- ✅ **Type-safe database operations** - Compile-time type checking
- ✅ **ActiveRecord pattern** - Intuitive model definitions and operations
- ✅ **Complex relationships** - belongs_to, has_many, has_one, many_to_many
- ✅ **Advanced queries** - Joins, aggregations, subqueries, raw SQL
- ✅ **Database migrations** - Version-controlled schema evolution
- ✅ **Multiple database support** - SQLite, PostgreSQL, MySQL

### Advanced Features

- 🚀 **Enterprise-grade caching** - Memory, Redis, fragment, tag-based invalidation
- 📊 **Performance monitoring** - Real-time query analysis, N+1 detection
- 🔧 **Developer-friendly configuration** - Environment-based setup
- 🌐 **Web framework integration** - Kemal, Azu, and others
- 💾 **Connection pooling** - Efficient database connection management
- 🔒 **Transaction management** - ACID compliance and rollback safety

## 🛡️ Production Ready

All examples demonstrate production-ready patterns:

- **Error handling** - Comprehensive exception management
- **Performance monitoring** - Built-in query analysis and optimization
- **Security** - SQL injection prevention and safe parameter binding
- **Scalability** - Connection pooling and caching strategies
- **Maintainability** - Clean architecture and separation of concerns

## 📚 Documentation

Each directory contains its own README with detailed explanations and usage instructions. The examples are thoroughly documented with inline comments explaining the concepts and patterns being demonstrated.

## 🤝 Contributing

Found an issue or want to improve an example? Contributions are welcome! Please ensure any new examples follow the established patterns and include comprehensive documentation.

## 🔗 Related Resources

- **[CQL Repository](https://github.com/crystal-lang/cql)** - Main CQL repository
- **[Crystal Language](https://crystal-lang.org/)** - Crystal programming language
- **[CQL Documentation](../docs/)** - Comprehensive CQL documentation

---

**Ready to explore CQL's powerful features?** Start with the [basic examples](basic/) and work your way up to the [complete blog application](blog/)! 🚀
