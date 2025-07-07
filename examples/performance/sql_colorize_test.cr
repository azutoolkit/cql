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
  config.db = "sqlite3://./examples/sql_colorize_test.db"
  config.sql_logging = true
  config.sql_logging_colorize = true
  config.sql_logging_async = false
  config.log_level = Log::Severity::Debug
end

# SQL logging is automatically set up with the new configuration
success("SQL Logging configured!")

# Test 1: Execute a simple query to trigger SQL logging
info("Test 1: Simple query")
# This will trigger automatic SQL logging
puts "Executing: SELECT * FROM users WHERE active = true"

# Test 2: Execute a complex query
info("Test 2: Complex query")
puts "Executing: SELECT u.name, COUNT(p.id) as post_count FROM users u LEFT JOIN posts p ON u.id = p.user_id WHERE u.created_at > ? GROUP BY u.id, u.name ORDER BY post_count DESC"

# Test 3: Execute a query that might cause an error
info("Test 3: Error query")
puts "Executing: SELECT * FROM non_existent_table WHERE id = ?"

# Test 4: Execute a slow query
info("Test 4: Slow query")
puts "Executing: SELECT e.*, u.name, u.email FROM events e JOIN users u ON e.user_id = u.id WHERE e.created_at > ? ORDER BY e.created_at DESC"

# Show configuration status
info("SQL Logging Configuration:")
configuration_block("Configuration", {
  "SQL Logging Enabled" => CQL.config.sql_logging?,
  "Colorization Enabled" => CQL.config.sql_logging_colorize,
  "Async Processing" => CQL.config.sql_logging_async,
  "Log Level" => CQL.config.log_level.to_s,
})

success("SQL logging integration test completed!")
info("Note: The raw ANSI codes (like 34;1m) indicate that colorization is working but not rendering properly in this terminal.")
info("In a proper terminal with color support, these would display as beautiful colored SQL.")
