require "sqlite3"
require "../../src/cql"
require "../../src/cache/cache"
require "../../src/cache/memory_cache"
require "../../src/cache/cache_store"
require "../utilities/beautify"

include Beautify

# Database schema for examples
WithCacheExampleDB = CQL::Schema.define(
  :with_cache_example,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://examples/with_cache_example.db") do
  table :products do
    primary :id, Int32
    text :name
    text :description
    real :price
    integer :stock_quantity
    text :category
    timestamps
  end

  table :orders do
    primary :id, Int32
    text :customer_name
    text :customer_email
    real :total_amount
    text :status
    timestamps
  end
end

# Product model
class Product
  include CQL::ActiveRecord::Model(Int32)
  include JSON::Serializable

  db_context WithCacheExampleDB, :products

  property id : Int32?
  property name : String
  property description : String
  property price : Float64
  property stock_quantity : Int32
  property category : String
  property created_at : Time?
  property updated_at : Time?

  def initialize(@name : String, @description : String, @price : Float64, @stock_quantity : Int32, @category : String)
  end
end

# Order model
class Order
  include CQL::ActiveRecord::Model(Int32)
  include JSON::Serializable

  db_context WithCacheExampleDB, :orders

  property id : Int32?
  property customer_name : String
  property customer_email : String
  property total_amount : Float64
  property status : String
  property created_at : Time?
  property updated_at : Time?

  def initialize(@customer_name : String, @customer_email : String, @total_amount : Float64, @status : String = "pending")
  end
end

# Example demonstrating with_cache method usage
class WithCacheDemo
  def self.run
    # Initialize database
    WithCacheExampleDB.build

    # Set up caching
    setup_caching

    # Seed some data
    seed_data

    header("CQL with_cache Method Demo")

    # Demo 1: Basic with_cache usage
    demo_basic_with_cache

    # Demo 2: Caching with custom TTL
    demo_custom_ttl

    # Demo 3: Caching complex objects
    demo_complex_objects

    # Demo 4: Caching expensive computations
    demo_expensive_computations

    # Demo 5: Cache key generation strategies
    demo_cache_key_strategies

    # Demo 6: Cache statistics and monitoring
    demo_cache_statistics

    # Demo 7: Cache invalidation patterns
    demo_cache_invalidation

    # Demo 8: Performance comparison
    demo_performance_comparison

    demo_complete("with_cache Method Demo")
  end

  private def self.setup_caching
    section("Setting up Caching System")

    # Configure memory cache
    config = CQL::Cache::CacheStoreConfig.new(
      type: :memory,
      max_size: 1000,
      default_ttl: 30.minutes
    )
    CQL::Cache::Cache.configure(config)

    success("Caching system configured")
    configuration_block("Cache Configuration", {
      "Cache Type"  => "Memory",
      "Max Size"    => "1000 entries",
      "Default TTL" => "30 minutes",
      "Cache Name"  => CQL::Cache::Cache.cache_name,
    })
  end

  private def self.seed_data
    section("Seeding Test Data")

    # Create some products
    products = [
      Product.new("Laptop", "High-performance laptop", 999.99, 50, "Electronics"),
      Product.new("Mouse", "Wireless mouse", 29.99, 100, "Electronics"),
      Product.new("Keyboard", "Mechanical keyboard", 89.99, 75, "Electronics"),
      Product.new("Book", "Programming guide", 49.99, 200, "Books"),
      Product.new("Desk", "Office desk", 199.99, 25, "Furniture"),
    ]

    products.each(&.save!)

    # Create some orders
    orders = [
      Order.new("John Doe", "john@example.com", 1029.98),
      Order.new("Jane Smith", "jane@example.com", 139.98),
      Order.new("Bob Johnson", "bob@example.com", 249.98),
    ]

    orders.each(&.save!)

    success("Test data seeded")
    info("Created #{products.size} products and #{orders.size} orders")
  end

  private def self.demo_basic_with_cache
    step(1, "Basic with_cache Usage")

    # Example 1: Caching simple string data
    cache_key = "demo:basic:string"
    result = CQL::Cache::Cache.with_cache(cache_key, 5.minutes) do
      "Hello from cache! Generated at #{Time.utc}"
    end
    database_operation("Cached string result", result.to_s)

    # Example 2: Caching numeric data
    cache_key = "demo:basic:number"
    result = CQL::Cache::Cache.with_cache(cache_key, 5.minutes) do
      Random.new.rand(1000)
    end
    database_operation("Cached number result", result.to_s)

    # Example 3: Caching array data
    cache_key = "demo:basic:array"
    result = CQL::Cache::Cache.with_cache(cache_key, 5.minutes) do
      ["apple", "banana", "cherry", "date"]
    end
    database_operation("Cached array result", result.to_s)

    # Example 4: Caching hash data
    cache_key = "demo:basic:hash"
    result = CQL::Cache::Cache.with_cache(cache_key, 5.minutes) do
      {
        "name"   => "John Doe",
        "age"    => 30,
        "city"   => "New York",
        "active" => true,
      }
    end
    database_operation("Cached hash result", result.to_s)
  end

  private def self.demo_custom_ttl
    step(2, "Custom TTL Settings")

    # Example 1: Short TTL for frequently changing data
    cache_key = "demo:ttl:short"
    result1 = CQL::Cache::Cache.with_cache(cache_key, 2.seconds) do
      "Short-lived cache: #{Time.utc}"
    end
    database_operation("Short TTL result", result1.to_s)

    # Example 2: Long TTL for stable data
    cache_key = "demo:ttl:long"
    result2 = CQL::Cache::Cache.with_cache(cache_key, 1.hour) do
      "Long-lived cache: #{Time.utc}"
    end
    database_operation("Long TTL result", result2.to_s)

    # Example 3: Using default TTL
    cache_key = "demo:ttl:default"
    result3 = CQL::Cache::Cache.with_cache(cache_key) do
      "Default TTL cache: #{Time.utc}"
    end
    database_operation("Default TTL result", result3.to_s)

    # Test short TTL expiration
    info("Waiting 3 seconds for short TTL to expire...")
    sleep(3.seconds)

    # Try to get the short TTL cache again
    result4 = CQL::Cache::Cache.with_cache(cache_key, 2.seconds) do
      "Short-lived cache (regenerated): #{Time.utc}"
    end
    database_operation("After expiration", result4.to_s)
  end

  private def self.demo_complex_objects
    step(3, "Caching Complex Objects")

    # Example 1: Caching database query results
    cache_key = "demo:complex:products"
    products = CQL::Cache::Cache.with_cache(cache_key, 10.minutes) do
      Product.all
    end
    database_operation("Cached products count", products.size.to_s)

    # Example 2: Caching aggregated data
    cache_key = "demo:complex:stats"
    stats = CQL::Cache::Cache.with_cache(cache_key, 15.minutes) do
      {
        "total_products"    => Product.count,
        "total_orders"      => Order.count,
        "avg_product_price" => Product.all.map(&.price).sum / Product.count,
        "categories"        => Product.all.map(&.category).uniq,
        "generated_at"      => Time.utc.to_s,
      }
    end
    database_operation("Cached statistics", stats.to_s)

    # Example 3: Caching filtered results
    cache_key = "demo:complex:electronics"
    electronics = CQL::Cache::Cache.with_cache(cache_key, 5.minutes) do
      Product.where(category: "Electronics").all
    end
    database_operation("Cached electronics count", electronics.size.to_s)
  end

  private def self.demo_expensive_computations
    step(4, "Caching Expensive Computations")

    # Example 1: Simulating expensive calculation
    cache_key = "demo:expensive:fibonacci"
    result = CQL::Cache::Cache.with_cache(cache_key, 1.hour) do
      info("Computing expensive Fibonacci calculation...")
      sleep(0.5.seconds) # Simulate expensive operation
      fib(35)
    end
    database_operation("Fibonacci result", result.to_s)

    # Example 2: Caching with different parameters
    cache_key = "demo:expensive:factorial:10"
    result = CQL::Cache::Cache.with_cache(cache_key, 1.hour) do
      info("Computing factorial of 10...")
      sleep(0.3.seconds) # Simulate expensive operation
      factorial(10)
    end
    database_operation("Factorial result", result.to_s)

    # Example 3: Caching database joins
    cache_key = "demo:expensive:join"
    result = CQL::Cache::Cache.with_cache(cache_key, 10.minutes) do
      info("Performing complex database join...")
      sleep(0.2.seconds) # Simulate complex query
      # Simulate complex join result
      {
        "total_revenue"      => Order.all.map(&.total_amount).sum,
        "top_customers"      => Order.all.sort_by(&.total_amount).reverse.first(3).map(&.customer_name),
        "product_categories" => Product.all.map(&.category).tally,
      }
    end
    database_operation("Complex join result", result.to_s)
  end

  private def self.demo_cache_key_strategies
    step(5, "Cache Key Generation Strategies")

    # Example 1: Using SQL and parameters
    sql = "SELECT * FROM products WHERE category = ? AND price > ?"
    params = ["Electronics", 50.0]
    result = CQL::Cache::Cache.with_cache(sql, params, 10.minutes) do
      Product.where {
        products = Product.table_column(:category)
        products.eq("Electronics") & products.gt(50.0)
      }.all
    end
    database_operation("Query result count", result.size.to_s)

    # Example 2: Using hash parameters
    params_hash = {
      "category"  => "Electronics",
      "min_price" => 50.0,
      "limit"     => 10,
    }
    result = CQL::Cache::Cache.with_cache("products_filter", params_hash, 10.minutes) do
      Product.where(category: "Electronics").limit(10).all
    end
    database_operation("Filtered result count", result.size.to_s)

    # Example 3: Using custom cache names
    CQL::Cache::Cache.cache_name = "custom_demo"
    result = CQL::Cache::Cache.with_cache("custom_query", ["test"], 5.minutes) do
      "Custom cache name result"
    end
    database_operation("Custom result", result.to_s)
  end

  private def self.demo_cache_statistics
    step(6, "Cache Statistics and Monitoring")

    # Perform some cache operations to generate statistics
    info("Performing cache operations to generate statistics...")

    5.times do |i|
      CQL::Cache::Cache.with_cache("stats:test:#{i}", 1.minute) do
        sleep(0.1.seconds)
        "Test data #{i}"
      end
    end

    # Get cache statistics
    stats = CQL::Cache::Cache.statistics
    performance_block("Cache Statistics", stats)

    # Get performance summary
    summary = CQL::Cache::Cache.performance_summary
    info("Performance Summary:")
    puts summary

    # Check cache size
    cache_size = CQL::Cache::Cache.size
    database_operation("Current cache size", cache_size.to_s)

    # Check if specific keys exist
    exists = CQL::Cache::Cache.has_key?("stats:test:0")
    database_operation("Key 'stats:test:0' exists", exists.to_s)
  end

  private def self.demo_cache_invalidation
    step(7, "Cache Invalidation Patterns")

    # Example 1: Manual cache clearing
    cache_key = "demo:invalidation:test"
    result1 = CQL::Cache::Cache.with_cache(cache_key, 1.hour) do
      "Original value: #{Time.utc}"
    end
    database_operation("Original cached value", result1.to_s)

    # Clear the cache
    CQL::Cache::Cache.clear
    status_indicator(:success, "Cache cleared")

    # Try to get the same key again
    result2 = CQL::Cache::Cache.with_cache(cache_key, 1.hour) do
      "New value after clear: #{Time.utc}"
    end
    database_operation("Value after cache clear", result2.to_s)

    # Example 2: Disabling cache temporarily
    CQL::Cache::Cache.enabled = false
    result3 = CQL::Cache::Cache.with_cache(cache_key, 1.hour) do
      "Cache disabled: #{Time.utc}"
    end
    database_operation("Cache disabled result", result3.to_s)

    # Re-enable cache
    CQL::Cache::Cache.enabled = true
    status_indicator(:success, "Cache re-enabled")
  end

  private def self.demo_performance_comparison
    step(8, "Performance Comparison")

    # Test without cache
    info("Testing without cache...")
    start_time = Time.monotonic
    5.times do
      sleep(0.1.seconds) # Simulate expensive operation
    end
    without_cache_time = Time.monotonic - start_time

    # Test with cache
    info("Testing with cache...")
    start_time = Time.monotonic
    5.times do |i|
      CQL::Cache::Cache.with_cache("perf:test:#{i}", 1.minute) do
        sleep(0.1.seconds) # Simulate expensive operation
        "Performance test #{i}"
      end
    end
    with_cache_time = Time.monotonic - start_time

    # Test cache hits
    info("Testing cache hits...")
    start_time = Time.monotonic
    5.times do |i|
      CQL::Cache::Cache.with_cache("perf:test:#{i}", 1.minute) do
        "This should not execute"
      end
    end
    cache_hits_time = Time.monotonic - start_time

    performance_block("Performance Comparison", {
      "Without Cache"          => "#{execution_time(without_cache_time)}",
      "With Cache (First Run)" => "#{execution_time(with_cache_time)}",
      "With Cache (Hits)"      => "#{execution_time(cache_hits_time)}",
      "Cache Hit Speedup"      => "#{(without_cache_time.total_seconds / cache_hits_time.total_seconds).round(2)}x faster",
    })
  end

  # Helper methods for expensive computations
  private def self.fib(n : Int32) : Int64
    return n.to_i64 if n <= 1
    fib(n - 1) + fib(n - 2)
  end

  private def self.factorial(n : Int32) : Int64
    return 1_i64 if n <= 1
    n.to_i64 * factorial(n - 1)
  end
end

# Run the demo if this file is executed directly
if __FILE__ == $0
  WithCacheDemo.run
end
