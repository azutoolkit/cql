require "../spec_helper"
require "../support/fake_pg_server"
require "../../src/postgres"

private alias PG = CQL::Postgres

private def build_through_driver(url : String) : DB::Connection
  PG::Driver.new.connection_builder(URI.parse(url)).build
end

describe CQL::Postgres::Driver do
  it "opens connections for crystal-db, keeping its pool options out of the startup packet and the password intact" do
    startup = nil
    sent = nil
    server = FakePG.start do |client|
      startup = client.read_startup
      client.auth(3)
      sent = client.cstrings(client.expect('p'))
      client.ok_handshake
      client.idle
    end
    url = "postgres://ada:p%2Bw%40%3A%25@127.0.0.1:#{server.port}/app?sslmode=disable&max_pool_size=3&initial_pool_size=1&checkout_timeout=2&prepared_statements_cache=false&application_name=cql_driver"
    connection = build_through_driver(url)
    connection.should be_a PG::Connection
    sent.not_nil!.first.should eq "p+w@:%"
    startup.not_nil!["application_name"].should eq "cql_driver"
    startup.not_nil!.keys.select(&.includes?("pool")).should be_empty
    connection.close
  end

  it "keeps spaces in credentials intact and sends no crystal-db options" do
    startup = nil
    sent = nil
    server = FakePG.start do |client|
      startup = client.read_startup
      client.auth(3)
      sent = client.cstrings(client.expect('p'))
      client.ok_handshake
      client.idle
    end
    build_through_driver("postgres://a%20b:p%20w%2B1@127.0.0.1:#{server.port}/app?sslmode=disable&max_pool_size=2").close
    sent.not_nil!.first.should eq "p w+1"
    startup.not_nil!["user"].should eq "a b"
    startup.not_nil!.keys.to_set.should eq Set{"application_name", "client_encoding", "database", "protocol", "user"}
    #  ["application_name", "client_encoding", "database", "protocol", "user"]
  end

  it "accepts the auth_methods option written for the pg shard without sending it to the server" do
    startup = nil
    server = FakePG.start do |client|
      startup = client.read_startup
      client.auth(3)
      client.cstrings(client.expect('p'))
      client.ok_handshake
      client.idle
    end
    build_through_driver("postgres://a:b@127.0.0.1:#{server.port}/app?sslmode=disable&auth_methods=scram-sha-256%2Cmd5").close
    startup.not_nil!.has_key?("auth_methods").should be_false
  end

  it "refuses pool_reset, since crystal-db's pool cannot reset a connection, and points to EngineSource" do
    expect_raises(ArgumentError, /EngineSource/) { build_through_driver("postgres://localhost:1/db?pool_reset=discard_all") }
  end

  it "reports a refused or unreachable server as DB::ConnectionRefused, which crystal-db retries, but not a server error" do
    closed = TCPServer.new("127.0.0.1", 0)
    closed_port = closed.local_address.port
    closed.close
    builder = PG::Driver.new.connection_builder(URI.parse("postgres://u@127.0.0.1:#{closed_port}/db?sslmode=disable"))
    expect_raises(DB::ConnectionRefused) { builder.build }

    hung_up = FakePG.start(&.read_startup)
    expect_raises(DB::ConnectionRefused) { PG::Driver.new.connection_builder(URI.parse("postgres://u@127.0.0.1:#{hung_up.port}/db?sslmode=disable")).build }

    rejecting = FakePG.start do |client|
      client.read_startup
      client.error("28000", "no", {'S' => "FATAL", 'V' => "FATAL"})
    end
    refused = PG::Driver.new.connection_builder(URI.parse("postgres://u@127.0.0.1:#{rejecting.port}/db?sslmode=disable"))
    expect_raises(PG::InvalidAuthorization) { refused.build }
  end

  it "leaves the cockroachdb name alone until it is opted in" do
    before = PG::Driver.registered?("cockroachdb")
    PG::Driver.register
    PG::Driver.registered?("cockroachdb").should eq before
    PG::Driver::NAMES.should eq({"postgres", "postgresql"})
  end

  it "opens through crystal-db's registry and pool for cockroachdb:// URLs once opted in" do
    PG::Driver.register_cockroachdb
    accepted = 0
    server = FakePG.start do |client|
      accepted += 1
      client.read_startup
      client.ok_handshake
      client.idle
    end
    DB.driver_class("cockroachdb").should eq PG::Driver
    DB.open("cockroachdb://root@127.0.0.1:#{server.port}/defaultdb?sslmode=disable&initial_pool_size=1&max_pool_size=2") do |database|
      database.checkout.should be_a PG::Connection
    end
    accepted.should eq 1
  end

  it "does not claim a name that is already registered" do
    PG::Driver.registered?("no_such_driver").should be_false
    PG::Driver.registered?("postgres").should be_true
  end
end
