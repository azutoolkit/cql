# Query building plus SQL generation (`to_sql`, no database round trip), then ActiveRecord operations
# (`ar:` workloads) against a seeded in-memory SQLite database, with the library's default configuration.
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

# ActiveRecord workloads hit a real SQLite DB. In-memory DBs are per connection, so the pool is pinned to one.
ArSchema = CQL::Schema.define(:ar_bench, adapter: CQL::Adapter::SQLite, uri: "sqlite3::memory:?max_pool_size=1&initial_pool_size=1") do
  table :ar_users do
    primary :id, Int64, auto_increment: true
    text :name
    text :email
    integer :age
  end

  table :ar_posts do
    primary :id, Int64, auto_increment: true
    bigint :user_id
    text :title
  end

  table :ar_events do
    primary :id, Int64, auto_increment: true
    text :name
  end
end

class ArUser
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: ArSchema, table: :ar_users

  property name : String
  property email : String
  property age : Int32

  has_many :posts, ArPost, foreign_key: :user_id

  def initialize(@name, @email, @age)
  end
end

class ArPost
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: ArSchema, table: :ar_posts

  property user_id : Int64
  property title : String

  def initialize(@user_id, @title)
  end
end

class ArEvent
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: ArSchema, table: :ar_events

  property name : String

  def initialize(@name)
  end
end

AR_USERS = 10_000

ArSchema.ar_users.create!
ArSchema.ar_posts.create!
ArSchema.ar_events.create!
# Real apps index foreign keys and filter columns; `index` in a table block is not emitted, so create them here.
ArSchema.exec("CREATE INDEX idx_ar_posts_user_id ON ar_posts (user_id)")
ArSchema.exec("CREATE INDEX idx_ar_users_age ON ar_users (age)")
(1..AR_USERS).each_slice(500) do |ids|
  users = ids.map { |id| {:name => "user #{id}", :email => "user#{id}@example.com", :age => 20 + id % 50} of Symbol => DB::Any }
  posts = ids.flat_map { |id| (1..3).map { |number| {:user_id => id.to_i64, :title => "post #{number}"} of Symbol => DB::Any } }
  ArSchema.insert.into(:ar_users).values(users).commit
  ArSchema.insert.into(:ar_posts).values(posts).commit
end

workload("ar: find by id") do |job|
  job.report("ArUser.find") { ArUser.find(5_000_i64) }
end

workload("ar: where + order + first") do |job|
  job.report("where.order.first") { ArUser.where(age: 30).order(name: :desc).first }
end

workload("ar: load 100 rows") do |job|
  job.report("limit(100).all") { ArUser.query.limit(100).all }
end

workload("ar: last") do |job|
  job.report("ArUser.last") { ArUser.last }
end

workload("ar: exists?") do |job|
  job.report("where.exists?") { ArUser.query.exists?(age: 30) }
end

workload("ar: find_each 10000 rows") do |job|
  job.report("find_each") { ArUser.query.find_each { |user| user } }
end

workload("ar: has_many children") do |job|
  parent = ArUser.find!(1_i64)
  job.report("association") { parent.reload_posts.to_a }
  job.report("100 parents, association") { ArUser.query.limit(100).all.each(&.posts.to_a) }
  job.report("100 parents, preload") { ArUser.query.limit(100).preload(:posts).all.each(&.posts.to_a) }
end

workload("ar: insert one") do |job|
  job.report("create!") { ArEvent.new("event").create! }
end

workload("ar: update one") do |job|
  user = ArUser.find!(1_i64)
  names = {"renamed", "user 1"}
  updates = 0
  job.report("update!") do
    updates += 1
    user.update!(name: names[updates % 2])
  end
end

workload("ar: insert 1000 records") do |job|
  job.report("1000 x create!") { 1000.times { ArEvent.new("event").create! } }
end

abort "BENCH_ONLY=#{BENCH_ONLY} matched no workload" if WORKLOADS_RUN.empty?
