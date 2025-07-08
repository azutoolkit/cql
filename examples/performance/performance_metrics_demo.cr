# Performance Metrics Demo
# Demonstrates the comprehensive PerformanceMetrics class

require "../../src/performance"

# Configure performance monitoring
CQL::Performance.configure do |config|
  config.monitoring.enabled = true
  config.profiling.enabled = true
  config.detection.enabled = true
  config.logging.enabled = true
  config.logging.colorize = true
end

# Simulate some database queries
puts "🚀 Running performance metrics demo..."

# Track some queries
CQL::Performance.track("SELECT * FROM users WHERE id = ?", [1] of DB::Any) do
  sleep(0.05) # Simulate query execution
end

CQL::Performance.track("SELECT * FROM posts WHERE user_id = ?", [1] of DB::Any) do
  sleep(0.02)
end

# Simulate N+1 pattern
CQL::Performance.start_relation_loading("posts", "User")
10.times do |i|
  CQL::Performance.track("SELECT * FROM posts WHERE user_id = ?", [i] of DB::Any) do
    sleep(0.01)
  end
end
CQL::Performance.end_relation_loading

# Some slow queries
CQL::Performance.track("SELECT * FROM large_table WHERE complex_condition = ?", ["slow"] of DB::Any) do
  sleep(0.2) # Slow query
end

CQL::Performance.track("SELECT * FROM very_large_table WHERE very_complex_condition = ?", ["very_slow"] of DB::Any) do
  sleep(0.5) # Very slow query
end

# Get comprehensive metrics
puts "\n📊 Collecting Performance Metrics..."
metrics = CQL::Performance.metrics

# Display summary
puts "\n📈 PERFORMANCE SUMMARY"
puts "=" * 50
summary = metrics.summary
summary.each do |key, value|
  puts "#{key}: #{value}"
end

# Display detailed metrics
puts "\n🔍 DETAILED METRICS"
puts "=" * 50

# Query metrics
puts "\n📊 Query Metrics:"
query_metrics = metrics.query_metrics
puts "  Total Queries: #{query_metrics.total_queries}"
puts "  Slow Queries: #{query_metrics.slow_queries}"
puts "  Very Slow Queries: #{query_metrics.very_slow_queries}"
puts "  Average Execution Time: #{query_metrics.avg_execution_time.total_milliseconds.round(2)}ms"
puts "  Queries per Second: #{query_metrics.queries_per_second.round(2)}"
puts "  Slow Query Rate: #{query_metrics.slow_query_rate.round(2)}%"

# N+1 metrics
puts "\n🔄 N+1 Detection Metrics:"
n_plus_one_metrics = metrics.n_plus_one_metrics
puts "  Total Patterns: #{n_plus_one_metrics.total_patterns}"
puts "  Critical Patterns: #{n_plus_one_metrics.critical_patterns}"
puts "  High Patterns: #{n_plus_one_metrics.high_patterns}"
puts "  Medium Patterns: #{n_plus_one_metrics.medium_patterns}"
puts "  Low Patterns: #{n_plus_one_metrics.low_patterns}"
puts "  Total Repetitions: #{n_plus_one_metrics.total_repetitions}"
puts "  Average Repetitions per Pattern: #{n_plus_one_metrics.avg_repetitions_per_pattern.round(2)}"

# Health metrics
puts "\n🏥 Health Metrics:"
health_metrics = metrics.health_metrics
puts "  Overall Health Score: #{health_metrics.overall_health_score}/100"
puts "  Query Health Score: #{health_metrics.query_health_score}/100"
puts "  N+1 Health Score: #{health_metrics.n_plus_one_health_score}/100"
puts "  Cache Health Score: #{health_metrics.cache_health_score}/100"
puts "  System Health Score: #{health_metrics.system_health_score}/100"
puts "  Total Issues: #{health_metrics.total_issues}"
puts "  Critical Issues: #{health_metrics.critical_issues}"
puts "  High Issues: #{health_metrics.high_issues}"

# System metrics
puts "\n💻 System Metrics:"
system_metrics = metrics.system_metrics
puts "  Uptime: #{system_metrics.uptime.total_seconds.round(2)}s"
puts "  Memory Usage: #{system_metrics.memory_usage_mb}MB"
puts "  CPU Usage: #{system_metrics.cpu_usage_percent}%"
puts "  Active Connections: #{system_metrics.active_connections}"
puts "  Connection Pool Utilization: #{system_metrics.connection_pool_utilization}%"

# Top queries
puts "\n🏆 Top Queries:"
puts "\nSlowest Queries:"
metrics.slowest_queries(3).each_with_index do |query, i|
  puts "  #{i + 1}. #{query.execution_time.total_milliseconds.round(2)}ms - #{query.sql[0..50]}..."
end

puts "\nMost Frequent Queries:"
metrics.most_frequent_queries(3).each_with_index do |query, i|
  puts "  #{i + 1}. #{query[:count]} times - #{query[:sql][0..50]}..."
end

# Issues
puts "\n⚠️  Performance Issues:"
if metrics.issues.any?
  metrics.issues.each_with_index do |issue, i|
    puts "  #{i + 1}. [#{issue.severity.to_s.upcase}] #{issue.type}: #{issue.message}"
    issue.details.each do |key, value|
      puts "     #{key}: #{value}"
    end
  end
else
  puts "  ✅ No performance issues detected!"
end

# N+1 patterns by severity
puts "\n🔄 N+1 Patterns by Severity:"
[:critical, :high, :medium, :low].each do |severity|
  patterns = metrics.n_plus_one_patterns_by_severity(severity)
  if patterns.any?
    puts "  #{severity.to_s.capitalize}:"
    patterns.each do |pattern|
      puts "    - #{pattern.repetition_count} repetitions: #{pattern.repeated_query[0..50]}..."
    end
  end
end

# Health status
puts "\n🎯 Overall Health Status:"
if metrics.healthy?
  puts "  ✅ Performance is healthy!"
else
  puts "  ❌ Performance issues detected!"
end

# Export to JSON
puts "\n📄 Exporting metrics to JSON..."
json_metrics = metrics.to_json
puts "  JSON size: #{json_metrics.size} characters"
puts "  Sample JSON structure:"
puts json_metrics[0..200] + "..."

puts "\n✨ Performance Metrics Demo Complete!"
