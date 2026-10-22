# Tour of the native PostgreSQL driver, CQL::Postgres::AsyncEngine. Run from the
# repository root against any PostgreSQL server you can write a table to:
#
#   shards install
#   DATABASE_URL=postgres://user:pass@localhost/db crystal run playground/postgres_async_demo.cr
#
# It creates one table, cql_async_demo_orders, and drops it again when it exits.
# No bound value is ever printed: telemetry shows SQL and parameter counts only.
require "pg" # only so CQL::Schema can describe the PostgreSQL dialect; no connection is made through it
require "../src/cql"
require "../src/postgres"

Log.setup(:warn)

DATABASE_URL = ENV["DATABASE_URL"]? || abort("set DATABASE_URL, e.g. postgres://user:pass@localhost/db")
TABLE        = "cql_async_demo_orders"

# The schema only describes tables and renders PostgreSQL SQL ($1, $2, ...).
# `initial_pool_size=0` keeps it from opening a connection of its own: every
# statement below runs on the engine instead.
Shop = CQL::Schema.define(:shop, "postgres://localhost:1/none?initial_pool_size=0", CQL::Adapter::Postgres) do
  table :cql_async_demo_orders do
    primary :id, Int64, auto_increment: true
    text :customer
    bigint :cents
    text :status
  end
end

class Order
  include CQL::ActiveRecord::Model(Int64)
  db_context Shop, :cql_async_demo_orders

  property customer : String
  property cents : Int64
  property status : String

  def initialize(@customer, @cents, @status = "open")
  end
end

def section(number : Int32, title : String) : Nil
  puts "\n== #{number}. #{title}"
end

# --- 1. Connect ---------------------------------------------------------------
section 1, "Connect (pool of 5)"
separator = DATABASE_URL.includes?('?') ? '&' : '?'
engine = CQL::Postgres::AsyncEngine.connect("#{DATABASE_URL}#{separator}pool_size=5")
at_exit do
  engine.exec("DROP TABLE IF EXISTS #{TABLE}") rescue nil
  engine.close
end
engine.with_connection do |connection|
  parameters = connection.session.server_parameters
  puts "connected to PostgreSQL #{parameters["server_version"]} as backend #{connection.session.process_id}"
end
puts "pool: #{engine.pool.stats}"

# --- 2. Telemetry -------------------------------------------------------------
section 2, "Telemetry (every statement below goes through it)"
CQL::Telemetry.subscribe("demo") do |event|
  status = event.success? ? "ok" : "FAILED #{event.error.class}"
  puts "  [#{event.operation}] %.2fms %s (%d params) %s" % {event.duration.total_milliseconds, event.sql, event.param_count, status}
end

engine.exec("DROP TABLE IF EXISTS #{TABLE}")
engine.exec("CREATE TABLE #{TABLE} (id bigserial PRIMARY KEY, customer text NOT NULL UNIQUE, cents bigint NOT NULL, status text NOT NULL)")

# --- 3. Parameterized queries ---------------------------------------------------
section 3, "Parameterized queries through the CQL DSL"
["ada", "bob", "cyd"].each_with_index do |customer, index|
  Shop.insert.into(:cql_async_demo_orders).values(customer: customer, cents: (index + 1) * 1250_i64, status: "open").using(engine).commit
end
hostile = "x'; DROP TABLE #{TABLE}; --"
names = Shop.query.from(:cql_async_demo_orders).select(:customer).where(customer: hostile).using(engine).all(as: String)
puts "a hostile value is just data: #{names.size} rows"
big = Shop.query.from(:cql_async_demo_orders).select(:customer, :cents).where("cents >= ?", 2500_i64).order(cents: :desc).using(engine).all(as: {String, Int64})
puts "orders of at least 25.00: #{big.inspect}"

# --- 4. Model hydration ---------------------------------------------------------
section 4, "ActiveRecord models, no extra mapping code"
orders = Order.query.where(status: "open").order_by(cents: :asc).using(engine).to_a
puts orders.map { |order| "#{order.customer}: #{order.cents}" }.join(", ")

# --- 5. Concurrency ---------------------------------------------------------------
section 5, "Eight fibers sharing a pool of five connections"
CQL::Telemetry.unsubscribe("demo")
started = Time.instant
done = Channel(Int32).new
8.times do |fiber|
  spawn do
    engine.exec_query(&.scalar("SELECT pg_sleep(0.2), $1::int", fiber))
    done.send(fiber)
  end
end
8.times { done.receive }
elapsed = (Time.instant - started).total_seconds.round(2)
puts "8 queries of 0.2s each finished in #{elapsed}s (sequentially: 1.6s; five at a time: about 0.4s)"
puts "pool: #{engine.pool.stats}"

# --- 6. Pipelining ----------------------------------------------------------------
section 6, "Pipelining: one connection, many statements, one round trip"
statements = Array.new(200) { |number| {"SELECT $1::int + 1", [number.to_i32.as(DB::Any)]} }
started = Time.instant
results = engine.pipeline(statements)
pipelined = (Time.instant - started).total_milliseconds
started = Time.instant
statements.each { |(sql, params)| engine.exec_query(&.scalar(sql, args: params)) }
one_by_one = (Time.instant - started).total_milliseconds
total = results.sum { |result| result.as(CQL::Postgres::PipelineResult).all(as: Int32).first }
puts "200 statements, sum of results #{total}: pipelined in %.1fms, one by one in %.1fms" % {pipelined, one_by_one}

# --- 7. Transactions ----------------------------------------------------------------
section 7, "Transactions"
CQL::Telemetry.subscribe("demo") do |event|
  puts "  [#{event.operation}] #{event.sql}#{" FAILED #{event.error.class}" unless event.success?}"
end
engine.transaction do |tx|
  Shop.update.table(:cql_async_demo_orders).set(status: "paid").where(customer: "ada").using(tx).commit
end
begin
  engine.transaction do |tx|
    Shop.update.table(:cql_async_demo_orders).set(status: "paid").where(customer: "bob").using(tx).commit
    raise "payment gateway down"
  end
rescue ex
  puts "rolled back: #{ex.message}"
end
puts "statuses: #{Order.query.order_by(id: :asc).using(engine).to_a.map { |order| "#{order.customer}=#{order.status}" }.join(", ")}"

# Per-transaction options and savepoints. `synchronous_commit: false` is a SET LOCAL: the commit returns before the
# WAL reaches disk, so a server crash can lose it (never corrupt it). Fine for recomputable data, not for payments.
engine.transaction(isolation: :serializable, synchronous_commit: false) do |tx|
  Shop.update.table(:cql_async_demo_orders).set(status: "shipped").where(customer: "ada").using(tx).commit
  tx.savepoint do |inner|
    Shop.update.table(:cql_async_demo_orders).set(status: "lost").where(customer: "ada").using(inner).commit
    raise DB::Rollback.new
  end
end
puts "after a rolled-back savepoint: #{Order.query.where(customer: "ada").using(engine).to_a.map(&.status).join}"

# --- 8. Typed errors ----------------------------------------------------------------
section 8, "Server errors arrive typed, without the offending values"
begin
  Shop.insert.into(:cql_async_demo_orders).values(customer: "ada", cents: 1_i64, status: "open").using(engine).commit
rescue ex : CQL::Postgres::UniqueViolation
  puts "#{ex.class}: #{ex.message}"
  puts "constraint: #{ex.constraint} (the duplicated key is in #detail, which is never part of the message)"
end

CQL::Telemetry.unsubscribe("demo")
puts "\nfinal pool: #{engine.pool.stats}"
