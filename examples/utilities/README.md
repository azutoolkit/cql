# Utilities

`beautify.cr` defines `Beautify`, the console helpers that the blog app and several examples print with. It is not a
program: require it and include the module.

```crystal
require "../utilities/beautify" # from a file in examples/<dir>/
include Beautify

header("Cache demo")
step(1, "Store and read")
success("Stored 3 users")
database_operation("user:1", "Ada")
configuration_block("Cache", {"Max size" => 100, "TTL" => "30 minutes"})
performance("Second read took #{execution_time(0.42.milliseconds)}")
stats({"hits" => 3, "misses" => 1, "size" => 3, "hit_rate_percent" => 75.0})
status_indicator(:warning, "Hit rate below 80%")
demo_complete("Cache demo")
```

```text
╔══════════════╗
║  Cache demo  ║
╚══════════════╝

1️⃣  Store and read
──────────────────
✓ Stored 3 users
  🗄️  user:1: Ada

⚙️  Cache:
  Max size: 100
  TTL: 30 minutes
⚡ Second read took 0.42ms

📊 Cache Statistics:
┌─────────────────┬─────────┐
│ Metric          │ Value   │
├─────────────────┼─────────┤
│ Hits            │       3 │
│ Misses          │       1 │
│ Cache Size      │       3 │
│ Hit Rate        │   75.0% │
└─────────────────┴─────────┘
⚠️ Hit rate below 80%

🎉 Cache demo Complete!
```

Colors are plain ANSI escape codes, so they show as raw codes where the terminal does not interpret them.

| Group | Methods |
| --- | --- |
| Colors (return a `String`) | `bold`, `blue`, `green`, `yellow`, `cyan`, `magenta`, `red`, `dim` |
| Headings | `header(text)`, `section(text)`, `step(number, text)`, `sub_header(text)`, `separator(char = "═", length = 60)`, `empty_line` |
| Messages | `success`, `info`, `warning`, `error`, `performance`, `status_indicator(status, message)` with `:success`, `:warning`, `:error`, `:info` or `:progress` |
| Values | `config_item(key, value)`, `configuration_block(title, hash)`, `schema_info(name, adapter, uri)`, `database_operation(operation, details)`, `stats(hash)` (reads `"hits"`, `"misses"`, `"size"`, `"hit_rate_percent"`), `performance_comparison(name, time, name, time)` |
| Lists and boxes | `bullet_point(text, level = 0)`, `numbered_list(items)`, `feature_list(title, items)`, `summary_box(title, items)`, `table_header(columns)`, `table_row(columns, widths)`, `table_footer(widths)` |
| Snippets | `code_block(code, language = "crystal")`, `sql_snippet(sql)`, `json_snippet(data)` (printed in cyan between fence lines; there is no syntax highlighting) |
| Progress and status | `progress_bar(current, total, width = 30)`, `query_result(type, result, cached = false)`, `migration_status(name, version, status = :applied)`, `file_operation(operation, path, status = :success)`, `cleanup_notice`, `demo_complete(title)` |
| Time | `timestamp` (`HH:MM:SS.mmm`), `execution_time(span)` (`"0.42ms"`, or seconds from 1 s up) |

The snippet above was run with Crystal 1.22.0; the output block is what it printed, without the colors.
