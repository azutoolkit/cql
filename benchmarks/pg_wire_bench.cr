# Compares CQL's native wire driver (CQL::Postgres::AsyncEngine) with the `pg`
# shard on the same server, through the same crystal-db calls.
#
#   DATABASE_URL=postgres://user:pass@localhost/db crystal run --release benchmarks/pg_wire_bench.cr
#
# Settings (environment): BENCH_OPS (operations per workload, default 5000),
# BENCH_CONCURRENCY (fibers for the concurrent workload, default 8), BENCH_WARMUP
# (default 200). Each driver gets a pool as large as the concurrency, filled
# before timing. It drops and creates the table `cql_wire_bench_items`. Nothing
# here is a result: numbers depend on your server, network and build.
#
# Read results with these in mind: the drivers differ in design (the wire driver
# caches prepared statements per connection and reads binary results; the pg
# shard parses on every call), the wire driver runs first, inserts are dominated
# by the server's commit, and everything runs on one Crystal thread. Put
# `sslmode=` in DATABASE_URL so both sides negotiate TLS the same way. The pg
# shard's CQL query rows run through a CQL::Schema with its own pool (up to the
# same size), so that driver may hold up to twice as many connections.
require "../src/postgres"
require "pg"

DATABASE_URL = ENV["DATABASE_URL"]? || abort("set DATABASE_URL, e.g. postgres://user:pass@localhost/db")
OPS          = (ENV["BENCH_OPS"]? || "5000").to_i
CONCURRENCY  = (ENV["BENCH_CONCURRENCY"]? || "8").to_i
WARMUP       = (ENV["BENCH_WARMUP"]? || "200").to_i
TABLE        = "cql_wire_bench_items"

def bench_schema(name : Symbol, uri : String) : CQL::Schema
  CQL::Schema.define(name, uri, CQL::Adapter::Postgres) do
    table :cql_wire_bench_items do
      primary :id, Int64, auto_increment: true
      text :name
      integer :qty
    end
  end
end

# Runs *size* sleeping queries at once so the driver's pool opens all its connections.
def hold_connections(size : Int32, &spawner : Channel(Nil) ->) : Nil
  done = Channel(Nil).new
  size.times { spawner.call(done) }
  size.times { done.receive }
end

# One driver under test.
abstract class Contender
  abstract def name : String
  # The CQL query DSL on this driver: `SELECT name WHERE id = $1`.
  abstract def lookup(id : Int64) : String
  abstract def scalar(n : Int64) : Int64
  abstract def hundred_rows : Int32
  abstract def insert(n : Int64) : Nil
  abstract def reset : Nil
  abstract def warm_up_pool(size : Int32) : Nil
  abstract def close : Nil
end

class WireContender < Contender
  @engine : CQL::Postgres::AsyncEngine
  @schema : CQL::Schema

  def initialize(url : String, pool : Int32)
    separator = url.includes?('?') ? '&' : '?'
    @engine = CQL::Postgres::AsyncEngine.connect("#{url}#{separator}pool_size=#{pool}")
    @schema = bench_schema(:bench_wire, "postgres://localhost:1/none?initial_pool_size=0")
  end

  def lookup(id : Int64) : String
    @schema.query.from(:cql_wire_bench_items).select(:name).where(id: id).using(@engine).get!(as: String)
  end

  def name : String
    "cql wire"
  end

  def scalar(n : Int64) : Int64
    @engine.exec_query(&.scalar("SELECT $1::int8", n)).as(Int64)
  end

  def hundred_rows : Int32
    @engine.exec_query(&.query_all("SELECT g::int4, 'row ' || g FROM generate_series(1, 100) g", as: {Int32, String})).size
  end

  def insert(n : Int64) : Nil
    @engine.exec_query(&.exec("INSERT INTO #{TABLE} (name, qty, at) VALUES ($1, $2, $3)", "item #{n}", n.to_i32, Time.utc))
  end

  def warm_up_pool(size : Int32) : Nil
    hold_connections(size) { |done| spawn { @engine.exec_query(&.scalar("SELECT pg_sleep(0.05)")); done.send(nil) } }
  end

  def reset : Nil
    @engine.exec("DROP TABLE IF EXISTS #{TABLE}")
    @engine.exec("CREATE TABLE #{TABLE} (id bigserial PRIMARY KEY, name text, qty int, at timestamptz)")
    @engine.exec("INSERT INTO #{TABLE} (name, qty) SELECT 'item ' || g, g FROM generate_series(1, 100) g")
  end

  def close : Nil
    @engine.exec("DROP TABLE IF EXISTS #{TABLE}")
    @engine.close
  end
end

class PgShardContender < Contender
  @db : DB::Database
  @schema : CQL::Schema

  def initialize(url : String, pool : Int32)
    separator = url.includes?('?') ? '&' : '?'
    pooled = "#{url}#{separator}initial_pool_size=#{pool}&max_pool_size=#{pool}&max_idle_pool_size=#{pool}"
    @db = DB.open(pooled)
    @schema = bench_schema(:bench_pg, "#{url}#{separator}initial_pool_size=0&max_pool_size=#{pool}&max_idle_pool_size=#{pool}")
  end

  def lookup(id : Int64) : String
    @schema.query.from(:cql_wire_bench_items).select(:name).where(id: id).get!(as: String)
  end

  def name : String
    "pg shard"
  end

  def scalar(n : Int64) : Int64
    @db.scalar("SELECT $1::int8", n).as(Int64)
  end

  def hundred_rows : Int32
    @db.query_all("SELECT g::int4, 'row ' || g FROM generate_series(1, 100) g", as: {Int32, String}).size
  end

  def insert(n : Int64) : Nil
    @db.exec("INSERT INTO #{TABLE} (name, qty, at) VALUES ($1, $2, $3)", "item #{n}", n.to_i32, Time.utc)
  end

  def warm_up_pool(size : Int32) : Nil
    hold_connections(size) { |done| spawn { @db.scalar("SELECT pg_sleep(0.05)"); done.send(nil) } }
  end

  def reset : Nil
    @db.exec("DROP TABLE IF EXISTS #{TABLE}")
    @db.exec("CREATE TABLE #{TABLE} (id bigserial PRIMARY KEY, name text, qty int, at timestamptz)")
    @db.exec("INSERT INTO #{TABLE} (name, qty) SELECT 'item ' || g, g FROM generate_series(1, 100) g")
  end

  def close : Nil
    @db.exec("DROP TABLE IF EXISTS #{TABLE}")
    @db.close
  end
end

record Measurement, workload : String, driver : String, operations : Int32, elapsed : Time::Span, latencies : Array(Time::Span) do
  def per_second : Float64
    operations / elapsed.total_seconds
  end

  def mean_us : Float64
    latencies.sum(&.total_microseconds) / latencies.size
  end

  def percentile_us(fraction : Float64) : Float64
    latencies.sort[((latencies.size - 1) * fraction).round.to_i].total_microseconds
  end
end

# Runs *total* operations over *fibers* fibers and times each one.
def measure(workload : String, contender : Contender, total : Int32, fibers : Int32, &operation : Int64 ->) : Measurement
  latencies = Array(Time::Span).new(total)
  done = Channel(Exception?).new
  per_fiber = total // fibers
  started = Time.instant
  fibers.times do |fiber|
    spawn do
      per_fiber.times do |step|
        began = Time.instant
        operation.call((fiber * per_fiber + step).to_i64)
        latencies << (Time.instant - began)
      end
      done.send(nil)
    rescue ex
      done.send(ex)
    end
  end
  failures = Array.new(fibers) { done.receive }.compact
  raise failures.first unless failures.empty?
  Measurement.new(workload, contender.name, per_fiber * fibers, Time.instant - started, latencies)
end

def warm_up(contender : Contender) : Nil
  WARMUP.times { |round| contender.scalar(round.to_i64) }
  contender.hundred_rows
end

def workloads(contender : Contender) : Array(Measurement)
  contender.reset
  contender.warm_up_pool(CONCURRENCY)
  warm_up(contender)
  [
    measure("select 1 value (1 fiber)", contender, OPS, 1) { |number| contender.scalar(number) },
    measure("select 100 rows (1 fiber)", contender, OPS // 10, 1) { |_| contender.hundred_rows },
    measure("insert 1 row (1 fiber)", contender, OPS, 1) { |number| contender.insert(number) },
    measure("CQL query DSL, 1 row (1 fiber)", contender, OPS, 1) { |number| contender.lookup(number % 100 + 1) },
    measure("CQL query DSL, 1 row (#{CONCURRENCY} fibers)", contender, OPS, CONCURRENCY) { |number| contender.lookup(number % 100 + 1) },
    measure("select 1 value (#{CONCURRENCY} fibers)", contender, OPS, CONCURRENCY) { |number| contender.scalar(number) },
    measure("insert 1 row (#{CONCURRENCY} fibers)", contender, OPS, CONCURRENCY) { |number| contender.insert(number) },
  ]
end

def report(results : Array(Measurement)) : Nil
  puts "%-30s %-9s %10s %10s %10s %10s" % {"workload", "driver", "ops/s", "mean µs", "p50 µs", "p99 µs"}
  results.sort_by { |result| {result.workload, result.driver} }.each do |result|
    puts "%-30s %-9s %10.0f %10.1f %10.1f %10.1f" % {result.workload, result.driver, result.per_second, result.mean_us, result.percentile_us(0.5), result.percentile_us(0.99)}
  end
end

puts "operations per workload: #{OPS}, concurrency: #{CONCURRENCY}, warm-up: #{WARMUP}"
contenders = [WireContender.new(DATABASE_URL, CONCURRENCY), PgShardContender.new(DATABASE_URL, CONCURRENCY)] of Contender
begin
  results = contenders.flat_map { |contender| workloads(contender) }
  report(results)
ensure
  contenders.each(&.close)
end
