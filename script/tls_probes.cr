require "../src/postgres"

# Probes the driver's TLS behaviour against real servers (see script/tls-probes). Environment:
#   TLS_PG_PORT, TLS_CA     a PostgreSQL with `hostssl` only and a certificate for the name `localhost`
#   NOTLS_PG_PORT           a PostgreSQL without TLS (user cql, trust)
#   CRDB_PORT, CRDB_CA      optional: a secure CockroachDB (user cql_pw, password secret, database cql_wire)
# Each probe prints PASS or FAIL; the exit status is the number of failures.
alias PG = CQL::Postgres

# Forwards every TCP connection to the target and counts them, so a probe can tell how many connection
# attempts a pool made.
class CountingProxy
  getter port : Int32
  getter accepted = Atomic(Int32).new(0)

  def initialize(@target_port : Int32)
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.local_address.port
    spawn do
      while client = @server.accept?
        @accepted.add(1)
        spawn forward(client)
      end
    end
  end

  def close : Nil
    @server.close
  end

  private def forward(client : TCPSocket) : Nil
    upstream = TCPSocket.new("127.0.0.1", @target_port)
    spawn { IO.copy(client, upstream) rescue nil; upstream.close rescue nil }
    IO.copy(upstream, client) rescue nil
    client.close rescue nil
  rescue IO::Error
    client.close rescue nil
  end
end

FAILURES = [] of String

def probe(name : String, &) : Nil
  detail = yield
  puts "PASS  #{name}#{detail ? "  (#{detail})" : ""}"
rescue ex
  FAILURES << name
  puts "FAIL  #{name}  (#{ex.class}: #{ex.message})"
end

def connect(url : String) : PG::Session
  PG::Session.connect(PG::Config.parse(url))
end

def refused_with(url : String, pattern : Regex) : String
  connect(url).close
  raise "connected, but TLS should have been refused"
rescue ex : PG::TLSRefused
  raise "wrong message: #{ex.message}" unless ex.message.to_s.matches?(pattern)
  ex.message.to_s
end

# How many connections crystal-db's pool opens for one `db.scalar` with retry_attempts=3 (the retry loop lives
# in the query path, not in `checkout`).
def pool_attempts(target_port : Int32, host : String, query : String) : {Int32, Exception?}
  proxy = CountingProxy.new(target_port)
  error = nil
  begin
    DB.open("postgres://cql@#{host}:#{proxy.port}/postgres?#{query}&initial_pool_size=0&retry_attempts=3&retry_delay=0.01") { |pool| pool.scalar("SELECT 1") }
  rescue ex
    error = ex
  end
  sleep 100.milliseconds
  attempts = proxy.accepted.get
  proxy.close
  {attempts, error}
end

tls_port = ENV["TLS_PG_PORT"].to_i
tls_ca = ENV["TLS_CA"]
notls_port = ENV["NOTLS_PG_PORT"].to_i
url = ->(port : Int32, host : String, query : String) { "postgres://cql@#{host}:#{port}/postgres?#{query}" }

puts "TLS PostgreSQL: #{connect(url.call(tls_port, "localhost", "sslmode=require")).tap(&.close).server_parameters["server_version"]}  |  plain PostgreSQL: #{connect(url.call(notls_port, "127.0.0.1", "sslmode=disable")).tap(&.close).server_parameters["server_version"]}"

probe("sslmode=require against a server without TLS -> TLSRefused 'does not support TLS'") do
  refused_with(url.call(notls_port, "127.0.0.1", "sslmode=require"), /does not support TLS/)
end

probe("sslmode=prefer against a server without TLS falls back to plaintext") do
  session = connect(url.call(notls_port, "127.0.0.1", "sslmode=prefer"))
  raise "unexpected rows" unless session.query("SELECT 1").rows == [[1]]
  session.close
  nil
end

probe("sslmode=require against a TLS server connects (certificate not verified)") do
  connect(url.call(tls_port, "localhost", "sslmode=require")).close
  nil
end

probe("sslmode=verify-full with the server's certificate as CA connects for the name in the certificate") do
  connect(url.call(tls_port, "localhost", "sslmode=verify-full&sslrootcert=#{tls_ca}")).close
  nil
end

probe("sslmode=verify-full with the CA but the wrong host name -> TLSRefused") do
  refused_with(url.call(tls_port, "127.0.0.1", "sslmode=verify-full&sslrootcert=#{tls_ca}"), /TLS to .* failed/)
end

probe("sslmode=verify-full without the CA (self-signed certificate) -> TLSRefused 'certificate verify failed'") do
  refused_with(url.call(tls_port, "localhost", "sslmode=verify-full"), /certificate verify failed/)
end

probe("sslmode=prefer against a TLS server uses TLS") do
  session = connect(url.call(tls_port, "localhost", "sslmode=prefer"))
  session.close
  nil
end

{ {"sslmode=require against a server without TLS", notls_port, "localhost", "sslmode=require"},
 {"verify-full with the wrong host name", tls_port, "127.0.0.1", "sslmode=verify-full&sslrootcert=#{tls_ca}"},
 {"verify-full without the CA", tls_port, "localhost", "sslmode=verify-full"} }.each do |name, port, host, query|
  probe("crystal-db's pool does not retry: #{name}") do
    attempts, error = pool_attempts(port, host, query)
    raise "expected the TLSRefused error to reach the caller, got #{error.inspect}" unless error.is_a?(PG::TLSRefused)
    raise "#{attempts} connection attempts, expected 1" unless attempts == 1
    "1 connection attempt, #{error.class}"
  end
end

probe("control: the pool DOES retry a transport failure (server that hangs up)") do
  hang_up = TCPServer.new("127.0.0.1", 0)
  accepted = Atomic(Int32).new(0)
  spawn do
    while client = hang_up.accept?
      accepted.add(1)
      client.close
    end
  end
  error = nil
  begin
    DB.open("postgres://cql@127.0.0.1:#{hang_up.local_address.port}/postgres?sslmode=disable&initial_pool_size=0&retry_attempts=3&retry_delay=0.01") { |pool| pool.scalar("SELECT 1") }
  rescue ex
    error = ex
  end
  sleep 100.milliseconds
  hang_up.close
  # one pool attempt is two connections here (the 3.2 startup, then the 3.0 fallback)
  raise "expected the pool to retry, saw #{accepted.get} connection(s) (#{error.inspect})" unless accepted.get > 2
  "#{accepted.get} connection attempts, #{error.try(&.class)}"
end

if (crdb_port = ENV["CRDB_PORT"]?) && (crdb_ca = ENV["CRDB_CA"]?)
  secure = ->(query : String) { "postgres://cql_pw:secret@localhost:#{crdb_port}/cql_wire?#{query}" }
  probe("CockroachDB: verify-full without the CA -> TLSRefused 'certificate verify failed'") do
    refused_with(secure.call("sslmode=verify-full"), /certificate verify failed/)
  end
  probe("CockroachDB: verify-full with the CA connects") do
    session = connect(secure.call("sslmode=verify-full&sslrootcert=#{crdb_ca}"))
    version = session.query("SELECT version()").rows.first.first.to_s[0, 40]
    session.close
    version
  end
end

puts FAILURES.empty? ? "all probes passed" : "#{FAILURES.size} probe(s) failed"
exit FAILURES.size
