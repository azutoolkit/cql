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
    it "formats SQL with params" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false, pretty_format: false)
      result = formatter.format("SELECT * FROM users WHERE id = ?", [1] of DB::Any)
      result.should contain("SQL")
      result.should contain("SELECT * FROM users WHERE id = ?")
      result.should contain("Parameters:")
      result.should contain("[1]")
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

    it "formats multiple parameters separated by commas" do
      formatter = CQL::Performance::SQLFormatter.new(colorize_enabled: false)
      params = [1, "two", 3] of DB::Any
      result = formatter.format_params(params)
      result.should eq("[1, two, 3]")
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
