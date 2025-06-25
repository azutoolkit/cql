require "db"
require "../src/cql"
require "../src/performance"

# Example: Using the LoggerReportGenerator for development debugging
#
# The LoggerReportGenerator provides beautiful, colorful console output
# specifically designed for developers to see performance issues in real-time
# during development and debugging.

class LoggerReportExample
    def self.run
    puts "🚀 CQL Logger Report Generator Example"
    puts "====================================="

    # Enable debug logging to see the logger output
    ::Log.setup(:debug)

    # Create performance monitor with logger report format
    monitor = CQL::Performance::PerformanceMonitor.new

    # Simulate some performance data
    create_sample_performance_data(monitor)

    puts "\n🎯 Generating Logger Report (will appear above this line):"
    puts "─" * 60

    # Generate a beautiful console report
    monitor.generate_comprehensive_report("logger")

    puts "─" * 60
    puts "✅ Logger report generated!"
    puts "\n💡 Pro Tips for Developers:"
    puts "  • Set LOG_LEVEL=debug to enable logger reports"
    puts "  • Use 'logger' format for real-time development debugging"
    puts "  • Integrate with your development workflow for instant feedback"
    puts "  • Colorful output helps identify critical issues quickly"
    puts "  • Performance recommendations guide optimization efforts"
  end

    private def self.create_sample_performance_data(monitor)
    # Simulate some N+1 queries
    10.times do |i|
      monitor.after_query(
        "SELECT * FROM users WHERE id = ?",
        [i.as(DB::Any)],
        2.milliseconds
      )
    end

    # Simulate a slow query
    monitor.after_query(
      "SELECT users.*, profiles.* FROM users LEFT JOIN profiles ON users.id = profiles.user_id WHERE users.created_at > ?",
      [(Time.utc - 1.day).as(DB::Any)],
      150.milliseconds
    )

    # Simulate a very slow query
    monitor.after_query(
      "SELECT COUNT(*) FROM orders o JOIN order_items oi ON o.id = oi.order_id JOIN products p ON oi.product_id = p.id",
      [] of DB::Any,
      500.milliseconds
    )
  end
end

# Example usage in development
puts "\n" + "═" * 80
puts "🔧 CQL Logger Report Generator - Development Example"
puts "═" * 80

LoggerReportExample.run

puts "\n" + "═" * 80
puts "🔧 How to Use in Your Development Workflow:"
puts "═" * 80

puts %Q{
💻 DEVELOPMENT USAGE:

1. **Enable Debug Logging**:
   ```bash
   # Environment variable
   LOG_LEVEL=debug crystal run your_app.cr

   # Or in code
   ::Log.setup(:debug)
   ```

2. **Generate Logger Reports**:
   ```crystal
   # In your application
   monitor = CQL::Performance::PerformanceMonitor.new

   # After running queries...
   monitor.generate_comprehensive_report("logger")
   ```

3. **Integration Examples**:

   **During Testing**:
   ```crystal
   # In your test suite
   describe "Performance Tests" do
     it "should not have N+1 queries" do
       Log.setup(:debug)  # Enable debug logging

       # Your test code here...

       # Generate beautiful report for debugging
       CQL.performance_monitor.generate_comprehensive_report("logger")
     end
   end
   ```

   **Development Middleware**:
   ```crystal
   # In your web framework
   class PerformanceMiddleware
     def call(context)
       if ::Log.level <= ::Log::Severity::Debug
         # Before request
         CQL.performance_monitor.clear_data

         # Handle request
         response = call_next(context)

         # After request - show beautiful performance report
         CQL.performance_monitor.generate_comprehensive_report("logger")

         response
       else
         call_next(context)
       end
     end
   end
   ```

4. **Features**:
   • 🎨 Beautiful colored output with emojis
   • 🔍 Clear issue categorization by severity
   • 💡 Intelligent performance recommendations
   • 📊 Event summaries and statistics
   • ⚡ Only runs when LOG_LEVEL=debug (zero overhead in production)
   • 🎯 Developer-friendly formatting

5. **Output Example**:
   The logger report shows:
   • Overview with metadata
   • Performance issues by severity (🔥 Critical, ⚠️  High, ⚡ Medium, ℹ️  Low)
   • Detailed issue descriptions
   • Smart recommendations based on issue types
   • Event summaries and statistics
   • Celebration when no issues are found! 🎉

💡 Perfect for: Development debugging, CI/CD performance checks,
   code review performance validation, and learning about query optimization!
}

puts "\n" + "═" * 80
