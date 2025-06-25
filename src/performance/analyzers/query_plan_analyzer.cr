# Refactored Query Plan Analyzer using Strategy Pattern
# Follows Open/Closed Principle - extensible for new database types

require "../interfaces"
require "json"

module CQL::Performance::Analyzers
  # Query Plan Analysis Result
  struct QueryPlanResult < AnalysisResult
    getter estimated_cost : Float64?
    getter estimated_rows : Int64?
    getter execution_time : Time::Span?
    getter plan_data : String

    def initialize(query : String, @plan_data : String,
                   @estimated_cost : Float64? = nil,
                   @estimated_rows : Int64? = nil,
                   @execution_time : Time::Span? = nil,
                   warnings : Array(String) = [] of String)
      super(query, warnings)
    end

    def has_issues? : Bool
      return true if warnings.any?
      return true if estimated_cost && estimated_cost.not_nil! > 1000.0
      return true if estimated_rows && estimated_rows.not_nil! > 10_000
      false
    end

    def performance_score : Float64
      base_score = estimated_cost || 0.0
      rows_penalty = (estimated_rows || 0_i64) * 0.1
      warning_penalty = warnings.size * 50.0

      base_score + rows_penalty + warning_penalty
    end
  end

  # Strategy interface for database-specific plan analysis
  abstract class DatabasePlanStrategy
    abstract def supports?(adapter : Adapter) : Bool
    abstract def analyze(sql : String, params : Array(DB::Any), schema : Schema) : QueryPlanResult
    abstract def analyze_with_execution(sql : String, params : Array(DB::Any), schema : Schema) : QueryPlanResult

    protected def should_analyze?(sql : String) : Bool
      normalized = sql.strip.downcase
      normalized.starts_with?("select") ||
      normalized.starts_with?("update") ||
      normalized.starts_with?("delete")
    end
  end

  # PostgreSQL Plan Analysis Strategy
  class PostgresPlanStrategy < DatabasePlanStrategy
    def supports?(adapter : Adapter) : Bool
      adapter == Adapter::Postgres
    end

    def analyze(sql : String, params : Array(DB::Any), schema : Schema) : QueryPlanResult
      explain_sql = "EXPLAIN (FORMAT JSON, BUFFERS, VERBOSE) #{sql}"

      plan_json = schema.exec_query do |conn|
        conn.query_one(explain_sql, args: params, as: String)
      end

      parse_postgres_plan(sql, plan_json)
    end

    def analyze_with_execution(sql : String, params : Array(DB::Any), schema : Schema) : QueryPlanResult
      explain_sql = "EXPLAIN (ANALYZE, FORMAT JSON, BUFFERS, VERBOSE) #{sql}"

      start_time = Time.monotonic
      plan_json = schema.exec_query do |conn|
        conn.query_one(explain_sql, args: params, as: String)
      end
      execution_time = Time.monotonic - start_time

      parse_postgres_plan(sql, plan_json, execution_time)
    end

    private def parse_postgres_plan(sql : String, plan_json : String, execution_time : Time::Span? = nil) : QueryPlanResult
      plan_data = JSON.parse(plan_json)
      plan_info = plan_data[0]["Plan"]

      estimated_cost = plan_info["Total Cost"]?.try(&.as_f)
      estimated_rows = plan_info["Plan Rows"]?.try(&.as_i64)

      warnings = detect_postgres_warnings(plan_info, estimated_cost)

      QueryPlanResult.new(
        query: sql,
        plan_data: plan_json,
        estimated_cost: estimated_cost,
        estimated_rows: estimated_rows,
        execution_time: execution_time,
        warnings: warnings
      )
    end

    private def detect_postgres_warnings(plan_info : JSON::Any, estimated_cost : Float64?) : Array(String)
      warnings = [] of String

      if plan_info["Node Type"]?.try(&.as_s) == "Seq Scan"
        warnings << "Sequential scan detected - consider adding indexes"
      end

      if estimated_cost && estimated_cost > 1000.0
        warnings << "High estimated cost: #{estimated_cost}"
      end

      if plan_info["Actual Loops"]?.try(&.as_i) && plan_info["Actual Loops"].as_i > 1000
        warnings << "High loop count detected"
      end

      warnings
    end
  end

  # MySQL Plan Analysis Strategy
  class MySQLPlanStrategy < DatabasePlanStrategy
    def supports?(adapter : Adapter) : Bool
      adapter == Adapter::MySql
    end

    def analyze(sql : String, params : Array(DB::Any), schema : Schema) : QueryPlanResult
      explain_sql = "EXPLAIN FORMAT=JSON #{sql}"

      plan_json = schema.exec_query do |conn|
        conn.query_one(explain_sql, args: params, as: String)
      end

      parse_mysql_plan(sql, plan_json)
    end

    def analyze_with_execution(sql : String, params : Array(DB::Any), schema : Schema) : QueryPlanResult
      # MySQL doesn't have EXPLAIN ANALYZE, so we time the actual execution
      start_time = Time.monotonic
      schema.exec_query do |conn|
        conn.exec(sql, args: params)
      end
      execution_time = Time.monotonic - start_time

      result = analyze(sql, params, schema)
      QueryPlanResult.new(
        query: result.query,
        plan_data: result.plan_data,
        estimated_cost: result.estimated_cost,
        estimated_rows: result.estimated_rows,
        execution_time: execution_time,
        warnings: result.warnings
      )
    end

    private def parse_mysql_plan(sql : String, plan_json : String) : QueryPlanResult
      plan_data = JSON.parse(plan_json)
      query_block = plan_data["query_block"]?

      estimated_cost = query_block.try(&.["cost_info"]?).try(&.["query_cost"]?).try(&.as_f)
      estimated_rows = query_block.try(&.["cost_info"]?).try(&.["query_rows"]?).try(&.as_i64)

      warnings = detect_mysql_warnings(plan_json)

      QueryPlanResult.new(
        query: sql,
        plan_data: plan_json,
        estimated_cost: estimated_cost,
        estimated_rows: estimated_rows,
        warnings: warnings
      )
    end

    private def detect_mysql_warnings(plan_json : String) : Array(String)
      warnings = [] of String

      if plan_json.includes?("table_scan")
        warnings << "Table scan detected - consider adding indexes"
      end

      if plan_json.includes?("filesort")
        warnings << "File sort detected - consider optimizing ORDER BY"
      end

      warnings
    end
  end

  # SQLite Plan Analysis Strategy
  class SQLitePlanStrategy < DatabasePlanStrategy
    def supports?(adapter : Adapter) : Bool
      adapter == Adapter::SQLite
    end

    def analyze(sql : String, params : Array(DB::Any), schema : Schema) : QueryPlanResult
      explain_sql = "EXPLAIN QUERY PLAN #{sql}"

      plan_lines = [] of String
      schema.exec_query do |conn|
        conn.query_each(explain_sql, args: params) do |rs|
          line = rs.read(String?) || rs.read(String?) || rs.read(String?) || rs.read(String?)
          plan_lines << line if line
        end
      end

      parse_sqlite_plan(sql, plan_lines.join("\n"))
    end

    def analyze_with_execution(sql : String, params : Array(DB::Any), schema : Schema) : QueryPlanResult
      start_time = Time.monotonic
      schema.exec_query do |conn|
        conn.exec(sql, args: params)
      end
      execution_time = Time.monotonic - start_time

      result = analyze(sql, params, schema)
      QueryPlanResult.new(
        query: result.query,
        plan_data: result.plan_data,
        estimated_cost: result.estimated_cost,
        estimated_rows: result.estimated_rows,
        execution_time: execution_time,
        warnings: result.warnings
      )
    end

    private def parse_sqlite_plan(sql : String, plan_text : String) : QueryPlanResult
      warnings = detect_sqlite_warnings(plan_text)

      QueryPlanResult.new(
        query: sql,
        plan_data: plan_text,
        warnings: warnings
      )
    end

    private def detect_sqlite_warnings(plan_text : String) : Array(String)
      warnings = [] of String

      lower_plan = plan_text.downcase

      if lower_plan.includes?("scan table")
        warnings << "Table scan detected - consider adding indexes"
      end

      if lower_plan.includes?("using temporary b-tree")
        warnings << "Temporary B-tree created - query may be expensive"
      end

      if lower_plan.includes?("using covering index")
        # This is actually good
      end

      warnings
    end
  end

  # Context for the Strategy Pattern
  class StrategyBasedQueryAnalyzer < QueryAnalyzer
    Log = ::Log.for(self)

    @strategies : Array(DatabasePlanStrategy) = [] of DatabasePlanStrategy
    @schema : Schema

    def initialize(@schema : Schema)
      register_default_strategies
    end

    def supports?(adapter : Adapter) : Bool
      @strategies.any?(&.supports?(adapter))
    end

    def analyze(sql : String, params : Array(DB::Any) = [] of DB::Any) : AnalysisResult?
      strategy = find_strategy(@schema.adapter)
      return nil unless strategy

      return nil unless strategy.should_analyze?(sql)

      begin
        strategy.analyze(sql, params, @schema)
      rescue ex : Exception
        Log.error { "Query plan analysis failed: #{ex.message}" }
        nil
      end
    end

    def analyze_with_execution(sql : String, params : Array(DB::Any) = [] of DB::Any) : QueryPlanResult?
      strategy = find_strategy(@schema.adapter)
      return nil unless strategy

      return nil unless strategy.should_analyze?(sql)

      begin
        strategy.analyze_with_execution(sql, params, @schema)
      rescue ex : Exception
        Log.error { "Query plan analysis with execution failed: #{ex.message}" }
        nil
      end
    end

    def add_strategy(strategy : DatabasePlanStrategy) : Void
      @strategies << strategy unless @strategies.includes?(strategy)
    end

    private def register_default_strategies
      @strategies << PostgresPlanStrategy.new
      @strategies << MySQLPlanStrategy.new
      @strategies << SQLitePlanStrategy.new
    end

    private def find_strategy(adapter : Adapter) : DatabasePlanStrategy?
      @strategies.find(&.supports?(adapter))
    end
  end
end
