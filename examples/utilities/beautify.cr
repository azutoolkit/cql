module Beautify
  def bold(text)
    "\033[1m#{text}\033[0m"
  end

  def blue(text)
    "\033[34m#{text}\033[0m"
  end

  def green(text)
    "\033[32m#{text}\033[0m"
  end

  def yellow(text)
    "\033[33m#{text}\033[0m"
  end

  def cyan(text)
    "\033[36m#{text}\033[0m"
  end

  def magenta(text)
    "\033[35m#{text}\033[0m"
  end

  def red(text)
    "\033[31m#{text}\033[0m"
  end

  def dim(text)
    "\033[2m#{text}\033[0m"
  end

  def header(text)
    border = "═" * (text.size + 4)
    puts blue(bold("╔#{border}╗"))
    puts blue(bold("║  #{text}  ║"))
    puts blue(bold("╚#{border}╝"))
  end

  def sub_header(text)
    puts "\n#{bold(text)}"
    puts "─" * text.size
  end

  def section(text)
    puts "\n#{cyan(bold("▶ #{text}"))}"
    puts cyan("─" * (text.size + 2))
  end

  def step(number, text)
    puts "\n#{blue(bold("#{number}️⃣  #{text}"))}"
    puts blue("─" * (text.size + 4))
  end

  def success(text)
    puts green("✓ #{text}")
  end

  def info(text)
    puts blue("ℹ #{text}")
  end

  def warning(text)
    puts yellow("⚠ #{text}")
  end

  def error(text)
    puts red("❌ #{text}")
  end

  def performance(text)
    puts magenta("⚡ #{text}")
  end

  def config_item(key, value)
    puts "  #{cyan("#{key}:")} #{dim(value.to_s)}"
  end

  def migration_status(name, version, status = :applied)
    icon = case status
           when :applied
             green("✓")
           when :pending
             yellow("⏱")
           when :failed
             red("❌")
           else
             blue("•")
           end
    puts "  #{icon} #{name} #{dim("(version #{version})")}"
  end

  def database_operation(operation, details)
    puts "  #{blue("🗄️  #{operation}:")} #{details}"
  end

  def code_block(code, language = "crystal")
    puts dim("```#{language}")
    puts cyan(code)
    puts dim("```")
  end

  def bullet_point(text, level = 0)
    indent = "  " * level
    puts "#{indent}• #{text}"
  end

  def numbered_list(items)
    items.each_with_index do |item, index|
      puts "  #{cyan("#{index + 1}.")} #{item}"
    end
  end

  def progress_bar(current, total, width = 30)
    percentage = (current.to_f / total * 100).round(1)
    filled = (current.to_f / total * width).round.to_i
    bar = "█" * filled + "░" * (width - filled)
    print "\r#{cyan("Progress:")} #{bar} #{percentage}%"
    puts if current == total
  end

  def query_result(query_type, result, cached = false)
    cache_status = cached ? green("[CACHED]") : yellow("[DATABASE]")
    puts "#{cache_status} #{query_type}: #{result.size} records"
    if result.size > 0 && result.size <= 3
      result.each_with_index do |record, i|
        puts "  #{i + 1}. #{record}"
      end
    elsif result.size > 3
      puts "  First 3 results:"
      result.first(3).each_with_index do |record, i|
        puts "  #{i + 1}. #{record}"
      end
      puts "  ... and #{result.size - 3} more"
    end
  end

  def stats(stats)
    puts "\n#{bold("📊 Cache Statistics:")}"
    puts "┌─────────────────┬─────────┐"
    puts "│ Metric          │ Value   │"
    puts "├─────────────────┼─────────┤"
    puts "│ Hits            │ #{stats["hits"].to_s.rjust(7)} │"
    puts "│ Misses          │ #{stats["misses"].to_s.rjust(7)} │"
    puts "│ Cache Size      │ #{stats["size"].to_s.rjust(7)} │"
    puts "│ Hit Rate        │ #{stats["hit_rate_percent"].to_s.rjust(6)}% │"
    puts "└─────────────────┴─────────┘"
  end

  def performance_comparison(baseline_name, baseline_time, optimized_name, optimized_time)
    speedup = baseline_time / optimized_time
    puts "\n#{bold("🏁 Performance Comparison:")}"
    puts "┌─────────────────────────┬─────────────────┐"
    puts "│ Method                  │ Time            │"
    puts "├─────────────────────────┼─────────────────┤"
    puts "│ #{baseline_name.ljust(23)} │ #{baseline_time.total_milliseconds.round(2).to_s.rjust(13)}ms │"
    puts "│ #{optimized_name.ljust(23)} │ #{optimized_time.total_milliseconds.round(2).to_s.rjust(13)}ms │"
    puts "│ #{green("Speedup").ljust(23)} │ #{green("#{speedup.round(2)}x faster").rjust(15)} │"
    puts "└─────────────────────────┴─────────────────┘"
  end

  def feature_list(title, features)
    puts "\n#{bold("✨ #{title}:")}"
    features.each do |feature|
      puts green("  ✓ #{feature}")
    end
  end

  def configuration_block(title, configs)
    puts "\n#{bold("⚙️  #{title}:")}"
    configs.each do |key, value|
      config_item(key, value)
    end
  end

  def schema_info(schema_name, adapter, uri)
    puts "\n#{bold("🗄️  Database Schema:")}"
    config_item("Schema", schema_name)
    config_item("Adapter", adapter)
    config_item("URI", uri)
  end

  def summary_box(title, items)
    max_length = ([title] + items).max_of(&.size) + 4
    border = "─" * max_length

    puts "\n#{blue("╭#{border}╮")}"
    puts blue("│ #{bold(title).ljust(max_length - 1)} │")
    puts blue("├#{border}┤")
    items.each do |item|
      puts blue("│ #{item.ljust(max_length - 1)} │")
    end
    puts blue("╰#{border}╯")
  end

  def status_indicator(status, message)
    icon = case status
           when :success
             green("✅")
           when :warning
             yellow("⚠️")
           when :error
             red("❌")
           when :info
             blue("ℹ️")
           when :progress
             cyan("🔄")
           else
             "•"
           end
    puts "#{icon} #{message}"
  end

  def file_operation(operation, file_path, status = :success)
    icon = case status
           when :success
             green("📄")
           when :created
             green("📝")
           when :deleted
             red("🗑️")
           when :modified
             yellow("✏️")
           else
             blue("📄")
           end
    puts "#{icon} #{operation}: #{cyan(file_path)}"
  end

  def separator(char = "═", length = 60)
    puts char * length
  end

  def empty_line
    puts
  end

  def cleanup_notice
    puts "\n#{dim("🧹 Cleaning up...")}"
  end

  def demo_complete(title)
    puts "\n#{green(bold("🎉 #{title} Complete!"))}"
  end

  def timestamp
    Time.local.to_s("%H:%M:%S.%3N")
  end

  def execution_time(duration)
    if duration.total_milliseconds < 1000
      "#{duration.total_milliseconds.round(2)}ms"
    else
      "#{duration.total_seconds.round(2)}s"
    end
  end

  def json_snippet(data)
    puts dim("```json")
    puts cyan(data.to_pretty_json)
    puts dim("```")
  end

  def sql_snippet(sql)
    puts dim("```sql")
    puts cyan(sql)
    puts dim("```")
  end

  def table_header(columns)
    max_widths = columns.map { |col| col.to_s.size + 2 }
    header = "┌" + max_widths.map { |width| "─" * width }.join("┬") + "┐"
    content = "│" + columns.zip(max_widths).map { |column, width| " #{column}".ljust(width) }.join("│") + "│"
    separator = "├" + max_widths.map { |width| "─" * width }.join("┼") + "┤"

    puts header
    puts content
    puts separator
  end

  def table_row(columns, max_widths)
    content = "│" + columns.zip(max_widths).map { |column, width| " #{column}".ljust(width) }.join("│") + "│"
    puts content
  end

  def table_footer(max_widths)
    footer = "└" + max_widths.map { |width| "─" * width }.join("┴") + "┘"
    puts footer
  end
end
