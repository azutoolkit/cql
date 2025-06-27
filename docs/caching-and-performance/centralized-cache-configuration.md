# Centralized Cache Configuration

The CQL library provides a comprehensive, centralized cache configuration system that allows you to configure all caching functionality from one place. This approach follows SOLID principles and provides a clean, maintainable way to manage cache settings across your entire application.

## Overview

Instead of configuring cache settings in multiple places across your application, CQL's centralized configuration allows you to:

- Configure all cache settings in one place
- Apply environment-specific defaults automatically
- Validate configuration at startup
- Access cache functionality through a unified API
- Monitor and manage cache performance centrally

## Basic Configuration

```crystal
require "cql"

CQL.configure do |config|
  config.database_url = "postgresql://localhost/myapp"

  # Enable caching with basic settings
  config.cache.enabled = true
  config.cache.default_ttl = 30.minutes
  config.cache.key_prefix = "myapp"
end
```

## Cache Configuration Options

The cache configuration is accessed through `config.cache` and provides the following options:

### Core Settings

| Setting       | Type         | Default  | Description                               |
| ------------- | ------------ | -------- | ----------------------------------------- |
| `enabled`     | `Bool`       | `false`  | Enable or disable the entire cache system |
| `default_ttl` | `Time::Span` | `1.hour` | Default time-to-live for cache entries    |
| `key_prefix`  | `String`     | `"cql"`  | Prefix for all cache keys                 |
| `cache_name`  | `String`     | `"cql"`  | Name for the cache instance               |

### Memory Cache Settings

| Setting                          | Type     | Default | Description                                   |
| -------------------------------- | -------- | ------- | --------------------------------------------- |
| `enable_memory_cache`            | `Bool`   | `true`  | Enable in-memory caching                      |
| `memory_cache_max_size`          | `Int32?` | `1000`  | Maximum number of entries in memory cache     |
| `memory_cache_enable_statistics` | `Bool`   | `true`  | Enable statistics collection for memory cache |

### Request-Scoped Cache Settings

| Setting                    | Type    | Default | Description                                |
| -------------------------- | ------- | ------- | ------------------------------------------ |
| `enable_request_cache`     | `Bool`  | `true`  | Enable per-request query caching           |
| `request_cache_max_size`   | `Int32` | `1000`  | Maximum entries per request                |
| `auto_clear_request_cache` | `Bool`  | `true`  | Automatically clear cache between requests |

### Fragment Cache Settings

| Setting                            | Type   | Default | Description                       |
| ---------------------------------- | ------ | ------- | --------------------------------- |
| `enable_fragment_cache`            | `Bool` | `false` | Enable fragment caching           |
| `fragment_cache_enable_versioning` | `Bool` | `true`  | Enable version-based invalidation |
| `fragment_cache_enable_tagging`    | `Bool` | `true`  | Enable tag-based invalidation     |

### Invalidation Strategy Settings

| Setting                 | Type         | Default       | Description                                                                         |
| ----------------------- | ------------ | ------------- | ----------------------------------------------------------------------------------- |
| `invalidation_strategy` | `String`     | `"timestamp"` | Strategy for cache invalidation (`"timestamp"`, `"version"`, `"transaction_aware"`) |
| `max_cache_age`         | `Time::Span` | `1.hour`      | Maximum age for timestamp-based invalidation                                        |

### Performance and Monitoring

| Setting                   | Type            | Default | Description                         |
| ------------------------- | --------------- | ------- | ----------------------------------- |
| `enable_cache_statistics` | `Bool`          | `true`  | Enable cache performance statistics |
| `enable_cache_logging`    | `Bool`          | `false` | Enable cache operation logging      |
| `cache_log_level`         | `Log::Severity` | `Debug` | Log level for cache operations      |

### Advanced Settings

| Setting                   | Type         | Default     | Description                            |
| ------------------------- | ------------ | ----------- | -------------------------------------- |
| `auto_cleanup_expired`    | `Bool`       | `true`      | Automatically clean up expired entries |
| `cleanup_interval`        | `Time::Span` | `5.minutes` | Interval for cleanup operations        |
| `enable_batch_operations` | `Bool`       | `true`      | Enable batch cache operations          |

### Middleware Integration

| Setting                         | Type     | Default          | Description                             |
| ------------------------------- | -------- | ---------------- | --------------------------------------- |
| `enable_middleware_integration` | `Bool`   | `false`          | Enable automatic middleware integration |
| `middleware_request_id_header`  | `String` | `"X-Request-ID"` | Header name for request ID tracking     |

## Environment-Specific Defaults

The cache configuration automatically applies environment-specific defaults:

### Development Environment

- `enabled = true`
- `enable_cache_logging = true`
- `cache_log_level = Debug`
- `memory_cache_max_size = 1000`
- `request_cache_max_size = 1000`

### Test Environment

- `enabled = false` (disabled by default for test isolation)
- `enable_cache_logging = false`
- `memory_cache_max_size = 100`
- `request_cache_max_size = 100`

### Production Environment

- `enabled = false` (disabled by default for safety)
- `enable_cache_logging = false`
- `cache_log_level = Info`
- `memory_cache_max_size = 5000`
- `request_cache_max_size = 2000`

## Comprehensive Configuration Example

```crystal
CQL.configure do |config|
  config.database_url = "postgresql://localhost/myapp"

  # Core cache settings
  config.cache.enabled = true
  config.cache.default_ttl = 45.minutes
  config.cache.key_prefix = "myapp"

  # Memory cache configuration
  config.cache.enable_memory_cache = true
  config.cache.memory_cache_max_size = 2000
  config.cache.memory_cache_enable_statistics = true

  # Request-scoped caching
  config.cache.enable_request_cache = true
  config.cache.request_cache_max_size = 1000
  config.cache.auto_clear_request_cache = true

  # Fragment caching
  config.cache.enable_fragment_cache = true
  config.cache.fragment_cache_enable_versioning = true
  config.cache.fragment_cache_enable_tagging = true

  # Invalidation strategy
  config.cache.invalidation_strategy = "transaction_aware"
  config.cache.max_cache_age = 2.hours

  # Performance monitoring
  config.cache.enable_cache_statistics = true
  config.cache.enable_cache_logging = true
  config.cache.cache_log_level = Log::Severity::Info

  # Advanced features
  config.cache.auto_cleanup_expired = true
  config.cache.cleanup_interval = 10.minutes
  config.cache.enable_batch_operations = true

  # Web framework integration
  config.cache.enable_middleware_integration = true
  config.cache.middleware_request_id_header = "X-Request-ID"
end
```

## Cache Management API

Once configured, you can manage the cache system through the CQL module:

### Enable/Disable Cache

```crystal
# Enable caching
CQL.enable_cache(true)

# Check if caching is enabled
if CQL.cache_enabled?
  puts "Cache is enabled"
end

# Disable caching
CQL.enable_cache(false)
```

### Statistics and Monitoring

```crystal
# Get cache statistics
stats = CQL.cache_stats
puts "Hit rate: #{stats["hit_rate_percent"]}%"

# Get performance summary
puts CQL.cache_performance

# Reset statistics
CQL.reset_cache_stats
```

### Request-Scoped Caching

```crystal
# Manual request cache management
CQL.start_request_cache("request-123")
# ... perform database operations
CQL.end_request_cache

# Or use block syntax
CQL.with_request_cache("request-123") do
  # ... perform database operations
  # Cache is automatically cleared when block exits
end
```

### Create Cache Instances

```crystal
# Create a memory cache instance
memory_cache = CQL.create_memory_cache

# Create a fragment cache instance
fragment_cache = CQL.create_fragment_cache
```

## Web Framework Integration

The centralized configuration works seamlessly with web framework middleware:

### Kemal

```crystal
require "cql/cache/middleware"

CQL.configure do |config|
  config.cache.enabled = true
  config.cache.enable_middleware_integration = true
end

before_all do |env|
  CQL::Cache::Middleware::Kemal.before_request(env)
end

after_all do |env|
  CQL::Cache::Middleware::Kemal.after_request(env)
end
```

### Lucky

```crystal
abstract class ApplicationAction < Lucky::Action
  include CQL::Cache::Middleware::Lucky
end
```

## Configuration Validation

The configuration system includes comprehensive validation:

```crystal
begin
  CQL.configure do |config|
    config.cache.enabled = true
    config.cache.memory_cache_max_size = -1  # Invalid!
  end
rescue ArgumentError => e
  puts "Invalid configuration: #{e.message}"
end
```

## Best Practices

1. **Environment-Specific Configuration**: Override defaults for production environments
2. **Memory Limits**: Set appropriate `memory_cache_max_size` based on available memory
3. **TTL Settings**: Configure `default_ttl` based on your data freshness requirements
4. **Request Caching**: Enable for web applications to eliminate duplicate queries
5. **Fragment Caching**: Use for expensive computations or complex query results
6. **Monitoring**: Enable statistics in development but consider disabling logging in production
7. **Invalidation Strategy**: Choose the strategy that best fits your data consistency needs

## Production Configuration Example

```crystal
CQL.configure do |config|
  config.database_url = ENV["DATABASE_URL"]
  config.environment = "production"

  # Production cache settings
  config.cache.enabled = true
  config.cache.default_ttl = 1.hour
  config.cache.memory_cache_max_size = 10000
  config.cache.enable_request_cache = true
  config.cache.invalidation_strategy = "version"
  config.cache.enable_cache_logging = false
  config.cache.enable_cache_statistics = true
  config.cache.enable_middleware_integration = true
end
```

This centralized approach provides a clean, maintainable way to configure all caching functionality while ensuring optimal performance and proper resource management across different environments.
