# Query building plus SQL generation (`to_sql`, no database round trip) on an in-memory SQLite schema,
# with the library's default configuration.
#
#   crystal run --release benchmarks/sqlite_bench.cr
#   BENCH_ONLY=join crystal run --release benchmarks/sqlite_bench.cr   # one workload
require "benchmark"
require "sqlite3"
require "../src/cql"

BenchSchema = CQL::Schema.define(:bench, adapter: CQL::Adapter::SQLite, uri: "sqlite3::memory:") do
  table :users do
    primary :id, Int32
    column :name, String
    column :email, String
    column :age, Int32
  end

  table :posts do
    primary :id, Int32
    column :user_id, Int32
    column :title, String
    column :views, Int32
  end
end

INSERT_ROWS = Array.new(500) do |index|
  {:name => "user #{index}", :email => "user#{index}@example.com", :age => 20 + index % 50} of Symbol => DB::Any
end

BENCH_ONLY    = ENV["BENCH_ONLY"]?.try(&.downcase)
WORKLOADS_RUN = [] of String

# Runs one `Benchmark.ips` group; the block adds its reports to the yielded job.
def workload(name : String, &)
  return if BENCH_ONLY.try { |only| !name.downcase.includes?(only) }
  WORKLOADS_RUN << name
  puts name
  Benchmark.ips(warmup: 1.second, calculation: 3.seconds) { |job| yield job }
end

workload("simple where by id") do |job|
  job.report("to_sql") { BenchSchema.query.from(:users).where(id: 42).to_sql }
end

workload("10-condition where") do |job|
  job.report("to_sql") do
    query = BenchSchema.query.from(:users).where do
      users.id.gt(1) & users.id.lt(1000) & users.name.like("a%") & users.name.neq("bob") &
        users.email.like("%@example.com") & users.email.neq("x@example.com") &
        users.age.gte(18) & users.age.lte(65) & users.age.neq(30) & users.age.neq(40)
    end
    query.to_sql
  end
end

workload("join with order and limit") do |job|
  job.report("to_sql") do
    BenchSchema.query.from(:users)
      .join(:posts) { |j| j.users.id.eq(j.posts.user_id) }
      .select(users: [:name], posts: [:title])
      .order(name: :desc).limit(20).to_sql
  end
end

workload("insert #{INSERT_ROWS.size} rows") do |job|
  job.report("to_sql") { BenchSchema.insert.into(:users).values(INSERT_ROWS).to_sql }
end

abort "BENCH_ONLY=#{BENCH_ONLY} matched no workload" if WORKLOADS_RUN.empty?
