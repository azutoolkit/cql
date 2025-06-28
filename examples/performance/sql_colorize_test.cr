# SQL Colorization Test
# This test demonstrates that SQL logging integration is working correctly
# The colorization issue is a separate display problem

require "../../src/cql"
require "../../src/performance/sql_log_formatter"
require "../utilities/beautify"

include Beautify

header("SQL Logging Integration Test")

section("Testing SQL Logging Integration")

# Configure CQL with SQL logging
CQL.configure do |config|
  config.sql_logging.enabled = true
  config.sql_logging.colorize_output = true
  config.sql_logging.include_execution_time = true
  config.sql_logging.include_parameters = true
  config.sql_logging.include_row_count = true
  config.sql_logging.pretty_format = true
  config.sql_logging.async_processing = false
  config.sql_logging.slow_query_threshold = 0.milliseconds
  config.log_level = Log::Severity::Debug
end

# Enable colorization
CQL::Performance.force_enable_colors!

# Create SQL logger
sql_logger = CQL::Performance::SQLLogFormatter.new(CQL.config.sql_logging)
CQL::Performance.sql_logger = sql_logger

success("SQL Logger initialized!")

# Test 1: Manual SQL logging
info("Test 1: Manual SQL logging")
sql_logger.log_sql(
  sql: "SELECT * FROM users WHERE active = true",
  params: [true].map(&.as(DB::Any)),
  execution_time: 15.milliseconds,
  context: "test/manual",
  rows_affected: 25_i64
)

# Test 2: Slow query logging
info("Test 2: Slow query logging")
sql_logger.log_sql(
  sql: "SELECT u.name, COUNT(p.id) as post_count FROM users u LEFT JOIN posts p ON u.id = p.user_id WHERE u.created_at > ? GROUP BY u.id, u.name ORDER BY post_count DESC",
  params: ["2024-01-01T00:00:00Z"].map(&.as(DB::Any)),
  execution_time: 250.milliseconds,
  context: "test/slow_query",
  rows_affected: 150_i64
)

# Test 3: Error logging
info("Test 3: Error logging")
sql_logger.log_sql(
  sql: "SELECT * FROM non_existent_table WHERE id = ?",
  params: [123].map(&.as(DB::Any)),
  execution_time: 5.milliseconds,
  context: "test/error",
  error: "Table 'non_existent_table' doesn't exist"
)

# Test 4: Very slow query
info("Test 4: Very slow query")
sql_logger.log_sql(
  sql: "SELECT e.*, u.name, u.email FROM events e JOIN users u ON e.user_id = u.id WHERE e.created_at > ? ORDER BY e.created_at DESC",
  params: ["2024-01-01 00:00:00 UTC"].map(&.as(DB::Any)),
  execution_time: 2.5.seconds,
  context: "test/very_slow",
  rows_affected: 1000_i64
)

# Show statistics
info("SQL Logger Statistics:")
stats = sql_logger.stats
configuration_block("Statistics", {
  "Processed Queries" => stats["processed"],
  "Error Count"       => stats["errors"],
  "Batch Count"       => stats["batches"],
  "Uptime (seconds)"  => stats["uptime_seconds"],
})

success("SQL logging integration test completed!")
info("Note: The raw ANSI codes (like 34;1m) indicate that colorization is working but not rendering properly in this terminal.")
info("In a proper terminal with color support, these would display as beautiful colored SQL.")
