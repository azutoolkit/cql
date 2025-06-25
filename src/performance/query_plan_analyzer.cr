# Query Plan Analysis component for CQL Performance Tools
# Provides EXPLAIN query plan analysis with database-specific implementations

require "../cql"

module CQL::Performance
  # Exception for plan analysis errors
  class PlanAnalysisError < Exception; end

  # Represents a database query execution plan
  struct QueryPlan
    getter sql : String
    getter plan : String
    getter estimated_cost : Float64?
    getter estimated_rows : Int64?
    getter execution_time : Time::Span?
    getter warnings : Array(String)

    def initialize(@sql : String, @plan : String,
                   @estimated_cost : Float64? = nil,
                   @estimated_rows : Int64? = nil,
                   @execution_time : Time::Span? = nil,
                   @warnings : Array(String) = [] of String)
    end

    # Check if the plan indicates potential performance issues
    def has_performance_issues? : Bool
      warnings.any? ||
        (estimated_cost && estimated_cost.not_nil! > 1000.0_f32) ||
        (estimated_rows && estimated_rows.not_nil! > 10_000) || false
    end

    # Get a human-readable summary of the plan
    def summary : String
      String.build do |str|
        str << "Query Plan Summary:\n"
        str << "SQL: #{sql[0..100]}#{sql.size > 100 ? "..." : ""}\n"
        str << "Estimated Cost: #{estimated_cost || "N/A"}\n"
        str << "Estimated Rows: #{estimated_rows || "N/A"}\n"
        str << "Execution Time: #{execution_time || "N/A"}\n"
        str << "Warnings: #{warnings.empty? ? "None" : warnings.join(", ")}\n"
        str << "Performance Issues: #{has_performance_issues? ? "YES" : "No"}\n"
      end
    end
  end

  # Query Plan Analyzer - provides EXPLAIN functionality
  class QueryPlanAnalyzer
    Log = ::Log.for(self)

    @schema : Schema
    @enabled : Bool

    def initialize(@schema : Schema, @enabled : Bool = true)
    end

    # Analyze a query plan using EXPLAIN
    def analyze(sql : String, params : Array(DB::Any) = [] of DB::Any) : QueryPlan?
      return nil unless @enabled
      return nil unless should_analyze?(sql)

      Log.debug { "Analyzing query plan for: #{sql[0..100]}..." }

      case @schema.adapter
      when Adapter::Postgres
        analyze_postgres(sql, params)
      when Adapter::MySql
        analyze_mysql(sql, params)
      when Adapter::SQLite
        analyze_sqlite(sql, params)
      else
        Log.warn { "Query plan analysis not supported for adapter: #{@schema.adapter}" }
        nil
      end
    rescue ex : Exception
      Log.error { "Query plan analysis failed: #{ex.message}" }
      nil
    end

    # Analyze with execution (EXPLAIN ANALYZE)
    def analyze_with_execution(sql : String, params : Array(DB::Any) = [] of DB::Any) : QueryPlan?
      return nil unless @enabled
      return nil unless should_analyze?(sql)

      Log.debug { "Analyzing query plan with execution for: #{sql[0..100]}..." }

      case @schema.adapter
      when Adapter::Postgres
        analyze_postgres_with_execution(sql, params)
      when Adapter::MySql
        analyze_mysql_with_execution(sql, params)
      when Adapter::SQLite
        analyze_sqlite_with_execution(sql, params)
      else
        Log.warn { "Query plan analysis with execution not supported for adapter: #{@schema.adapter}" }
        nil
      end
    rescue ex : Exception
      Log.error { "Query plan analysis with execution failed: #{ex.message}" }
      nil
    end

    private def should_analyze?(sql : String) : Bool
      # Only analyze SELECT statements and potentially expensive operations
      normalized = sql.strip.downcase
      normalized.starts_with?("select") ||
        normalized.starts_with?("update") ||
        normalized.starts_with?("delete")
    end

    private def analyze_postgres(sql : String, params : Array(DB::Any)) : QueryPlan
      explain_sql = "EXPLAIN (FORMAT JSON, BUFFERS, VERBOSE) #{sql}"

      plan_json = @schema.exec_query do |conn|
        conn.query_one(explain_sql, args: params, as: String)
      end

      parse_postgres_plan(sql, plan_json)
    end

    private def analyze_postgres_with_execution(sql : String, params : Array(DB::Any)) : QueryPlan
      explain_sql = "EXPLAIN (ANALYZE, FORMAT JSON, BUFFERS, VERBOSE) #{sql}"

      start_time = Time.monotonic
      plan_json = @schema.exec_query do |conn|
        conn.query_one(explain_sql, args: params, as: String)
      end
      execution_time = Time.monotonic - start_time

      parse_postgres_plan(sql, plan_json, execution_time)
    end

    private def parse_postgres_plan(sql : String, plan_json : String, execution_time : Time::Span? = nil) : QueryPlan
      plan_data = JSON.parse(plan_json)
      plan_info = plan_data[0]["Plan"]

      estimated_cost = plan_info["Total Cost"]?.try(&.as_f)
      estimated_rows = plan_info["Plan Rows"]?.try(&.as_i64)

      warnings = [] of String

      # Check for performance warnings
      if plan_info["Node Type"]?.try(&.as_s) == "Seq Scan"
        warnings << "Sequential scan detected - consider adding indexes"
      end

      if estimated_cost && estimated_cost > 1000.0_f32
        warnings << "High estimated cost: #{estimated_cost}"
      end

      QueryPlan.new(
        sql: sql,
        plan: plan_json,
        estimated_cost: estimated_cost,
        estimated_rows: estimated_rows,
        execution_time: execution_time,
        warnings: warnings
      )
    end

    private def analyze_mysql(sql : String, params : Array(DB::Any)) : QueryPlan
      explain_sql = "EXPLAIN FORMAT=JSON #{sql}"

      plan_json = @schema.exec_query do |conn|
        conn.query_one(explain_sql, args: params, as: String)
      end

      parse_mysql_plan(sql, plan_json)
    end

    private def analyze_mysql_with_execution(sql : String, params : Array(DB::Any)) : QueryPlan
      # MySQL doesn't have EXPLAIN ANALYZE, so we time the actual execution
      start_time = Time.monotonic
      @schema.exec_query do |conn|
        conn.exec(sql, args: params)
      end
      execution_time = Time.monotonic - start_time

      plan = analyze_mysql(sql, params)
      return plan unless plan

      QueryPlan.new(
        sql: plan.sql,
        plan: plan.plan,
        estimated_cost: plan.estimated_cost,
        estimated_rows: plan.estimated_rows,
        execution_time: execution_time,
        warnings: plan.warnings
      )
    end

    private def parse_mysql_plan(sql : String, plan_json : String) : QueryPlan
      plan_data = JSON.parse(plan_json)
      query_block = plan_data["query_block"]?

      estimated_cost = query_block.try(&.["cost_info"]?).try(&.["query_cost"]?).try(&.as_f)
      estimated_rows = query_block.try(&.["cost_info"]?).try(&.["query_rows"]?).try(&.as_i64)

      warnings = [] of String

      # Check for table scans
      if plan_json.includes?("table_scan")
        warnings << "Table scan detected - consider adding indexes"
      end

      QueryPlan.new(
        sql: sql,
        plan: plan_json,
        estimated_cost: estimated_cost.try(&.to_f64),
        estimated_rows: estimated_rows,
        warnings: warnings
      )
    end

    private def analyze_sqlite(sql : String, params : Array(DB::Any)) : QueryPlan
      explain_sql = "EXPLAIN QUERY PLAN #{sql}"

      plan_lines = [] of String
      @schema.exec_query do |conn|
        conn.query_each(explain_sql, args: params) do |rs|
          # SQLite returns multiple columns, we want the detail column
          line = rs.read(String?) || rs.read(String?) || rs.read(String?) || rs.read(String?)
          plan_lines << line if line
        end
      end

      parse_sqlite_plan(sql, plan_lines.join("\n"))
    end

    private def analyze_sqlite_with_execution(sql : String, params : Array(DB::Any)) : QueryPlan
      start_time = Time.monotonic
      @schema.exec_query do |conn|
        conn.exec(sql, args: params)
      end
      execution_time = Time.monotonic - start_time

      plan = analyze_sqlite(sql, params)
      return plan unless plan

      QueryPlan.new(
        sql: plan.sql,
        plan: plan.plan,
        estimated_cost: plan.estimated_cost,
        estimated_rows: plan.estimated_rows,
        execution_time: execution_time,
        warnings: plan.warnings
      )
    end

    private def parse_sqlite_plan(sql : String, plan_text : String) : QueryPlan
      warnings = [] of String

      # SQLite plan analysis
      if plan_text.downcase.includes?("scan table")
        warnings << "Table scan detected - consider adding indexes"
      end

      if plan_text.downcase.includes?("using temporary b-tree")
        warnings << "Temporary B-tree created - query may be expensive"
      end

      QueryPlan.new(
        sql: sql,
        plan: plan_text,
        warnings: warnings
      )
    end
  end
end
