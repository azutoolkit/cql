# Text against binary bind parameters on the same server, through the wire driver's session.
#
#   DATABASE_URL=postgres://user@localhost/db crystal run --release benchmarks/pg_binary_params_bench.cr
#
# BENCH_ONLY runs only the workloads whose name contains it.
# Settings (environment): BENCH_OPS (statements per workload and round, default 5000), BENCH_ROUNDS (default 7;
# text and binary alternate inside every round and the median is reported). Each workload sends the same values
# both ways and checks that the server returned the same rows first. It creates the table
# `cql_binary_bench_items` (unlogged). Nothing here is a result: numbers depend on your server, network and build.
require "../src/postgres"

alias PG = CQL::Postgres

URL    = ENV["DATABASE_URL"]? || abort("set DATABASE_URL, e.g. postgres://user@localhost/db")
OPS    = (ENV["BENCH_OPS"]? || "5000").to_i
ROUNDS = (ENV["BENCH_ROUNDS"]? || "7").to_i
TABLE  = "cql_binary_bench_items"

def connect(binary : Bool) : PG::Session
  separator = URL.includes?('?') ? "&" : "?"
  PG::Session.connect(PG::Config.parse(binary ? "#{URL}#{separator}binary_params=true" : URL))
end

record Workload, name : String, sql : String, params : Proc(PG::Session, Array(PG::Types::Param))

def timed(session : PG::Session, workload : Workload) : Float64
  100.times { session.query(workload.sql, workload.params.call(session)) }
  started = Time.instant
  OPS.times { session.query(workload.sql, workload.params.call(session)) } # encoding is part of what is timed
  OPS / (Time.instant - started).total_seconds
end

def median(values : Array(Float64)) : Float64
  values.sort[values.size // 2]
end

stamp = Time.utc(2024, 2, 29, 12, 30, 15, nanosecond: 123_456_000)
id = UUID.new("123e4567-e89b-12d3-a456-426614174000")
numbers = Array.new(1000) { |index| index.to_i64 * 7919 }
words = Array.new(200) { |index| "word-#{index}" }
stamps = Array.new(500) { |index| stamp + index.seconds }
decimals = Array.new(200) { |index| PG::Types::DecimalText.new("#{index}.#{index % 100}25") }

workloads = [
  Workload.new("6 scalars (int8 float8 uuid timestamptz bool numeric)", "SELECT $1::int8, $2::float8, $3::uuid, $4::timestamptz, $5::bool, $6::numeric",
    ->(s : PG::Session) { [s.encode(123456789_i64), s.encode(0.1), s.encode(id), s.encode(stamp), s.encode(true), s.encode(PG::Types::DecimalText.new("12345.678"))] }),
  Workload.new("1 int8", "SELECT $1::int8", ->(s : PG::Session) { [s.encode(123456789_i64)] }),
  Workload.new("1 timestamptz", "SELECT $1::timestamptz", ->(s : PG::Session) { [s.encode(stamp)] }),
  Workload.new("1 numeric", "SELECT $1::numeric", ->(s : PG::Session) { [s.encode(PG::Types::DecimalText.new("12345.678"))] }),
  Workload.new("int8[1000]", "SELECT sum(x) FROM unnest($1::int8[]) x", ->(s : PG::Session) { [s.encode(numbers)] }),
  Workload.new("text[200]", "SELECT count(*) FROM unnest($1::text[]) x", ->(s : PG::Session) { [s.encode(words)] }),
  Workload.new("timestamptz[500]", "SELECT count(*) FROM unnest($1::timestamptz[]) x", ->(s : PG::Session) { [s.encode(stamps)] }),
  Workload.new("numeric[200]", "SELECT sum(x) FROM unnest($1::numeric[]) x", ->(s : PG::Session) { [s.encode(decimals)] }),
  Workload.new("insert 7 columns", "INSERT INTO #{TABLE} VALUES ($1, $2, $3, $4, $5, $6, $7)",
    ->(s : PG::Session) { [s.encode(1_i64), s.encode(stamp), s.encode(PG::Types::DecimalText.new("9.99")), s.encode(id), s.encode(0.5), s.encode(false), s.encode("name")] }),
]

setup = connect(false)
setup.simple_query("DROP TABLE IF EXISTS #{TABLE}")
setup.simple_query("CREATE UNLOGGED TABLE #{TABLE} (id int8, at timestamptz, price numeric, token uuid, ratio float8, ok bool, name text)")

text = connect(false)
binary = connect(true)
puts "server: #{setup.query("SELECT version()").rows.first.first.to_s[0, 60]}"
puts "#{OPS} statements per workload and round, #{ROUNDS} rounds, medians (statements per second)"
puts "%-58s %10s %10s %8s" % {"workload", "text", "binary", "binary/text"}
workloads.each do |workload|
  next if ENV["BENCH_ONLY"]?.try { |only| !workload.name.includes?(only) }
  expected = text.query(workload.sql, workload.params.call(text)).rows.map(&.map(&.to_s))
  actual = binary.query(workload.sql, workload.params.call(binary)).rows.map(&.map(&.to_s))
  abort "#{workload.name}: binary and text results differ: #{expected} vs #{actual}" unless expected == actual
  before = binary.binary_params_sent
  texts, binaries = [] of Float64, [] of Float64
  ROUNDS.times do |round|
    pair = round.even? ? {text, binary} : {binary, text}
    first = timed(pair[0], workload)
    second = timed(pair[1], workload)
    round.even? ? (texts << first; binaries << second) : (binaries << first; texts << second)
  end
  setup.simple_query("TRUNCATE #{TABLE}")
  sent = binary.binary_params_sent > before
  puts "%-58s %10.0f %10.0f %8.2f%s" % {workload.name, median(texts), median(binaries), median(binaries) / median(texts), sent ? "" : "  (no binary form)"}
end
setup.simple_query("DROP TABLE #{TABLE}")
[setup, text, binary].each(&.close)
