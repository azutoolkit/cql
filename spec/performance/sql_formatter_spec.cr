require "../spec_helper"
require "../../src/performance/sql_formatter"

describe CQL::Performance::SQLFormatter do
  # Disable colorization for predictable test output
  before_each do
    Colorize.enabled = false
  end

  after_each do
    Colorize.enabled = true
  end

  describe "#format" do
    it "formats SQL with params when include_params is on" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false, pretty_format: false, include_params: true)
      result = formatter.format("SELECT * FROM users WHERE id = ?", [1] of DB::Any)
      result.should contain("SQL")
      result.should contain("SELECT * FROM users WHERE id = ?")
      result.should contain("Parameters:")
      result.should contain("[1]")
    end

    it "leaves the bound values out by default" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false, pretty_format: false)
      result = formatter.format("SELECT * FROM users WHERE email = ?", ["secret@example.com"] of DB::Any)
      result.should contain("SELECT * FROM users WHERE email = ?")
      result.should_not contain("Parameters:")
      result.should_not contain("secret@example.com")
    end

    it "formats SQL without params" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false, pretty_format: false)
      result = formatter.format("SELECT * FROM users")
      result.should contain("SQL")
      result.should contain("SELECT * FROM users")
      result.should_not contain("Parameters:")
    end

    it "includes execution time when provided" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false, pretty_format: false)
      result = formatter.format("SELECT 1", execution_time: 50.milliseconds)
      result.should contain("SQL")
    end

    it "includes rows affected when provided" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false, pretty_format: false)
      result = formatter.format("UPDATE users SET name = ?", ["test"] of DB::Any, rows_affected: 5_i64)
      result.should contain("5 rows")
    end

    it "includes context when provided" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false, pretty_format: false)
      result = formatter.format("SELECT 1", context: "test-context")
      result.should contain("test-context")
    end
  end

  describe "#format_sql_only" do
    it "formats just the SQL without metadata" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false, pretty_format: false)
      result = formatter.format_sql_only("SELECT * FROM users WHERE id = ?")
      result.should eq("SELECT * FROM users WHERE id = ?")
    end

    it "applies pretty formatting when enabled" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false, pretty_format: true)
      result = formatter.format_sql_only("SELECT * FROM users WHERE id = 1")
      result.should contain("SELECT")
      result.should contain("FROM")
      result.should contain("WHERE")
    end

    it "does not apply pretty formatting when disabled" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false, pretty_format: false)
      sql = "SELECT * FROM users"
      result = formatter.format_sql_only(sql)
      result.should eq(sql)
    end
  end

  describe "#format_params" do
    it "formats a parameter array" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false)
      params = [1, "hello"] of DB::Any
      result = formatter.format_params(params)
      result.should eq("[1, hello]")
    end

    it "returns empty brackets for empty params" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false)
      result = formatter.format_params([] of DB::Any)
      result.should eq("[]")
    end

    it "truncates long parameter values at max_param_length" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false, max_param_length: 10)
      long_string = "a" * 50
      params = [long_string] of DB::Any
      result = formatter.format_params(params)
      result.should contain("aaaaaaaaaa...")
      result.should_not contain(long_string)
    end

    it "does not truncate short parameter values" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false, max_param_length: 50)
      params = ["short"] of DB::Any
      result = formatter.format_params(params)
      result.should eq("[short]")
    end

    it "escapes control characters so a value cannot start a new log line" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false)
      result = formatter.format_params(["a\nERROR forged"] of DB::Any)
      result.should eq("[a\\nERROR forged]")
    end

    it "formats multiple parameters separated by commas" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false)
      params = [1, "two", 3] of DB::Any
      result = formatter.format_params(params)
      result.should eq("[1, two, 3]")
    end
  end

  describe "#loggable_error" do
    redacting = CQL::Performance::SQLFormatter.new(colorize_enabled: false, include_params: false)

    it "redacts single-quoted literals in a driver message when include_params is off" do
      redacting.loggable_error("Duplicate entry 'secret@example.com' for key 'users.email'")
        .should eq("Duplicate entry '?'")
    end

    it "redacts double-quoted literals in a driver message when include_params is off" do
      redacting.loggable_error(%(invalid input syntax for type integer: "secret@example.com"))
        .should eq(%(invalid input syntax for type integer: "?"))
      redacting.loggable_error(%(relation "users" does not exist)).should eq(%(relation "?" does not exist))
    end

    it "redacts a value that holds its own quote, which drivers print unescaped" do
      redacting.loggable_error("Duplicate entry 'o'brien@example.com' for key 'users.email'")
        .should eq("Duplicate entry '?'")
      redacting.loggable_error(%(invalid input syntax for type integer: "a"secret"))
        .should eq(%(invalid input syntax for type integer: "?"))
    end

    it "redacts a value that follows an apostrophe in the driver's own wording" do
      redacting.loggable_error("Variable 'sql_mode' can't be set to the value of 'secret'").should eq("Variable '?'")
    end

    it "redacts a value that holds the other kind of quote" do
      {
        {"hunter2", %(invalid input syntax for type uuid: "{"password":"hunter2'x"}"), %(invalid input syntax for type uuid: "?)},
        {"secret", %(invalid input syntax for type integer: "x"secret' tail"), %(invalid input syntax for type integer: "?)},
        {"secret", %(can't parse "abc'secret"), %(can'?")},
      }.each do |secret, message, redacted|
        redacting.loggable_error(message).should eq(redacted)
        redacting.loggable_error(message).should_not contain(secret)
      end
    end

    it "redacts from the first quote to the last one" do
      redacting.loggable_error("empty '' value").should eq("empty '?' value")
      redacting.loggable_error("keys 'a','b' end").should eq("keys '?' end")
      redacting.loggable_error(%(near 'a "b" c' end)).should eq("near '?' end")
    end

    it "redacts a lone quote to the end of the message" do
      redacting.loggable_error("near 'abc").should eq("near '?")
      redacting.loggable_error("can't connect").should eq("can'?")
    end

    it "leaves a message without quotes unchanged" do
      redacting.loggable_error("no such column: nope").should eq("no such column: nope")
    end

    it "redacts invalid UTF-8 inside a literal without raising" do
      redacting.loggable_error(String.new(Bytes[0x6b, 0x20, 0x27, 0xff, 0xfe, 0x27])).should eq("k '?'")
    end

    it "redacts a very long value" do
      redacting.loggable_error("x '" + "a" * 100_000 + "' y").should eq("x '?' y")
      redacting.loggable_error("x '" + "a" * 100_000).should eq("x '?")
    end

    it "returns the message verbatim when include_params is on" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false, include_params: true)
      formatter.loggable_error("Duplicate entry 'secret@example.com' for key 'users.email'")
        .should eq("Duplicate entry 'secret@example.com' for key 'users.email'")
    end
  end

  describe "#configure" do
    it "updates colorize setting" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false, pretty_format: false)
      formatter.configure(colorize: false)
      result = formatter.format_sql_only("SELECT 1")
      result.should eq("SELECT 1")
    end

    it "updates pretty format setting" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false, pretty_format: false)
      formatter.configure(pretty: true)
      result = formatter.format_sql_only("SELECT * FROM users WHERE id = 1")
      result.should contain("\n")
    end

    it "updates max_sql_length setting" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false, pretty_format: false)
      formatter.configure(max_sql: 20)
      result = formatter.format("SELECT * FROM users WHERE id = 1 AND name = 'test'")
      result.should contain("...")
    end

    it "updates include_params setting" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false, pretty_format: false)
      formatter.configure(include_params: true)
      result = formatter.format("SELECT * FROM users WHERE id = ?", [7] of DB::Any)
      result.should contain("Parameters: [7]")
    end

    it "updates max_param_length setting" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false)
      formatter.configure(max_param: 5)
      params = ["longvalue"] of DB::Any
      result = formatter.format_params(params)
      result.should contain("longv...")
    end
  end

  describe "SQL truncation" do
    it "truncates SQL at max_sql_length" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false, pretty_format: false, max_sql_length: 30)
      long_sql = "SELECT * FROM users WHERE id = 1 AND name = 'test' AND email = 'foo@bar.com'"
      result = formatter.format(long_sql)
      result.should contain("...")
    end

    it "does not truncate SQL shorter than max_sql_length" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false, pretty_format: false, max_sql_length: 500)
      short_sql = "SELECT * FROM users"
      result = formatter.format(short_sql)
      result.should contain("SELECT * FROM users")
      result.should_not contain("...")
    end
  end

  describe "pretty formatting" do
    it "adds line breaks at SQL keywords" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false, pretty_format: true)
      sql = "SELECT id, name FROM users WHERE active = 1 ORDER BY name"
      result = formatter.format_sql_only(sql)
      result.should contain("\n")
      result.should contain("SELECT")
      result.should contain("FROM")
      result.should contain("WHERE")
      result.should contain("ORDER BY")
    end

    it "adds line breaks for JOIN clauses" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false, pretty_format: true)
      sql = "SELECT * FROM users INNER JOIN orders ON users.id = orders.user_id"
      result = formatter.format_sql_only(sql)
      result.should contain("INNER JOIN")
    end

    it "normalizes whitespace in SQL" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false, pretty_format: true)
      sql = "SELECT   *   FROM   users   WHERE   id = 1"
      result = formatter.format_sql_only(sql)
      result.should_not contain("   ")
    end
  end

  describe "empty params handling" do
    it "does not include parameters section when params are empty" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false, pretty_format: false)
      result = formatter.format("SELECT * FROM users", [] of DB::Any)
      result.should_not contain("Parameters:")
    end

    it "format_params returns empty brackets for empty array" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false)
      result = formatter.format_params([] of DB::Any)
      result.should eq("[]")
    end
  end
end
