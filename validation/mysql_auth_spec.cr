require "spec"
require "../src/cql/mysql"

# No pending paths: script/mysql84-fixture provisions a verified TLS server and
# clears its authentication cache before this file executes.
MYSQL_AUTH_URL = ENV.fetch("CQL_ENTERPRISE_URL")
MYSQL_AUTH_CA  = ENV.fetch("CQL_MYSQL_CA")

private def mysql_variant(host : String? = nil, password : String? = nil, ca : String? = nil, mode = "verify_identity") : String
  uri = URI.parse(MYSQL_AUTH_URL)
  uri.host = host if host
  uri.password = password if password
  params = uri.query_params
  params["ssl-mode"] = mode
  params["ssl-ca"] = ca || MYSQL_AUTH_CA
  uri.query = params.to_s
  uri.to_s
end

describe "MySQL 8.4 default authentication over verified TLS" do
  it "authenticates cold and warm connections and executes bound queries" do
    2.times do
      DB.open(MYSQL_AUTH_URL) do |db|
        db.scalar("SELECT VERSION()").as(String).should start_with "8.4."
        db.query_one("SHOW SESSION STATUS LIKE 'Ssl_cipher'", as: {String, String})[1].should_not be_empty
        db.scalar("SELECT @@require_secure_transport").should eq 1_i64
        db.query_one("SELECT CAST(? AS SIGNED), CAST(? AS CHAR)", 42_i64, "bound", as: {Int64, String}).should eq({42_i64, "bound"})
      end
    end
  end

  it "rejects wrong passwords without including the password in the error" do
    error = expect_raises(CQL::MySQL::AuthenticationError) { DB.open(mysql_variant(password: "wrong-password")).close }
    error.message.to_s.should_not contain "wrong-password"
  end

  it "rejects an untrusted CA" do
    uri = URI.parse(MYSQL_AUTH_URL)
    uri.query = "ssl-mode=verify_identity"
    expect_raises(OpenSSL::SSL::Error) { DB.open(uri.to_s).close }
  end

  it "rejects a trusted certificate for the wrong hostname" do
    expect_raises(OpenSSL::SSL::Error) { DB.open(mysql_variant(host: "localhost")).close }
  end

  it "rejects plaintext transport when the server requires TLS" do
    expect_raises(CQL::MySQL::AuthenticationError) { DB.open(mysql_variant(mode: "disabled")).close }
  end

  it "reuses verified connections under concurrent pool contention" do
    DB.open(MYSQL_AUTH_URL + "&max_pool_size=3&initial_pool_size=1") do |db|
      results = Channel(Exception?).new(16)
      16.times do
        spawn do
          error = begin
            10.times { db.query_one("SELECT CAST(? AS SIGNED)", 7_i64, as: Int64).should eq 7_i64 }
            nil
          rescue ex
            ex
          end
          results.send(error)
        end
      end
      16.times do
        if error = results.receive
          raise error
        end
      end
    end
  end
end
