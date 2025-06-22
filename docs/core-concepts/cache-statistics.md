# Cache Statistics

CQL provides comprehensive cache statistics to help you monitor and optimize query performance. The `CQL::CacheStats` class tracks various metrics about your query cache usage, including hit rates, execution times, and overall performance.

---

## Overview

Cache statistics help you understand how effectively your application is using CQL's query cache and identify opportunities for optimization. By monitoring these metrics, you can make informed decisions about cache configuration and query optimization.

---

## Basic Usage

### Creating Cache Statistics

```crystal
require "cql"

# Create a new cache statistics instance
stats = CQL::CacheStats.new

# The stats object starts with zero values
stats.hits.should eq 0_i64
stats.misses.should eq 0_i64
stats.total_requests.should eq 0_i64
```

### Accessing Basic Metrics

```crystal
stats = CQL::CacheStats.new

# Set some example values
stats.hits = 75_i64
stats.misses = 25_i64
stats.total_requests = 100_i64

# Access basic metrics
stats.hits.should eq 75_i64
stats.misses.should eq 25_i64
stats.total_requests.should eq 100_i64
```

---

## Performance Metrics

### Hit Rate

The hit rate represents the percentage of cache requests that were successful (found in cache).

```crystal
stats = CQL::CacheStats.new
stats.hits = 80_i64
stats.total_requests = 100_i64

hit_rate = stats.hit_rate
# Returns: 80.0 (80% hit rate)

# When no requests have been made
stats = CQL::CacheStats.new
stats.hit_rate.should eq 0.0

# When all requests are hits
stats.hits = 10_i64
stats.total_requests = 10_i64
stats.hit_rate.should eq 100.0

# When all requests are misses
stats.misses = 10_i64
stats.total_requests = 10_i64
stats.hit_rate.should eq 0.0
```

### Miss Rate

The miss rate represents the percentage of cache requests that were not found in cache.

```crystal
stats = CQL::CacheStats.new
stats.hits = 30_i64
stats.misses = 70_i64
stats.total_requests = 100_i64

miss_rate = stats.miss_rate
# Returns: 70.0 (70% miss rate)

# Hit rate and miss rate always sum to 100.0
(stats.hit_rate + stats.miss_rate).should be_close(100.0, 0.0001)
```

### Average Cache Time

Track the average time spent retrieving data from cache.

```crystal
stats = CQL::CacheStats.new
stats.total_cache_time = 2.5
stats.total_requests = 5_i64

avg_cache_time = stats.average_cache_time
# Returns: 0.5 (average 0.5 seconds per cache operation)

# When no requests have been made
stats = CQL::CacheStats.new
stats.average_cache_time.should eq 0.0
```

### Average Execution Time

Track the average time spent executing database queries.

```crystal
stats = CQL::CacheStats.new
stats.total_execution_time = 10.0
stats.total_requests = 4_i64

avg_execution_time = stats.average_execution_time
# Returns: 2.5 (average 2.5 seconds per query execution)
```

---

## Uptime Tracking

### Cache Uptime

Track how long the cache has been running.

```crystal
stats = CQL::CacheStats.new

# Get uptime as Time::Span
uptime = stats.uptime
uptime.should be_a(Time::Span)

# Uptime is always positive
stats.uptime.total_seconds.should be >= 0.0

# Uptime increases over time
initial_uptime = stats.uptime.total_seconds
sleep(0.1.seconds)
stats.uptime.total_seconds.should be >= initial_uptime
```

---

## Real-World Examples

### Monitoring Cache Performance

```crystal
class CacheMonitor
  def initialize
    @stats = CQL::CacheStats.new
  end

  def log_performance
    puts "Cache Performance Report:"
    puts "  Hit Rate: #{@stats.hit_rate.round(2)}%"
    puts "  Miss Rate: #{@stats.miss_rate.round(2)}%"
    puts "  Average Cache Time: #{@stats.average_cache_time.round(3)}s"
    puts "  Average Execution Time: #{@stats.average_execution_time.round(3)}s"
    puts "  Uptime: #{@stats.uptime}"
    puts "  Total Requests: #{@stats.total_requests}"
  end

  def should_optimize_cache?
    # Suggest optimization if miss rate is high
    @stats.miss_rate > 50.0
  end

  def cache_efficiency_score
    # Calculate a simple efficiency score
    hit_rate_weight = 0.6
    cache_time_weight = 0.4

    hit_rate_score = @stats.hit_rate / 100.0
    cache_time_score = [1.0, 1.0 / (@stats.average_cache_time + 0.1)].min

    (hit_rate_score * hit_rate_weight) + (cache_time_score * cache_time_weight)
  end
end
```

### Performance Alerting

```crystal
class CacheAlerting
  def initialize(@stats : CQL::CacheStats)
  end

  def check_alerts
    alerts = [] of String

    # Alert on high miss rate
    if @stats.miss_rate > 80.0
      alerts << "High cache miss rate: #{@stats.miss_rate.round(1)}%"
    end

    # Alert on slow cache operations
    if @stats.average_cache_time > 1.0
      alerts << "Slow cache operations: #{@stats.average_cache_time.round(3)}s average"
    end

    # Alert on slow query execution
    if @stats.average_execution_time > 5.0
      alerts << "Slow query execution: #{@stats.average_execution_time.round(3)}s average"
    end

    alerts
  end

  def should_scale_cache?
    # Consider scaling if hit rate is low and requests are high
    @stats.hit_rate < 30.0 && @stats.total_requests > 1000
  end
end
```

### Integration with Application Monitoring

```crystal
class ApplicationMonitor
  def initialize
    @cache_stats = CQL::CacheStats.new
    @start_time = Time.utc
  end

  def record_cache_hit
    @cache_stats.hits += 1
    @cache_stats.total_requests += 1
  end

  def record_cache_miss
    @cache_stats.misses += 1
    @cache_stats.total_requests += 1
  end

  def record_cache_time(duration : Float64)
    @cache_stats.total_cache_time += duration
  end

  def record_execution_time(duration : Float64)
    @cache_stats.total_execution_time += duration
  end

  def generate_report
    {
      cache_performance: {
        hit_rate: @cache_stats.hit_rate,
        miss_rate: @cache_stats.miss_rate,
        average_cache_time: @cache_stats.average_cache_time,
        average_execution_time: @cache_stats.average_execution_time,
        total_requests: @cache_stats.total_requests,
        uptime: @cache_stats.uptime.total_seconds
      },
      application_uptime: Time.utc - @start_time
    }
  end
end
```

---

## Best Practices

### 1. Regular Monitoring

Monitor cache statistics regularly to identify performance trends:

```crystal
# Set up periodic monitoring
def monitor_cache_performance
  stats = CQL::CacheStats.new

  # Log performance every hour
  spawn do
    loop do
      log_performance_metrics(stats)
      sleep(1.hour)
    end
  end
end
```

### 2. Set Performance Thresholds

Define acceptable performance thresholds for your application:

```crystal
class PerformanceThresholds
  MAX_MISS_RATE = 30.0
  MAX_CACHE_TIME = 0.5
  MAX_EXECUTION_TIME = 2.0

  def self.check_thresholds(stats : CQL::CacheStats)
    violations = [] of String

    if stats.miss_rate > MAX_MISS_RATE
      violations << "Miss rate exceeds threshold: #{stats.miss_rate}% > #{MAX_MISS_RATE}%"
    end

    if stats.average_cache_time > MAX_CACHE_TIME
      violations << "Cache time exceeds threshold: #{stats.average_cache_time}s > #{MAX_CACHE_TIME}s"
    end

    if stats.average_execution_time > MAX_EXECUTION_TIME
      violations << "Execution time exceeds threshold: #{stats.average_execution_time}s > #{MAX_EXECUTION_TIME}s"
    end

    violations
  end
end
```

### 3. Cache Optimization

Use statistics to guide cache optimization decisions:

```crystal
def optimize_cache_based_on_stats(stats : CQL::CacheStats)
  if stats.miss_rate > 50.0
    # Consider increasing cache size or TTL
    increase_cache_capacity
  end

  if stats.average_cache_time > 1.0
    # Consider optimizing cache storage or retrieval
    optimize_cache_storage
  end

  if stats.average_execution_time > 5.0
    # Consider query optimization or database tuning
    optimize_database_queries
  end
end
```

---

## Integration with CQL Query Cache

Cache statistics work seamlessly with CQL's query cache system:

```crystal
# Enable query cache with statistics
CQL::QueryCache.enabled = true
CQL::QueryCache.default_ttl = 1.hour

# Create cache statistics
stats = CQL::CacheStats.new

# Execute queries (cache statistics are automatically updated)
users = User.where(active: true).all

# Monitor performance
puts "Cache hit rate: #{stats.hit_rate}%"
puts "Average execution time: #{stats.average_execution_time}s"
```

---

Cache statistics provide valuable insights into your application's database performance. By monitoring these metrics and setting up appropriate alerts, you can ensure optimal performance and quickly identify and resolve performance issues.
