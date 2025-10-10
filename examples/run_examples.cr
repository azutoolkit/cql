#!/usr/bin/env crystal

require "colorize"
require "option_parser"

# CQL Examples Runner - Simplified Version
# Interactive script to explore and run CQL examples

class ExampleRunner
  struct Example
    property name : String
    property file : String
    property description : String
    property prerequisites : Array(String)
    property category : String

    def initialize(@name : String, @file : String, @description : String,
                   @prerequisites = [] of String, @category : String = "")
    end
  end

  @examples = [] of Example
  @show_descriptions = true
  @auto_run = false
  @filter_category : String?

  def initialize
    setup_examples
  end

  def setup_examples
    # Basic Examples
    @examples << Example.new(
      "Simple Cache Demo",
      "basic/simple_cache_demo.cr",
      "Comprehensive demonstration of CQL's memory caching features with TTL, tags, and performance monitoring",
      ["Crystal 1.16.3+"],
      "basic"
    )

    @examples << Example.new(
      "Simple Caching Patterns",
      "basic/simple_caching_demo.cr",
      "Core caching concepts with tag-based invalidation and fragment caching",
      ["Crystal 1.16.3+"],
      "basic"
    )

    @examples << Example.new(
      "Redis Cache Basics",
      "basic/simple_redis_demo.cr",
      "Basic Redis cache integration with environment configuration",
      ["Crystal 1.16.3+", "Redis server"],
      "basic"
    )

    # Advanced Caching Examples
    @examples << Example.new(
      "Advanced Caching Patterns",
      "caching/advanced_caching_example.cr",
      "Complex caching strategies with database integration and multiple invalidation patterns",
      ["Crystal 1.16.3+", "SQLite3"],
      "caching"
    )

    @examples << Example.new(
      "ActiveRecord Caching Integration",
      "caching/active_record_cache_demo.cr",
      "Model-level caching with automatic key generation and invalidation",
      ["Crystal 1.16.3+"],
      "caching"
    )

    @examples << Example.new(
      "ActiveRecord Cache Demo",
      "caching/activerecord_cache_demo.cr",
      "Advanced ActiveRecord model caching with comprehensive features",
      ["Crystal 1.16.3+"],
      "caching"
    )

    @examples << Example.new(
      "Redis Cache Integration",
      "caching/redis_cache_demo.cr",
      "Comprehensive Redis backend with batch operations and performance comparison",
      ["Crystal 1.16.3+", "Redis server"],
      "caching"
    )

    @examples << Example.new(
      "Per-Request Query Caching",
      "caching/per_request_query_cache_demo.cr",
      "Request-scoped query deduplication for web applications",
      ["Crystal 1.16.3+", "SQLite3"],
      "caching"
    )

    @examples << Example.new(
      "Cache Configuration",
      "caching/cache_configuration_example.cr",
      "Cache setup and configuration patterns for different environments",
      ["Crystal 1.16.3+"],
      "caching"
    )

    @examples << Example.new(
      "with_cache Method Demo",
      "caching/with_cache_demo.cr",
      "Comprehensive demonstration of the with_cache method with various data types, TTL settings, and performance monitoring",
      ["Crystal 1.16.3+", "SQLite3"],
      "caching"
    )

    # Configuration Examples
    @examples << Example.new(
      "Configuration Showcase",
      "configuration/configuration_showcase.cr",
      "Developer-friendly configuration API with environment-specific setups",
      ["Crystal 1.16.3+"],
      "configuration"
    )

    @examples << Example.new(
      "Migrator Configuration",
      "configuration/migrator_config_example.cr",
      "Migration system configuration and setup patterns",
      ["Crystal 1.16.3+", "SQLite3"],
      "configuration"
    )

    # Migration Examples
    @examples << Example.new(
      "SQLite Migration Workflow",
      "migrations/schema_migration_workflow.cr",
      "Complete migration workflow with auto-synchronization and schema generation",
      ["Crystal 1.16.3+", "SQLite3"],
      "migrations"
    )

    @examples << Example.new(
      "PostgreSQL Migration Workflow",
      "migrations/schema_migration_workflow_pg.cr",
      "PostgreSQL-specific migration patterns with advanced features",
      ["Crystal 1.16.3+", "PostgreSQL server"],
      "migrations"
    )

    # Performance Examples
    @examples << Example.new(
      "Performance Monitoring",
      "performance/performance_monitoring_example.cr",
      "Comprehensive performance analysis with N+1 detection and query profiling",
      ["Crystal 1.16.3+", "SQLite3"],
      "performance"
    )

    @examples << Example.new(
      "Logger Performance Reports",
      "performance/logger_report_example.cr",
      "Development-focused performance debugging with beautiful console output",
      ["Crystal 1.16.3+"],
      "performance"
    )

    @examples << Example.new(
      "Beautiful SQL Log Formatter",
      "performance/sql_log_formatter_example.cr",
      "Beautiful SQL logging with async pipeline, batch processing, and background error reporting",
      ["Crystal 1.16.3+"],
      "performance"
    )

    @examples << Example.new(
      "SQL Log Integration Demo",
      "performance/sql_integration_example.cr",
      "Complete integration guide showing how SQLLogEntry works with query execution through event-driven architecture",
      ["Crystal 1.16.3+", "SQLite3"],
      "performance"
    )

    @examples << Example.new(
      "Simple SQL Log Demo",
      "performance/simple_sql_log_demo.cr",
      "Standalone demo showing beautiful SQL log output with syntax highlighting and performance indicators",
      ["Crystal 1.16.3+"],
      "performance"
    )

    @examples << Example.new(
      "SQL Log Demo",
      "performance/sql_log_demo.cr",
      "Basic SQL log formatter demo with colorized output and formatting examples",
      ["Crystal 1.16.3+"],
      "performance"
    )

    # Framework Integration Examples
    @examples << Example.new(
      "Azu Framework Integration",
      "framework-integration/azu_query_cache_demo.cr",
      "Complete Azu framework integration with multiple patterns and performance benchmarking",
      ["Crystal 1.16.3+", "SQLite3"],
      "framework-integration"
    )

    # Blog Application
    @examples << Example.new(
      "Complete Blog Application",
      "blog/blog_demo.cr",
      "Full-featured blog application demonstrating all CQL features with performance monitoring",
      ["Crystal 1.16.3+", "SQLite3"],
      "blog"
    )
  end

  def run(args = ARGV)
    parse_options(args)

    if @auto_run && @filter_category
      run_category(@filter_category.not_nil!)
      return
    end

    show_header
    show_main_menu
  end

  def parse_options(args)
    OptionParser.parse(args) do |parser|
      parser.banner = "Usage: crystal run_examples.cr [options]"

      parser.on("-c CATEGORY", "--category=CATEGORY", "Run all examples in category") do |category|
        @filter_category = category
        @auto_run = true
      end

      parser.on("-l", "--list", "List all available examples") do
        list_examples
        exit
      end

      parser.on("-h", "--help", "Show this help") do
        puts parser
        exit
      end

      parser.on("--no-descriptions", "Hide example descriptions") do
        @show_descriptions = false
      end
    end
  end

  def show_header
    puts "\n"
    puts "🎯 CQL Examples Runner".colorize(:cyan).bold
    puts "═" * 50
    puts "Interactive exploration of CQL ORM features"
    puts "Choose examples to run and see CQL in action!"
    puts
  end

  def show_main_menu
    loop do
      puts "\n📋 Main Menu".colorize(:blue).bold
      puts "─" * 30
      puts "1️⃣  Basic Examples (Getting Started)"
      puts "2️⃣  Advanced Caching Examples"
      puts "3️⃣  Configuration Examples"
      puts "4️⃣  Migration & Schema Examples"
      puts "5️⃣  Performance Monitoring Examples"
      puts "6️⃣  Framework Integration Examples"
      puts "7️⃣  Complete Blog Application"
      puts "8️⃣  Run All Examples"
      puts "9️⃣  List All Examples"
      puts "0️⃣  Exit"
      puts

      print "Select category (1-9, 0 to exit): ".colorize(:yellow)

      case gets.try(&.strip)
      when "1"
        show_category_menu("basic", "🚀 Basic Examples")
      when "2"
        show_category_menu("caching", "💾 Advanced Caching Examples")
      when "3"
        show_category_menu("configuration", "⚙️ Configuration Examples")
      when "4"
        show_category_menu("migrations", "🗄️ Migration & Schema Examples")
      when "5"
        show_category_menu("performance", "📊 Performance Monitoring Examples")
      when "6"
        show_category_menu("framework-integration", "🌐 Framework Integration Examples")
      when "7"
        show_category_menu("blog", "🎯 Complete Blog Application")
      when "8"
        run_all_examples
      when "9"
        list_examples
      when "0", "exit", "quit"
        puts "\n👋 Thanks for exploring CQL examples!".colorize(:green).bold
        puts "Visit https://github.com/crystal-lang/cql for more information"
        exit
      else
        puts "❌ Invalid selection. Please choose 1-9 or 0 to exit.".colorize(:red)
      end
    end
  end

  def show_category_menu(category : String, title : String)
    examples = @examples.select { |ex| ex.category == category }

    if examples.empty?
      puts "❌ No examples found in category: #{category}".colorize(:red)
      return
    end

    loop do
      puts "\n📂 #{title}"
      puts "─" * (title.size + 2)

      examples.each_with_index do |example, index|
        status = check_prerequisites(example.prerequisites)
        status_icon = status ? "✅" : "⚠️ "

        puts "#{index + 1}️⃣  #{status_icon} #{example.name}"
        if @show_descriptions
          puts "     #{example.description}"
          if example.prerequisites.any?
            puts "     Prerequisites: #{example.prerequisites.join(", ")}".colorize(:yellow)
          end
        end
        puts
      end

      puts "#{examples.size + 1}️⃣  🔄 Run All Examples in Category"
      puts "0️⃣  ← Back to Main Menu"
      puts

      print "Select example (1-#{examples.size + 1}, 0 for main menu): ".colorize(:yellow)

      input = gets.try(&.strip)
      case input
      when "0"
        break
      when (examples.size + 1).to_s
        run_category(category)
      else
        if input && (index = input.to_i?) && index >= 1 && index <= examples.size
          run_example(examples[index - 1])
        else
          puts "❌ Invalid selection. Please choose 1-#{examples.size + 1} or 0 for main menu.".colorize(:red)
        end
      end
    end
  end

  def run_example(example : Example)
    puts "\n🚀 Running: #{example.name}".colorize(:cyan).bold
    puts "─" * (example.name.size + 12)
    puts "📁 File: #{example.file}"
    puts "📝 Description: #{example.description}"

    if !check_prerequisites(example.prerequisites)
      puts "\n⚠️  Prerequisites not met:".colorize(:yellow).bold
      example.prerequisites.each do |prereq|
        puts "   • #{prereq}"
      end
      puts "\nDo you want to continue anyway? (y/N): "
      return unless gets.try(&.strip).try(&.downcase) == "y"
    end

    puts "\n🔄 Executing example...".colorize(:blue).bold
    puts "═" * 50

    start_time = Time.monotonic

    begin
      # Add examples/ prefix to the file path since we're running from project root
      example_path = "examples/#{example.file}"
      result = Process.run("crystal", [example_path], output: STDOUT, error: STDERR)

      execution_time = Time.monotonic - start_time

      if result.success?
        puts "\n" + "═" * 50
        puts "✅ Example completed successfully!".colorize(:green).bold
        puts "⏱️  Execution time: #{execution_time.total_seconds.round(2)}s"
      else
        puts "\n" + "═" * 50
        puts "❌ Example failed with exit code: #{result.exit_code}".colorize(:red).bold
      end
    rescue ex
      execution_time = Time.monotonic - start_time
      puts "\n" + "═" * 50
      puts "❌ Error running example: #{ex.message}".colorize(:red).bold
      puts "⏱️  Execution time: #{execution_time.total_seconds.round(2)}s"
    end

    puts "\nPress Enter to continue..."
    gets
  end

  def run_category(category : String)
    examples = @examples.select { |ex| ex.category == category }

    if examples.empty?
      puts "❌ No examples found in category: #{category}".colorize(:red)
      return
    end

    puts "\n🔄 Running all examples in category: #{category}".colorize(:cyan).bold
    puts "═" * 60

    successful = 0
    failed = 0

    examples.each_with_index do |example, index|
      puts "\n📌 [#{index + 1}/#{examples.size}] #{example.name}".colorize(:blue).bold

      if !check_prerequisites(example.prerequisites, quiet: true)
        puts "⏭️  Skipping due to unmet prerequisites: #{example.prerequisites.join(", ")}".colorize(:yellow)
        next
      end

      start_time = Time.monotonic

      begin
        # Add examples/ prefix to the file path since we're running from project root
        example_path = "examples/#{example.file}"
        result = Process.run("crystal", [example_path], output: Process::Redirect::Close, error: Process::Redirect::Close)
        execution_time = Time.monotonic - start_time

        if result.success?
          puts "✅ Completed in #{execution_time.total_seconds.round(2)}s".colorize(:green)
          successful += 1
        else
          puts "❌ Failed (exit code: #{result.exit_code})".colorize(:red)
          failed += 1
        end
      rescue ex
        execution_time = Time.monotonic - start_time
        puts "❌ Error: #{ex.message}".colorize(:red)
        failed += 1
      end
    end

    puts "\n" + "═" * 60
    puts "📊 Category Summary".colorize(:blue).bold
    puts "✅ Successful: #{successful}".colorize(:green)
    puts "❌ Failed: #{failed}".colorize(:red)
    if (successful + failed) > 0
      success_rate = (successful.to_f / (successful + failed) * 100).round(1)
      puts "📈 Success rate: #{success_rate}%".colorize(:cyan)
    end

    unless @auto_run
      puts "\nPress Enter to continue..."
      gets
    end
  end

  def run_all_examples
    puts "\n🚀 Running ALL CQL Examples".colorize(:cyan).bold
    puts "This will run examples from all categories..."
    puts "⚠️  This may take several minutes to complete."
    puts "\nDo you want to continue? (y/N): "

    return unless gets.try(&.strip).try(&.downcase) == "y"

    categories = @examples.map(&.category).uniq!.sort!

    categories.each do |category|
      puts "\n" + "=" * 60
      puts "📂 Category: #{category.capitalize}".colorize(:magenta).bold
      puts "=" * 60
      run_category(category)
    end

    puts "\n🎉 All examples completed!".colorize(:green).bold
    puts "Press Enter to return to main menu..."
    gets
  end

  def list_examples
    puts "\n📋 All Available CQL Examples".colorize(:cyan).bold
    puts "═" * 50

    categories = @examples.group_by(&.category)

    categories.each do |category, examples|
      puts "\n📂 #{category.capitalize} (#{examples.size} examples)".colorize(:blue).bold
      puts "─" * 40

      examples.each do |example|
        status = check_prerequisites(example.prerequisites, quiet: true) ? "✅" : "⚠️ "
        puts "  #{status} #{example.name}"
        puts "     📁 #{example.file}"
        puts "     📝 #{example.description}"
        if example.prerequisites.any?
          puts "     🔧 Prerequisites: #{example.prerequisites.join(", ")}".colorize(:yellow)
        end
        puts
      end
    end

    total_examples = @examples.size
    ready_examples = @examples.count { |ex| check_prerequisites(ex.prerequisites, quiet: true) }

    puts "📊 Summary".colorize(:blue).bold
    puts "─" * 20
    puts "Total examples: #{total_examples}"
    puts "Ready to run: #{ready_examples}".colorize(:green)
    puts "Need prerequisites: #{total_examples - ready_examples}".colorize(:yellow)
  end

  def check_prerequisites(prerequisites : Array(String), quiet = false) : Bool
    return true if prerequisites.empty?

    all_met = true

    prerequisites.each do |prereq|
      case prereq
      when /Crystal (\d+\.\d+\.\d+)\+/
        required_version = $1
        current_version = Crystal::VERSION
        if compare_versions(current_version, required_version) < 0
          puts "❌ Crystal #{required_version}+ required (current: #{current_version})".colorize(:red) unless quiet
          all_met = false
        end
      when "Redis server"
        unless redis_available?
          puts "❌ Redis server not available".colorize(:red) unless quiet
          all_met = false
        end
      when "PostgreSQL server"
        unless postgres_available?
          puts "❌ PostgreSQL server not available".colorize(:red) unless quiet
          all_met = false
        end
      when "SQLite3"
        unless sqlite_available?
          puts "❌ SQLite3 not available".colorize(:red) unless quiet
          all_met = false
        end
      end
    end

    all_met
  end

  private def compare_versions(current : String, required : String) : Int32
    current_parts = current.split('.').map(&.to_i)
    required_parts = required.split('.').map(&.to_i)

    [current_parts.size, required_parts.size].max.times do |i|
      current_part = current_parts[i]? || 0
      required_part = required_parts[i]? || 0

      if current_part != required_part
        return current_part <=> required_part
      end
    end

    0
  end

  private def redis_available? : Bool
    Process.run("redis-cli", ["ping"], output: Process::Redirect::Close, error: Process::Redirect::Close).success?
  rescue
    false
  end

  private def postgres_available? : Bool
    # Check if pg_isready is available and working
    Process.run("pg_isready", output: Process::Redirect::Close, error: Process::Redirect::Close).success?
  rescue
    # Fallback: try to connect to default database
    begin
      Process.run("psql", ["-c", "SELECT 1;"], output: Process::Redirect::Close, error: Process::Redirect::Close).success?
    rescue
      false
    end
  end

  private def sqlite_available? : Bool
    Process.run("sqlite3", ["--version"], output: Process::Redirect::Close, error: Process::Redirect::Close).success?
  rescue
    false
  end
end

# Main execution
if ARGV.includes?("--help") || ARGV.includes?("-h")
  puts "CQL Examples Runner"
  puts "Usage: crystal run_examples.cr [options]"
  puts ""
  puts "Options:"
  puts "  -c, --category=CATEGORY    Run all examples in category"
  puts "  -l, --list                 List all available examples"
  puts "  -h, --help                 Show this help"
  puts "  --no-descriptions          Hide example descriptions"
  puts ""
  puts "Categories: basic, caching, configuration, migrations, performance, framework-integration, blog"
  puts ""
  puts "Examples:"
  puts "  crystal run_examples.cr                    # Interactive menu"
  puts "  crystal run_examples.cr -c basic          # Run all basic examples"
  puts "  crystal run_examples.cr -l                # List all examples"
  exit
end

runner = ExampleRunner.new
runner.run
