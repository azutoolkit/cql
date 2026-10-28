require "../spec_helper"
require "../support/fake_pg_server"
require "../../src/postgres"

describe "native pool shutdown during connection establishment" do
  [false, true].each do |warming|
    it "refuses a connection completed after close (warm_up=#{warming})" do
      entered = Channel(Nil).new(1)
      resume = Channel(Nil).new(1)
      server = FakePG.start do |client|
        client.read_startup
        entered.send(nil)
        resume.receive
        client.ok_handshake
        client.idle { |_| }
      end
      config = CQL::Postgres::Config.parse(server.url(query: "sslmode=disable"))
      pool = CQL::Postgres::Pool.new(config, CQL::Postgres::Pool::Options.new(min_size: 1))
      outcome = Channel(Exception?).new(1)
      spawn do
        warming ? pool.warm_up : pool.checkout
        outcome.send(nil)
      rescue ex
        outcome.send(ex)
      end
      select
      when entered.receive
      when timeout(2.seconds) then fail "connection did not reach handshake"
      end
      pool.close
      resume.send(nil)
      select
      when error = outcome.receive
        error.should be_a(CQL::Postgres::PoolClosed)
      when timeout(2.seconds) then fail "checkout did not finish after close"
      end
      pool.stats.should eq CQL::Postgres::Pool::Stats.new(10, 0, 0)
    ensure
      pool.try(&.close)
      server.try(&.close)
    end
  end
end
