# CQL query DSL tour. Run from the repository root:
#
#   shards install && crystal run playground/cql_demo.cr
#
# It uses a throwaway SQLite file, so no database server is needed.
require "sqlite3"
require "../src/cql"

Log.setup(:warn)

DB_FILE = File.join(Dir.tempdir, "cql_demo_#{Process.pid}.db")
at_exit { File.delete?(DB_FILE) }

Demo = CQL::Schema.define(:demo, adapter: CQL::Adapter::SQLite, uri: "sqlite3://#{DB_FILE}") do
  table :authors do
    primary :id, Int64
    column :name, String
    column :age, Int32
    column :status, String
  end

  table :profiles do
    primary :id, Int64
    column :author_id, Int64
    column :country, String
  end

  table :books do
    primary :id, Int64
    column :title, String
    column :author_id, Int64
    column :pages, Int32
  end
end

class Author
  include CQL::ActiveRecord::Model(Int64)
  db_context Demo, :authors

  property name : String
  property age : Int32
  property status : String

  has_one :profile, Profile, foreign_key: :author_id
  has_many :books, Book, foreign_key: :author_id

  def initialize(@name, @age, @status = "active")
  end
end

class Profile
  include CQL::ActiveRecord::Model(Int64)
  db_context Demo, :profiles

  property author_id : Int64
  property country : String

  belongs_to :author, Author, :author_id

  def initialize(@author_id, @country)
  end
end

class Book
  include CQL::ActiveRecord::Model(Int64)
  db_context Demo, :books

  property title : String
  property author_id : Int64
  property pages : Int32

  belongs_to :author, Author, :author_id

  def initialize(@title, @author_id, @pages)
  end
end

def section(title : String) : Nil
  puts "\n== #{title}"
end

def show(sql_and_params) : Nil
  sql, params = sql_and_params
  puts "  #{sql}"
  puts "  params: #{params.inspect}" unless params.empty?
end

Demo.authors.create!
Demo.profiles.create!
Demo.books.create!

ada = Author.create!(name: "Ada", age: 36, status: "active")
alan = Author.create!(name: "Alan", age: 41, status: "active")
kid = Author.create!(name: "Kid", age: 12, status: "pending")
Profile.create!(author_id: ada.id.not_nil!, country: "US")
Profile.create!(author_id: alan.id.not_nil!, country: "UK")
Book.create!(title: "Notes", author_id: ada.id.not_nil!, pages: 120)
Book.create!(title: "Engines", author_id: ada.id.not_nil!, pages: 340)
Book.create!(title: "Machines", author_id: alan.id.not_nil!, pages: 210)

# Everything below goes through one execution path, so one subscriber sees it all.
statements = [] of CQL::Telemetry::QueryEvent
CQL::Telemetry.subscribe("demo") { |event| statements << event }

section "1. Typed where: bare column names, checked at compile time"
adults = Author.query.where { (age >= 18) & (status == "active") }.order_by(age: :desc).limit(20)
show adults.query.to_sql
puts "  => #{adults.to_a.map(&.name)}"
# Author.query.where { agee > 1 }       # compile error: unknown column `agee` on Author
# Author.query.where { age > "old" }    # compile error: cannot compare a Int32 column with String

section "2. Association join with a typed condition"
us = Author.query.joins(:profile) { profile.country == "US" }
show us.query.to_sql
puts "  => #{us.to_a.map(&.name)}"

section "3. Partial select returns lightweight rows"
rows = Author.query.where { age >= 18 }.select(:id, :name).order_by(name: :asc).to_a
puts "  => #{rows.map { |row| {row.id, row.name} }}"

section "4. Dynamic filters, built conditionally"
filters = {"min_age" => "30", "status" => ""}
people = Author.query
people = people.where { age >= filters["min_age"].to_i } unless filters["min_age"].empty?
people = people.where { status == filters["status"] } unless filters["status"].empty?
show people.query.to_sql

section "5. Raw fragments are always bound, never interpolated"
hostile = "x'; DROP TABLE authors; --"
raw = Author.query.where("lower(name) = lower(:name) OR age > :age", name: hostile, age: 40)
show raw.query.to_sql
puts "  => #{raw.to_a.map(&.name)} (table still exists: #{Author.count} authors)"

section "6. CTE + window function"
totals = Demo.query.from(:books).select(:author_id).sum(:pages, as: :pages_total).group(:author_id)
ranked = Demo.query
  .with(:totals, totals)
  .from(:totals)
  .select(:author_id, :pages_total)
  .window(:rank, as: :position, order_by: {pages_total: :desc})
show ranked.to_sql
puts "  => #{ranked.all(as: {Int64, Int64, Int64})}"

section "7. Set operations"
young = Demo.query.from(:authors).select(:name).where(status: "pending")
old = Demo.query.from(:authors).select(:name).where { authors.age > 40 }
show young.union(old).to_sql

section "8. Upsert"
upsert = Demo.insert.into(:authors).values(id: 1_i64, name: "Ada L.", age: 37, status: "active")
  .on_conflict(:id).do_update(:name, :age)
show upsert.to_sql
upsert.commit
puts "  => #{Author.find!(1_i64).name}"

section "9. The same query, rendered for every dialect"
q = Demo.query.from(:authors).select(:name).where(status: "active").limit(5).offset(10)
{CQL::Adapter::SQLite, CQL::Adapter::Postgres, CQL::Adapter::MySql, CQL::Adapter::CockroachDB}.each do |adapter|
  puts "  #{adapter.to_s.ljust(11)} #{q.to_sql(for: adapter)[0]}"
end

section "10. EXPLAIN"
puts q.explain.lines.map { |line| "  #{line}" }.join("\n")

section "11. Telemetry saw everything above"
statements.last(3).each do |event|
  puts "  [#{event.operation}] #{event.duration.total_microseconds.to_i}us  #{event.sql[0, 70]}"
end
puts "  #{statements.size} statements, #{statements.count(&.success?)} succeeded"
