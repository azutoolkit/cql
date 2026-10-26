# Performance Monitoring

Log the blog engine's queries, find and fix an N+1 query, guard query counts in a spec, and turn on CQL's profiler.

**You need:** the blog engine from all five parts of [Building a Blog](../building-a-blog/01-project-setup.md), or any app with `User` and `Post` models.

## Step 1: Log every query

CQL publishes every statement it runs, DDL included, to `CQL::Telemetry` as a `QueryEvent`:

```crystal
# src/perf.cr
require "./blog_engine"
require "./seeders"

Seeders.run # the same sample data on every run

Log.setup do |c|
  c.bind("cql.*", :debug, Log::IOBackend.new) # send CQL's query log to STDOUT
end
CQL::Telemetry.log_queries # one line per statement, at debug level
Post.where(published: true).count
CQL::Telemetry.unsubscribe("cql.log") # log_queries subscribes under this name
```

```bash
crystal src/perf.cr
```

```text
...
2026-10-26T02:30:12.700075Z  DEBUG - cql.telemetry: [select] 0.08ms SELECT COUNT(*) FROM posts WHERE posts.published = ? (1 params)
```

Bound values stay out of the line, and out of events unless `CQL::Telemetry.capture_params = true`. Transactions publish `TransactionEvent`s to `subscribe_transactions` instead (see [Telemetry](../../how-to/observability/telemetry.md#transactions)).

## Step 2: Collect queries in a monitor

```crystal
# src/monitoring/query_monitor.cr
# Keeps every statement CQL runs, to count queries and spot slow or repeated ones
module QueryMonitor
  record QueryRecord, sql : String, duration_ms : Float64, source : String do
    def slow?(threshold_ms = 100.0) : Bool
      duration_ms > threshold_ms
    end
  end

  @@queries = [] of QueryRecord

  def self.install : Nil
    CQL::Telemetry.subscribe("query_monitor") do |event|
      @@queries << QueryRecord.new(event.sql, event.duration.total_milliseconds, event.context || "")
    end
  end

  def self.queries : Array(QueryRecord)
    @@queries
  end

  def self.clear : Nil
    @@queries.clear
  end

  def self.slow_queries(threshold_ms = 100.0) : Array(QueryRecord)
    @@queries.select(&.slow?(threshold_ms))
  end

  def self.total_time_ms : Float64
    @@queries.sum(&.duration_ms)
  end

  # SQL text that repeats is a sign of N+1: CQL binds values, so the SQL is identical
  def self.repeated(min_count = 2) : Hash(String, Int32)
    @@queries.group_by(&.sql).transform_values(&.size).select { |_, count| count >= min_count }
  end

  def self.report : Nil
    puts "Queries: #{@@queries.size} in #{total_time_ms.round(2)}ms"
    slow_queries.each { |q| puts "  slow #{q.duration_ms.round(2)}ms: #{q.sql[0, 80]}" }
    repeated.each { |sql, count| puts "  #{count}x #{sql[0, 80]}" }
  end
end
```

## Step 3: Tag queries with their source

`with_context` tags the statements its block runs and returns the block's value; `alert_on_slow` reports slow statements. Add to `src/perf.cr`, with `require "./monitoring/query_monitor"` at its top:

```crystal
QueryMonitor.install

posts = CQL::Telemetry.with_context("load_posts") do
  Post.where(published: true).all
end
puts "Loaded #{posts.size} posts; source: #{QueryMonitor.queries.last.source}"

CQL::Telemetry.alert_on_slow(100.milliseconds) do |event|
  Log.warn { "Slow query (#{event.duration.total_milliseconds.round(2)}ms): #{event.sql}" }
end
```

```text
...
Loaded 9 posts; source: load_posts
```

## Step 4: Find an N+1 query and fix it

Add to `src/perf.cr`:

```crystal
# ❌ One query for the posts, then one per post for its author
QueryMonitor.clear
Post.where(published: true).all.each { |post| post.user.try(&.username) }
QueryMonitor.report

# ✅ preload: one more query, SELECT ... FROM users WHERE users.id IN (?, ?, ...)
QueryMonitor.clear
Post.where(published: true).preload(:user).all.each { |post| post.user.try(&.username) }
QueryMonitor.report

# ✅ has_many and has_one preload the same way
QueryMonitor.clear
User.where(active: true).preload(:posts).all.each { |user| puts "#{user.username}: #{user.posts.size} posts" }
QueryMonitor.report
```

```text
...
Queries: 10 in 0.17ms
  9x SELECT users.id, users.username, users.email, users.first_name, users.last_name,
Queries: 2 in 0.14ms
alice: 2 posts
bob: 4 posts
charlie: 4 posts
Queries: 2 in 0.17ms
```

Your timings will differ.

## Step 5: Print a dashboard

```crystal
# src/monitoring/dashboard.cr
require "./query_monitor"

module PerformanceDashboard
  def self.display(slow_ms = 50.0, repeat_limit = 3) : Nil
    queries = QueryMonitor.queries
    return puts "No queries recorded" if queries.empty?

    total = QueryMonitor.total_time_ms
    puts "Queries: #{queries.size} | total #{total.round(2)}ms | average #{(total / queries.size).round(3)}ms"

    QueryMonitor.slow_queries(slow_ms).sort_by(&.duration_ms).reverse.first(5).each do |q|
      puts "Slow (#{q.duration_ms.round(2)}ms): #{q.sql[0, 70]}"
    end

    QueryMonitor.repeated(repeat_limit).each do |sql, count|
      puts "Possible N+1 (#{count}x): #{sql[0, 70]}"
      puts "  -> preload the association, or join it"
    end
  end
end
```

Add to `src/perf.cr`, with `require "./monitoring/dashboard"` at its top:

```crystal
QueryMonitor.clear
Post.where(published: true).all.each { |post| post.user.try(&.username) }
PerformanceDashboard.display
```

```text
...
Queries: 10 | total 0.32ms | average 0.032ms
Possible N+1 (9x): SELECT users.id, users.username, users.email, users.first_name, users.
  -> preload the association, or join it
```

## Step 6: Guard query counts in a spec

```crystal
# spec/performance_spec.cr
require "spec"
require "../src/blog_engine"
require "../src/seeders"
require "../src/monitoring/query_monitor"

Seeders.run
QueryMonitor.install

describe "Post list" do
  before_each { QueryMonitor.clear }

  it "loads posts and their authors in two queries" do
    posts = Post.where(published: true).preload(:user).all
    posts.each(&.user)

    QueryMonitor.queries.size.should eq(2)
    QueryMonitor.slow_queries(100.0).should be_empty
  end
end
```

```bash
crystal spec spec/performance_spec.cr
```

```text
...
1 examples, 0 failures, 0 errors, 0 pending
```

Remove `preload(:user)` and the spec fails with 10 queries.

## Step 7: Turn on CQL's profiler

`CQL::Performance` is off by default in every environment. Enabled, it profiles queries, detects N+1 patterns and builds reports. Add to `src/perf.cr`:

```crystal
CQL::Performance.configure do |config|
  config.monitoring.enabled = true
  config.profiling.slow_query_threshold = 50.milliseconds
  config.detection.threshold = 3 # repeats of one query before it counts as N+1
end

Post.where(published: true).all.each { |post| post.user.try(&.username) }

puts CQL::Performance.report("console") # also "text", "json" and "html"
pp CQL::Performance.metrics_summary
Log.warn { "Performance issues found" } unless CQL::Performance.healthy?
```

```text
...
     Message: N+1 pattern detected: Query repeated 9 times
...
 "n_plus_one_patterns" => 1,
...
```

To forward timings to a metrics system, subscribe to the events; for tracing, assign a `CQL::Telemetry::Tracer` subclass to `CQL::Telemetry.tracer`:

```crystal
CQL::Telemetry.subscribe("metrics") do |event|
  # MetricsClient.timing("cql.query.duration", event.duration.total_milliseconds,
  #   tags: ["operation:#{event.operation}", "ok:#{event.success?}"])
end
```

## What to fix first

```crystal
# Index the columns you filter on: Part 2 indexed posts.published for this query
Post.where(published: true).all

# Load only the columns you need: Array(Post::Row), with the other fields nil
titles = Post.where(published: true).select(:id, :title).to_a

# Walk large tables in batches instead of loading every row
Post.find_each(batch_size: 100) { |post| puts post.title }
```

## Next steps

- [Optimizing Queries in CQL](../../how-to/performance/optimize-queries.md)
- [Avoid N+1 Queries](../../how-to/performance/n-plus-one.md)
- [Profile Queries and Detect N+1](../../how-to/observability/query-profiler.md)
- [Enable Query Caching](../../how-to/caching/query-cache.md)
