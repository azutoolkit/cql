# Utilities

This directory contains helper modules and utilities that enhance the examples throughout the CQL examples collection. These modules provide common functionality like formatting, styling, and console output enhancement.

## 📝 Utilities Overview

### 🎨 **beautify.cr**

**Purpose:** Console output formatting and styling utility module
**Features:**

- Beautiful colored console output with ANSI color codes
- Emoji-enhanced status indicators and section headers
- Consistent formatting across all examples
- Progress indicators and performance displays
- Table formatting and data presentation
- Error and success message styling
- Configuration and statistics display helpers

**Usage:** `require "../utilities/beautify"`

## 🎯 Beautify Module Features

### Text Styling

```crystal
include Beautify

puts bold("Important Text")
puts blue("Information")
puts green("Success Message")
puts red("Error Message")
puts yellow("Warning")
puts dim("Secondary Information")
```

### Section Headers and Organization

```crystal
header("Main Application Title")
section("Configuration Setup")
step(1, "Database Migration")
sub_header("Sub-process Details")
```

### Status Indicators

```crystal
success("Operation completed successfully")
info("Processing data...")
warning("Potential issue detected")
error("Failed to connect to database")
performance("Query executed in 45ms")
```

### Data Presentation

```crystal
# Configuration display
configuration_block("Database Settings", {
  "Host" => "localhost",
  "Port" => "5432",
  "Database" => "myapp_production"
})

# Statistics tables
stats({
  "hits" => 150,
  "misses" => 25,
  "hit_rate_percent" => 85.7
})

# Performance comparison
performance_comparison(
  "Without Cache", baseline_time,
  "With Cache", optimized_time
)
```

### Progress and Status

```crystal
# Progress bar
progress_bar(current: 75, total: 100)

# Status indicators
status_indicator(:success, "Migration completed")
status_indicator(:warning, "Cache hit rate below 80%")
status_indicator(:error, "Connection failed")

# File operations
file_operation("Created", "config/database.yml", :created)
file_operation("Updated", "src/models/user.cr", :modified)
```

### Code and SQL Display

```crystal
# Code blocks with syntax highlighting
code_block(crystal_code, "crystal")
sql_snippet("SELECT * FROM users WHERE active = true")
json_snippet({"status" => "success", "count" => 42})
```

### Lists and Tables

```crystal
# Feature lists
feature_list("New Features", [
  "Advanced caching system",
  "Performance monitoring",
  "Request-scoped optimization"
])

# Bullet points
bullet_point("First item")
bullet_point("Nested item", level: 1)

# Numbered lists
numbered_list([
  "Configure database connection",
  "Run migrations",
  "Start application"
])
```

### Specialized Displays

```crystal
# Query results with cache indicators
query_result("User Query", results, cached: true)

# Migration status
migration_status("CreateUsers", 001, :applied)
migration_status("AddIndexes", 002, :pending)

# Database operations
database_operation("INSERT", "3 records inserted")

# Summary boxes
summary_box("Demo Summary", [
  "25 examples demonstrated",
  "100% test coverage",
  "Production ready"
])
```

## 🎨 Color Scheme and Styling

### Color Palette

- **Blue:** Information, headers, structure
- **Green:** Success, completed operations
- **Yellow:** Warnings, pending operations
- **Red:** Errors, failed operations
- **Cyan:** Highlights, special emphasis
- **Magenta:** Performance metrics
- **Dim:** Secondary information, timestamps

### Consistent Visual Language

- **✅ Green checkmarks:** Successful operations
- **❌ Red X marks:** Failed operations
- **⚠️ Yellow warnings:** Attention needed
- **ℹ️ Blue info:** Informational messages
- **🔄 Progress indicators:** Operations in progress
- **📊 Charts and stats:** Data visualization
- **🚀 Performance:** Speed and optimization

## 🛠️ Usage Patterns

### Basic Example Structure

```crystal
require "../utilities/beautify"
include Beautify

header("Example Title")

step(1, "Setup Phase")
info("Initializing components...")
success("Setup completed")

step(2, "Main Operation")
database_operation("Query", "SELECT * FROM users")
performance("Executed in 25ms")

demo_complete("Example Title")
```

### Configuration Display Pattern

```crystal
section("Configuration")
configuration_block("Database", {
  "Adapter" => "PostgreSQL",
  "Host" => "localhost",
  "Pool Size" => "25"
})

status_indicator(:success, "Configuration validated")
```

### Performance Reporting Pattern

```crystal
section("Performance Analysis")

start_time = Time.monotonic
# ... perform operation ...
duration = Time.monotonic - start_time

performance("Operation completed in #{execution_time(duration)}")

stats(cache.performance_stats)
performance_comparison("Before", old_time, "After", new_time)
```

### Error Handling Pattern

```crystal
begin
  # ... risky operation ...
  success("Operation successful")
rescue ex
  error("Operation failed: #{ex.message}")
  warning("Attempting recovery...")
end
```

## 🔧 Customization

The beautify module is designed to be:

- **Extensible** - Easy to add new formatting functions
- **Consistent** - Unified styling across all examples
- **Terminal-Friendly** - Works in various terminal environments
- **Performance-Aware** - Minimal overhead for console output

### Adding New Formatting

```crystal
module Beautify
  def custom_display(title, data)
    puts "\n#{cyan(bold("🔧 #{title}:"))}"
    data.each { |item| puts "  • #{item}" }
  end
end
```

## 📚 Integration with Examples

### Used Throughout CQL Examples

- **Basic Examples:** Simple formatting for learning
- **Advanced Examples:** Rich display for complex operations
- **Performance Examples:** Detailed metrics visualization
- **Configuration Examples:** Clear configuration display
- **Migration Examples:** Step-by-step process visualization

### Consistent Experience

All CQL examples use the beautify module to provide:

- Consistent visual language across all examples
- Professional, easy-to-read console output
- Clear distinction between different types of information
- Enhanced learning experience through visual cues

## 🔗 Related Files

This utility is referenced by examples throughout the collection:

- `../basic/` - Basic console formatting
- `../caching/` - Cache statistics and performance display
- `../performance/` - Detailed performance reporting
- `../blog/` - Application output formatting
- `../migrations/` - Migration progress display

---

**The beautify module makes CQL examples not just functional, but beautiful!** 🎨
