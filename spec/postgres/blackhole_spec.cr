require "../spec_helper"
require "../support/blackhole_proxy"
require "../../src/postgres"

# Real PostgreSQL behind a proxy that turns into a TCP black hole. Needs a TLS-enabled server, e.g. the one
# script/tls-probes starts; set CQL_TLS_PG_PORT to its port (user cql, trust, `hostssl` only).
private alias PG = CQL::Postgres

private def tls_port : Int32?
  ENV["CQL_TLS_PG_PORT"]?.try(&.to_i?)
end

private def open_descriptors : Int32
  Dir.children("/proc/self/fd").size
end

private def through(proxy : BlackholeProxy) : PG::Session
  PG::Session.connect(PG::Config.parse("postgres://cql@127.0.0.1:#{proxy.port}/postgres?sslmode=require&connect_timeout=2"))
end

describe "a TLS connection over a path that goes silent" do
  it "fails a request parked in SSL_read within timeout plus grace, and releases the descriptors, 50 times" do
    port = tls_port
    pending! "set CQL_TLS_PG_PORT (see script/tls-probes)" unless port
    pending! "needs /proc/self/fd" unless Dir.exists?("/proc/self/fd")
    before = open_descriptors
    slowest = 0.seconds
    50.times do
      proxy = BlackholeProxy.new(port)
      session = through(proxy)
      begin
        session.cancel_grace = 200.milliseconds
        spawn do
          sleep 100.milliseconds
          proxy.blackhole!
        end
        started = Time.instant
        expect_raises(PG::QueryTimeout) { session.query("SELECT pg_sleep(5)", timeout: 300.milliseconds) }
        elapsed = Time.instant - started
        slowest = elapsed if elapsed > slowest
        elapsed.should be < 3.seconds
        session.closed?.should be_true
      ensure
        session.close
        proxy.close
      end
    end
    sleep 200.milliseconds
    (open_descriptors - before).should be <= 2
    puts "  slowest of 50: #{slowest.total_milliseconds.round}ms; descriptors before #{before}, after #{open_descriptors}"
  end

  it "fails a ping on an idle connection within its timeout, and releases the descriptors, 50 times" do
    port = tls_port
    pending! "set CQL_TLS_PG_PORT (see script/tls-probes)" unless port
    pending! "needs /proc/self/fd" unless Dir.exists?("/proc/self/fd")
    before = open_descriptors
    slowest = 0.seconds
    50.times do
      proxy = BlackholeProxy.new(port)
      session = through(proxy)
      begin
        session.ping(300.milliseconds).should be_true
        proxy.blackhole!
        started = Time.instant
        session.ping(300.milliseconds).should be_false
        elapsed = Time.instant - started
        slowest = elapsed if elapsed > slowest
        elapsed.should be < 2.seconds
        session.closed?.should be_true
      ensure
        session.close
        proxy.close
      end
    end
    sleep 200.milliseconds
    (open_descriptors - before).should be <= 2
    puts "  slowest of 50: #{slowest.total_milliseconds.round}ms; descriptors before #{before}, after #{open_descriptors}"
  end

  it "fails a request stuck writing into a full send buffer (the peer stopped reading), and releases the descriptors" do
    port = tls_port
    pending! "set CQL_TLS_PG_PORT (see script/tls-probes)" unless port
    pending! "needs /proc/self/fd" unless Dir.exists?("/proc/self/fd")
    before = open_descriptors
    10.times do
      proxy = BlackholeProxy.new(port)
      session = through(proxy)
      begin
        session.cancel_grace = 200.milliseconds
        session.simple_query("CREATE TEMP TABLE sink (line text)")
        proxy.blackhole!
        started = Time.instant
        expect_raises(PG::QueryTimeout) do
          session.copy_in("COPY sink FROM STDIN", timeout: 300.milliseconds) do |copy|
            chunk = Bytes.new(1 << 20, 'x'.ord.to_u8)
            200.times { copy.write(chunk) }
          end
        end
        (Time.instant - started).should be < 3.seconds
        session.closed?.should be_true
      ensure
        session.close
        proxy.close
      end
    end
    sleep 200.milliseconds
    (open_descriptors - before).should be <= 2
  end
end
