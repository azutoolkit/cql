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
