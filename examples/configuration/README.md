# Configuration Examples

This directory contains examples demonstrating CQL's flexible and developer-friendly configuration system. Learn how to set up CQL for different environments, configure databases, caching, and advanced features.

## 📝 Examples Overview

### 🚀 **configuration_showcase.cr**

**Purpose:** Comprehensive demonstration of CQL's new developer-friendly configuration API
**Features:**

- Quick development setup patterns
- Production configuration best practices
- Cache-focused configuration
- Test environment configuration
- Performance monitoring setup
- Before vs After comparison of old vs new syntax
- Environment-specific configurations
- Smart defaults and intuitive property names

**Run:** `crystal configuration_showcase.cr`

### 🗂️ **migrator_config_example.cr**

**Purpose:** Migration system configuration and setup patterns
**Features:**

- Basic migrator configuration with new syntax
- Environment-specific migrator settings
- Advanced configuration options
- Migrator config creation examples
- Auto-sync and schema verification settings
- Migration table customization

**Run:** `crystal migrator_config_example.cr`

## 🚀 Getting Started

### Quick Development Setup

```crystal
CQL.configure do |c|
  c.db = "postgresql://localhost/myapp"
  c.log_level = :debug
  c.auto_sync = true
end
```

### Production Configuration

```crystal
CQL.configure do |c|
  c.env = "production"
  c.db = ENV["DATABASE_URL"]
  c.pool_size = 25
  c.monitor_performance = true
  c.auto_sync = false
  c.verify_schema = true

  # Enable caching for performance
  c.cache.on = true
  c.cache.ttl = 1.hour
  c.cache.memory_size = 5000
end
```

## 🎯 Key Configuration Areas

### Database Configuration

- **Connection strings** - Simple database URL configuration
- **Connection pooling** - Pool size and timeout settings
- **Multi-database support** - SQLite, PostgreSQL, MySQL
- **SSL configuration** - Secure database connections

### Caching Configuration

- **Memory caching** - In-memory cache settings
- **Redis caching** - Redis backend configuration
- **TTL management** - Cache expiration settings
- **Request caching** - Per-request query deduplication

### Migration Configuration

- **Schema file management** - Auto-generated schema files
- **Migration table** - Customizable migration tracking
- **Auto-sync** - Automatic schema synchronization
- **Environment-specific** - Different settings per environment

### Performance Configuration

- **Query monitoring** - Real-time performance tracking
- **N+1 detection** - Automatic N+1 query detection
- **Plan analysis** - Query execution plan analysis
- **Profiling** - Detailed query profiling

## 🌍 Environment-Specific Patterns

### Development

```crystal
CQL.configure do |c|
  c.env = "development"
  c.db = "sqlite3://./db/development.db"
  c.log_level = :debug
  c.auto_sync = true
  c.monitor_performance = true

  c.cache.on = true
  c.cache.ttl = 15.minutes
end
```

### Test

```crystal
CQL.configure do |c|
  c.env = "test"
  c.db = "sqlite3://:memory:"
  c.pool_size = 1
  c.auto_sync = true
  c.log_level = :error

  # Disable cache in tests
  c.cache.on = false
end
```

### Production

```crystal
CQL.configure do |c|
  c.env = "production"
  c.db = ENV["DATABASE_URL"]
  c.pool_size = 25
  c.auto_sync = false
  c.verify_schema = true
  c.monitor_performance = true

  # Production caching
  c.cache.on = true
  c.cache.ttl = 1.hour
  c.cache.memory_size = 10000
  c.cache.redis_url = ENV["REDIS_URL"]
end
```

## 💡 Configuration Best Practices

### Security

- Never hardcode credentials in configuration
- Use environment variables for sensitive data
- Enable SSL for production database connections
- Disable auto-sync in production environments

### Performance

- Configure appropriate connection pool sizes
- Enable caching for production workloads
- Set reasonable TTL values for cached data
- Monitor performance and adjust settings

### Development Workflow

- Use auto-sync for development and test environments
- Enable debug logging during development
- Use in-memory databases for testing
- Configure shorter cache TTLs for development

### Deployment

- Use environment-specific configuration files
- Validate configuration on startup
- Monitor configuration drift in production
- Document configuration requirements

## 🔧 Advanced Configuration

### Custom Database URLs

```crystal
# PostgreSQL with SSL
c.db = "postgresql://user:pass@localhost/myapp?sslmode=require"

# SQLite with custom path
c.db = "sqlite3://./custom/path/database.db"

# MySQL with connection options
c.db = "mysql://user:pass@localhost/myapp?charset=utf8mb4"
```

### Performance Tuning

```crystal
c.pool_size = 25                    # Database connections
c.cache.memory_size = 10000         # Cache entries
c.cache.ttl = 1.hour               # Cache expiration
c.performance.query_timeout = 30.seconds  # Query timeout
```

### Feature Toggles

```crystal
c.monitor_performance = ENV["ENABLE_MONITORING"]? == "true"
c.cache.on = ENV["DISABLE_CACHE"]? != "true"
c.auto_sync = ENV["AUTO_SYNC"]? == "true"
```

## 🛠️ Troubleshooting

### Common Configuration Issues

**Database Connection Errors:**

- Verify database URL format
- Check database server is running
- Validate credentials and permissions

**Cache Configuration Problems:**

- Ensure Redis server is running (for Redis cache)
- Check memory limits for in-memory cache
- Verify TTL values are reasonable

**Migration Issues:**

- Check schema file permissions
- Verify migration table configuration
- Ensure auto-sync settings are appropriate

## 🔗 Related Examples

- **[../basic/](../basic/)** - Basic examples using these configurations
- **[../caching/](../caching/)** - Cache configuration in action
- **[../migrations/](../migrations/)** - Migration configuration examples
- **[../blog/](../blog/)** - Real application configuration

---

**Ready to configure CQL for your application?** Start with the configuration showcase and adapt the patterns to your needs! ⚙️
