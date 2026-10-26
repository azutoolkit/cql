require "../spec_helper"
require "../../src/postgres"

describe CQL::Postgres::Auth::ScramSha256 do
  # RFC 7677 section 3 test vector.
  it "reproduces the RFC 7677 client proof and verifies the server signature" do
    scram = CQL::Postgres::Auth::ScramSha256.new("pencil", nonce: "rOprNGfwEbeRWgbNEkqO", username: "user")
    String.new(scram.initial_response).should eq "n,,n=user,r=rOprNGfwEbeRWgbNEkqO"

    server_first = "r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=4096"
    String.new(scram.continue(server_first.to_slice)).should eq(
      "c=biws,r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0,p=dHzbZapWIk4jUhN+Ute9ytag9zjfMHgsqmmiz7AndVQ="
    )
    scram.verify("v=6rriTRBi23WpRR/wtup+mMhUZUn/dB5nLTJRsjl95G4=".to_slice)
  end

  it "refuses a server-final message before the exchange started, even an empty signature" do
    scram = CQL::Postgres::Auth::ScramSha256.new("pw")
    scram.verified?.should be_false
    expect_raises(CQL::Postgres::AuthenticationError, /before the exchange/) { scram.verify("v=".to_slice) }
  end

  it "answers the server-first message only once" do
    scram = CQL::Postgres::Auth::ScramSha256.new("pencil", nonce: "rOprNGfwEbeRWgbNEkqO", username: "user")
    first = "r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=4096".to_slice
    scram.continue(first)
    expect_raises(CQL::Postgres::AuthenticationError, /already handled/) { scram.continue(first) }
  end

  it "marks the exchange verified only after a matching signature" do
    scram = CQL::Postgres::Auth::ScramSha256.new("pencil", nonce: "rOprNGfwEbeRWgbNEkqO", username: "user")
    scram.continue("r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=4096".to_slice)
    expect_raises(CQL::Postgres::AuthenticationError) { scram.verify("v=".to_slice) }
    scram.verified?.should be_false
    scram.verify("v=6rriTRBi23WpRR/wtup+mMhUZUn/dB5nLTJRsjl95G4=".to_slice)
    scram.verified?.should be_true
  end

  it "reports malformed base64 from the server as an authentication failure" do
    scram = CQL::Postgres::Auth::ScramSha256.new("pw", nonce: "client")
    expect_raises(CQL::Postgres::AuthenticationError, /base64/) { scram.continue("r=clientX,s=!!!,i=4096".to_slice) }
  end

  it "does not show the password when inspected" do
    CQL::Postgres::Auth::ScramSha256.new("hunter2").inspect.should_not contain "hunter2"
  end

  it "normalises the password like the server does, so composed and decomposed forms agree" do
    accepted = nil
    server = FakePG.start do |client|
      client.read_startup
      client.auth(10, "SCRAM-SHA-256\0\0".to_slice)
      accepted = FakeScramServer.new("caf\u00E9").run(client)
      client.ok_handshake
    end
    config = CQL::Postgres::Config.parse(server.url(password: "cafe\u0301"))
    io = CQL::Postgres::Transport.connect(config)
    CQL::Postgres::Handshake.new(config, io).run
    io.close
    accepted.should be_true
  end

  it "uses an empty user name and a random nonce by default" do
    first = String.new(CQL::Postgres::Auth::ScramSha256.new("pw").initial_response)
    first.should match(/\An,,n=,r=[A-Za-z0-9+\/]{24}\z/)
  end

  it "rejects a server nonce that does not extend ours" do
    scram = CQL::Postgres::Auth::ScramSha256.new("pw", nonce: "client")
    expect_raises(CQL::Postgres::AuthenticationError, /nonce/) { scram.continue("r=other,s=c2FsdA==,i=4096".to_slice) }
  end

  it "rejects missing or unreasonable iteration counts" do
    scram = CQL::Postgres::Auth::ScramSha256.new("pw", nonce: "client")
    expect_raises(CQL::Postgres::AuthenticationError, /iteration/) { scram.continue("r=clientX,s=c2FsdA==".to_slice) }
    expect_raises(CQL::Postgres::AuthenticationError, /iteration/) { scram.continue("r=clientX,s=c2FsdA==,i=1000001".to_slice) }
    expect_raises(CQL::Postgres::AuthenticationError, /iteration/) { scram.continue("r=clientX,s=c2FsdA==,i=0".to_slice) }
  end

  it "rejects a forged or error server-final message" do
    scram = CQL::Postgres::Auth::ScramSha256.new("pencil", nonce: "rOprNGfwEbeRWgbNEkqO", username: "user")
    scram.continue("r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=4096".to_slice)
    expect_raises(CQL::Postgres::AuthenticationError, /does not match/) { scram.verify("v=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=".to_slice) }
    expect_raises(CQL::Postgres::AuthenticationError, /invalid-proof/) { scram.verify("e=invalid-proof".to_slice) }
  end
end

describe CQL::Postgres::Auth::MD5Password do
  # Expected value computed independently with Python's hashlib:
  # "md5" + md5(md5("secretpostgres").hexdigest() + bytes([1, 2, 3, 4])).hexdigest()
  it "hashes password, user and salt the way PostgreSQL expects" do
    CQL::Postgres::Auth::MD5Password.digest("postgres", "secret", Bytes[1, 2, 3, 4]).should eq "md5bb41a296aab6baccb36ff243a562abff"
  end
end

describe CQL::Postgres::Config do
  it "parses a TCP URL with percent-encoded credentials" do
    config = CQL::Postgres::Config.parse("postgres://ada:p%40ss@db.example.com:6543/app?sslmode=require&application_name=svc&connect_timeout=3&statement_cache_size=8&search_path=public")
    {config.host, config.port, config.user, config.database}.should eq({"db.example.com", 6543, "ada", "app"})
    config.password_for_authentication.should eq "p@ss"
    {config.ssl_mode, config.application_name, config.connect_timeout, config.statement_cache_size}.should eq({CQL::Postgres::SSLMode::Require, "svc", 3.seconds, 8})
    config.startup_parameters.should eq({"search_path" => "public", "user" => "ada", "database" => "app", "client_encoding" => "UTF8", "application_name" => "svc"})
  end

  it "drops auth_methods, written for the pg shard, instead of sending it as a startup parameter" do
    config = CQL::Postgres::Config.parse("postgres://ada@h/app?auth_methods=cleartext,md5,scram-sha-256&search_path=public")
    config.startup_parameters.has_key?("auth_methods").should be_false
    config.startup_parameters["search_path"].should eq "public"
  end

  it "reads the crystal-db pool keys full_db_url adds: sizes become pool options, the rest is dropped" do
    configuration = CQL::Configure::Config.new
    configuration.db = "postgres://ada@h/app?search_path=public"
    configuration.pool.size = 7
    configuration.pool.initial_size = 2
    config = CQL::Postgres::Config.parse(configuration.full_db_url)

    {config.driver_options["pool_size"]?, config.driver_options["pool_min_size"]?}.should eq({"7", "2"})
    config.startup_options.should eq({"search_path" => "public"})
  end

  it "lets the engine's own pool keys win over crystal-db's" do
    config = CQL::Postgres::Config.parse("postgres://ada@h/app?max_pool_size=20&pool_size=5&initial_pool_size=3&pool_min_size=1")
    {config.driver_options["pool_size"]?, config.driver_options["pool_min_size"]?}.should eq({"5", "1"})
    config.startup_options.should be_empty
  end

  it "drops prepared_statements_cache, which the engine replaces with statement_cache_size" do
    CQL::Postgres::Config.parse("postgres://ada@h/app?prepared_statements_cache=true").startup_options.should be_empty
  end

  it "decodes credentials once, so `+` and encoded percent signs survive" do
    CQL::Postgres::Config.parse("postgres://ada:a+b@h/db").password_for_authentication.should eq "a+b"
    CQL::Postgres::Config.parse("postgres://ada:p%2540x@h/db").password_for_authentication.should eq "p%40x"
    CQL::Postgres::Config.parse("postgres://a%2Bb:pw@h/db").user.should eq "a+b"
  end

  it "takes the port from the query when given there and never forwards it to the server" do
    config = CQL::Postgres::Config.parse("postgres://ada@h:5000/db?port=5001")
    config.port.should eq 5001
    config.startup_options.should be_empty
  end

  it "refuses query keys that would override the connection's identity or are not supported" do
    {"user" => "evil", "database" => "other", "client_encoding" => "SQL_ASCII", "replication" => "database"}.each do |key, value|
      expect_raises(ArgumentError, /#{key} cannot be set/) { CQL::Postgres::Config.parse("postgres://h/db?#{key}=#{value}") }
    end
    expect_raises(ArgumentError, /sslmod/) { CQL::Postgres::Config.parse("postgres://h/db?sslmod=verify-full") }
    expect_raises(ArgumentError, /sslcert/) { CQL::Postgres::Config.parse("postgres://h/db?sslcert=/x.pem") }
    expect_raises(ArgumentError, /require_auth/) { CQL::Postgres::Config.parse("postgres://h/db?require_auth=scram-sha-256") }
  end

  it "decodes query values by percent only, so a plus stays a plus" do
    config = CQL::Postgres::Config.parse("postgres://h/db?application_name=my+app&search_path=a%2Cb&sslmode=verify-full&sslrootcert=/ca+1.pem")
    config.application_name.should eq "my+app"
    config.startup_options["search_path"].should eq "a,b"
    config.ssl_root_cert.should eq "/ca+1.pem"
  end

  it "refuses credentials and libpq aliases in the query rather than sending them to the server" do
    {"password", "dbname", "hostaddr"}.each do |key|
      expect_raises(ArgumentError, /#{key} cannot be set/) { CQL::Postgres::Config.parse("postgres://h/db?#{key}=x") }
    end
  end

  it "accepts sslrootcert only where the server is verified" do
    expect_raises(ArgumentError, /sslrootcert needs sslmode=verify-full/) { CQL::Postgres::Config.parse("postgres://h/db?sslmode=require&sslrootcert=/ca.pem") }
    expect_raises(ArgumentError, /sslrootcert needs/) { CQL::Postgres::Config.parse("postgres://h/db?sslrootcert=/ca.pem") }
  end

  it "rejects non-finite timeouts" do
    {"inf", "nan"}.each do |value|
      expect_raises(ArgumentError, /connect_timeout/) { CQL::Postgres::Config.parse("postgres://h/db?connect_timeout=#{value}") }
    end
  end

  it "rejects numbers it cannot read and other URL schemes" do
    expect_raises(ArgumentError, /port must be/) { CQL::Postgres::Config.parse("postgres://h/db?port=abc") }
    expect_raises(ArgumentError, /connect_timeout/) { CQL::Postgres::Config.parse("postgres://h/db?connect_timeout=soon") }
    expect_raises(ArgumentError, /statement_cache_size/) { CQL::Postgres::Config.parse("postgres://h/db?statement_cache_size=big") }
    expect_raises(ArgumentError, /scheme/) { CQL::Postgres::Config.parse("mysql://h/db") }
    CQL::Postgres::Config.parse("cockroachdb://h/db").host.should eq "h"
  end

  it "treats a zero connect_timeout as no limit" do
    CQL::Postgres::Config.parse("postgres://h/db?connect_timeout=0").connect_timeout.should be_nil
    CQL::Postgres::Config.parse("postgres://h/db").connect_timeout.should eq 10.seconds
  end

  it "keeps the driver's own settings out of the startup parameters sent to the server" do
    config = CQL::Postgres::Config.parse("postgres://ada@h/app?pool_size=3&checkout_timeout=1.5&health_check_after=9&search_path=public")
    config.driver_options.should eq({"pool_size" => "3", "checkout_timeout" => "1.5", "health_check_after" => "9"})
    config.startup_options.should eq({"search_path" => "public"})
  end

  it "defaults the database to the user and supports Unix socket directories" do
    config = CQL::Postgres::Config.parse("postgres://ada@/?host=/var/run/postgresql&port=5433")
    config.database.should eq "ada"
    config.unix_socket?.should be_true
    config.socket_path.should eq "/var/run/postgresql/.s.PGSQL.5433"
  end

  it "never prints the password" do
    config = CQL::Postgres::Config.parse("postgres://ada:hunter2@localhost/app")
    config.inspect.should_not contain "hunter2"
    config.to_s.should_not contain "hunter2"
  end

  it "reports a missing password only when one is demanded" do
    expect_raises(CQL::Postgres::AuthenticationError, /password/) { CQL::Postgres::Config.new(password: nil).password_for_authentication }
  end

  it "rejects unsupported sslmode values" do
    expect_raises(ArgumentError, /sslmode/) { CQL::Postgres::Config.parse("postgres://h/db?sslmode=verify-ca") }
  end
end
