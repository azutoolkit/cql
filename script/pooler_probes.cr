require "../src/postgres"

# What the driver does through a connection pooler or proxy sitting in front of PostgreSQL. Environment:
#   POOLER_NAME, POOLER_PORT    for the report (the pooler listens on 127.0.0.1)
#   POOLER_USER, POOLER_PASSWORD  the role to log in with (password may be empty)
#   POOLER_QUERY                extra URL query, e.g. "sslmode=disable" (default)
# Every probe prints PASS or FAIL with what was observed; the exit status is the number of failures. A
# FAIL is a finding about the pooler (or the driver), not necessarily a bug: read the detail.
alias PG = CQL::Postgres

NAME     = ENV["POOLER_NAME"]
PORT     = ENV["POOLER_PORT"].to_i
USER     = ENV["POOLER_USER"]? || "cql"
PASSWORD = ENV["POOLER_PASSWORD"]?.presence
QUERY    = ENV["POOLER_QUERY"]? || "sslmode=disable"

FAILURES = [] of String

def url(extra = "") : String
  credentials = PASSWORD ? "#{USER}:#{PASSWORD}" : USER
  "postgres://#{credentials}@127.0.0.1:#{PORT}/postgres?#{QUERY}#{extra.empty? ? "" : "&#{extra}"}"
end

def session(extra = "") : PG::Session
  PG::Session.connect(PG::Config.parse(url(extra)))
end

def int(value : Int32) : PG::Types::Param
  PG::Types::ParamEncoder.encode(value)
end

PROBE_LIMIT = 20.seconds

# Runs one probe in its own fiber so a pooler that never answers fails the probe instead of hanging the run.
def probe(name : String, &block : -> String?) : Nil
  outcome = Channel(Exception | String?).new(1)
  spawn do
    outcome.send(block.call)
  rescue ex
    outcome.send(ex)
  end
  select
  when result = outcome.receive
    raise result if result.is_a?(Exception)
    puts "PASS  #{name}#{result ? "  (#{result})" : ""}"
  when timeout(PROBE_LIMIT)
    raise "no answer within #{PROBE_LIMIT}"
  end
rescue ex
  FAILURES << name
  puts "FAIL  #{name}  (#{ex.class}: #{ex.message.to_s[0, 160]})"
end

def check(condition : Bool, message : String) : Nil
  raise message unless condition
end

puts "== #{NAME} on 127.0.0.1:#{PORT}"

probe("connects; protocol and cancel key") do
  s = session
  detail = "protocol #{s.protocol_version}, cancel key #{s.secret_key.size} bytes"
  s.close
  detail
end

probe("cached prepared statement, three runs") do
  s = session
  values = Array.new(3) { s.query("SELECT $1::int + 1", [int(1)]).rows.first.first }
  s.close
  check(values == [2, 2, 2], "got #{values}")
  nil
end

probe("two clients, same SQL, interleaved (statement names shared on one server connection)") do
  a = session
  b = session
  begin
    values = [a, b, a, b].map { |client| client.query("SELECT $1::int + 1", [int(1)]).rows.first.first }
    check(values == [2, 2, 2, 2], "got #{values}")
    nil
  ensure
    a.close
    b.close
  end
end

probe("unnamed statements (statement_cache_size=0), two clients interleaved") do
  a = session("statement_cache_size=0")
  b = session("statement_cache_size=0")
  begin
    values = [a, b, a, b].map { |client| client.query("SELECT $1::int + 1", [int(1)]).rows.first.first }
    check(values == [2, 2, 2, 2], "got #{values}")
    nil
  ensure
    a.close
    b.close
  end
end

probe("pipeline of 5 statements") do
  s = session
  begin
    results = s.pipeline((1..5).map { |number| {"SELECT $1::int", [int(number)]} })
    check(results.size == 5 && results.none?(PG::ServerError), "got #{results.map(&.class)}")
    nil
  ensure
    s.close
  end
end

probe("SET LOCAL stays inside its transaction") do
  s = session("statement_cache_size=0")
  begin
    s.simple_query("BEGIN; SET LOCAL statement_timeout = 1234")
    inside = s.query("SHOW statement_timeout").rows
    s.simple_query("COMMIT")
    after = s.query("SHOW statement_timeout").rows
    check(inside == [["1234ms"]] && after == [["0"]], "inside #{inside}, after #{after}")
    nil
  ensure
    s.close
  end
end

probe("statement timeout cancels through the pooler and the session keeps working") do
  s = session
  begin
    s.cancel_grace = 2.seconds
    started = Time.instant
    begin
      s.query("SELECT pg_sleep(10)", timeout: 400.milliseconds)
      raise "the statement was not cancelled"
    rescue PG::QueryTimeout
    end
    elapsed = (Time.instant - started).total_milliseconds.round
    alive = !s.closed? && s.query("SELECT 7").rows == [[7]]
    "timed out after #{elapsed} ms; session #{alive ? "kept" : "dropped (cancel not confirmed)"}"
  ensure
    s.close
  end
end

probe("streaming 2000 rows 100 at a time, then stopping early") do
  s = session
  begin
    count = s.stream("SELECT g::int4 FROM generate_series(1, 2000) g", fetch_size: 100) { |rows| rows.to_a.size }
    early = s.stream("SELECT g::int4 FROM generate_series(1, 2000) g", fetch_size: 100) { |rows| rows.first(5).to_a.size }
    after = s.query("SELECT 1").rows
    check(count == 2000 && early == 5 && after == [[1]], "count #{count}, early #{early}, after #{after}")
    nil
  ensure
    s.close
  end
end

probe("transaction with a savepoint through AsyncEngine") do
  engine = PG::AsyncEngine.connect(url("pool_size=1&statement_cache_size=0"))
  begin
    result = engine.transaction do |tx|
      tx.exec_query(&.scalar("SELECT 1")).as(Int32) + (tx.savepoint { |inner| inner.exec_query(&.scalar("SELECT 2")).as(Int32) } || 0)
    end
    check(result == 3, "got #{result}")
    nil
  ensure
    engine.close
  end
end

puts FAILURES.empty? ? "== #{NAME}: all probes passed" : "== #{NAME}: #{FAILURES.size} probe(s) failed"
exit FAILURES.size
