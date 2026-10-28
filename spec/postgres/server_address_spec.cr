require "../spec_helper"
require "../support/fake_pg_server"
require "../../src/postgres"

private alias PG = CQL::Postgres

private PASSWORD = "s3cr3t-pw"
# URI.parse splits the user info at its first '@', which would put this tail in the host.
private AT_TAIL     = "SECRETTAIL"
private AT_PASSWORD = "pa@#{AT_TAIL}"

# A port nothing listens on: bound, read, then released.
private def refused_url(query = "", password = PASSWORD) : String
  server = TCPServer.new("127.0.0.1", 0)
  port = server.local_address.port
  server.close
  "postgres://ada:#{password}@127.0.0.1:#{port}/app?sslmode=disable#{query}"
end

private def names_server(error : Exception, address : String) : Nil
  chain = [error.message.to_s, error.cause.try(&.message).to_s].join(" | ")
  chain.should contain address
  chain.should_not contain PASSWORD
  chain.should_not contain AT_TAIL
end

describe "PostgreSQL connection errors name the server" do
  {PASSWORD, AT_PASSWORD}.each do |password|
    it "names host:port, not the password #{password}, when a checkout times out" do
      server = FakePG.start { |client| client.read_startup; client.ok_handshake; client.idle { |_| } }
      pool = PG::Pool.new(PG::Config.parse(server.url(password: password, query: "sslmode=disable&pool_size=1&checkout_timeout=0.05")))
      held = pool.checkout
      names_server(expect_raises(PG::PoolTimeout) { pool.checkout }, "127.0.0.1:#{server.port}")
      held.release
      pool.close
    end

    it "names host:port, not the password #{password}, when the engine cannot connect" do
      url = refused_url("&pool_min_size=1", password)
      address = url[/127\.0\.0\.1:\d+/]
      names_server(expect_raises(IO::Error) { PG::AsyncEngine.connect(url) }, address)
      names_server(expect_raises(DB::ConnectionRefused) { PG::EngineSource.connect(url) }, address)
    end
  end

  it "brackets an IPv6 host so its port reads apart from it" do
    PG::Config.parse("postgres://ada@[::1]:5433/app").address.should eq "[::1]:5433"
  end

  it "names host:port, not the password, when DB.open on the native driver cannot connect" do
    url = refused_url
    uri = URI.parse(url)
    driver = PG::Driver.new
    builder = driver.connection_builder(uri)
    error = expect_raises(DB::ConnectionRefused) do
      DB::Database.new(driver.connection_options(HTTP::Params.new), driver.pool_options(HTTP::Params.new)) { builder.build }
    end
    names_server(error, "127.0.0.1:#{uri.port}")
  end

  it "names the socket path of a Unix-socket URL" do
    directory = "/nonexistent-cql-#{Random::Secure.hex(4)}"
    url = "postgres://ada:#{PASSWORD}@/app?host=#{directory}&port=5433&pool_min_size=1"
    names_server(expect_raises(IO::Error) { PG::AsyncEngine.connect(url) }, "#{directory}/.s.PGSQL.5433")
  end
end

describe "A password with an unencoded '@'" do
  it "authenticates whole, and the host is read after the last '@'" do
    config = PG::Config.parse("postgres://ada:#{AT_PASSWORD}@127.0.0.1:5433/app")
    {config.host, config.address, config.password_for_authentication}.should eq({"127.0.0.1", "127.0.0.1:5433", AT_PASSWORD})
    {config.to_s, config.inspect}.join.should_not contain AT_TAIL
    PG::Config.parse("postgres://ada:#{AT_PASSWORD}@[::1]:5433/app").address.should eq "[::1]:5433"
    PG::Config.parse("postgres://ada:#{AT_PASSWORD}@%2Fsock%40dir/app").address.should eq "/sock@dir/.s.PGSQL.5432"
  end

  it "is refused, never echoed, in a URI already split at its first '@' (DB.open's)" do
    uri = URI.parse("postgres://ada:#{AT_PASSWORD}@127.0.0.1:5433/app")
    error = expect_raises(ArgumentError, "write an '@' in the password as %40") { PG::Config.from_uri(uri) }
    error.message.to_s.should_not contain AT_TAIL
    PG::Config.from_uri(URI.parse("postgres://ada:pw@%2Fsock%40dir/app")).address.should eq "/sock@dir/.s.PGSQL.5432"
  end

  it "takes user info only from the authority right after the scheme" do
    config = PG::Config.parse("postgres:app?application_name=http://u:pw@h")
    config.application_name.should eq "http://u:pw@h"
  end
end
