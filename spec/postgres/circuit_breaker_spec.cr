require "../spec_helper"
require "../support/fake_pg_server"
require "../../src/postgres"

describe CQL::Postgres::CircuitBreaker do
  it "opens at the threshold and admits exactly one recovery probe" do
    breaker = CQL::Postgres::CircuitBreaker.new(2, 1.second)
    now = Time.instant
    breaker.failed(breaker.acquire(now), now)
    breaker.failed(breaker.acquire(now), now)
    expect_raises(CQL::Postgres::CircuitOpen) { breaker.acquire(now) }
    probe = breaker.acquire(now + 1.second)
    expect_raises(CQL::Postgres::CircuitOpen) { breaker.acquire(now + 2.seconds) }
    breaker.succeeded(probe)
    breaker.acquire(now + 2.seconds)
  end

  it "ignores late successes and failures from before the circuit opened" do
    breaker = CQL::Postgres::CircuitBreaker.new(1, 1.second)
    now = Time.instant
    old = breaker.acquire(now)
    breaker.failed(old, now)
    breaker.succeeded(old)
    expect_raises(CQL::Postgres::CircuitOpen) { breaker.acquire(now) }
    probe = breaker.acquire(now + 1.second)
    breaker.succeeded(probe)
    breaker.failed(old, now + 1.second)
    breaker.acquire(now + 1.second)
  end

  it "reopens for a full cooldown when its recovery probe fails" do
    breaker = CQL::Postgres::CircuitBreaker.new(1, 1.second)
    now = Time.instant
    breaker.failed(breaker.acquire(now), now)
    breaker.failed(breaker.acquire(now + 1.second), now + 1.second)
    expect_raises(CQL::Postgres::CircuitOpen) { breaker.acquire(now + 1500.milliseconds) }
    breaker.acquire(now + 2.seconds)
  end

  it "is disabled at zero and rejects invalid options" do
    breaker = CQL::Postgres::CircuitBreaker.new(0, 1.second)
    20.times { breaker.failed(breaker.acquire) }
    expect_raises(ArgumentError, /nonnegative/) { CQL::Postgres::CircuitBreaker.new(-1, 1.second) }
    expect_raises(ArgumentError, /positive/) { CQL::Postgres::CircuitBreaker.new(1, 0.seconds) }
  end

  it "admits one probe under concurrent contention" do
    breaker = CQL::Postgres::CircuitBreaker.new(1, 1.second)
    now = Time.instant
    breaker.failed(breaker.acquire(now), now)
    outcomes = Channel(Bool).new(100)
    100.times do
      spawn do
        breaker.acquire(now + 1.second)
        outcomes.send(true)
      rescue CQL::Postgres::CircuitOpen
        outcomes.send(false)
      end
    end
    Array.new(100) { outcomes.receive }.count(true).should eq 1
  end

  it "stops real connection attempts and returns the pool slot after failures" do
    server = FakePG.start do |client|
      client.read_startup
      client.error("28P01", "test authentication refusal")
    end
    config = CQL::Postgres::Config.parse(server.url(query: "sslmode=disable&pool_size=1&connect_failure_threshold=2&connect_retry_delay=60"))
    pool = CQL::Postgres::Pool.new(config)
    2.times { expect_raises(CQL::Postgres::ServerError) { pool.checkout } }
    10.times { expect_raises(CQL::Postgres::CircuitOpen) { pool.checkout } }
    server.accepted.should eq 2
    pool.stats.in_use.should eq 0
  ensure
    pool.try(&.close)
    server.try(&.close)
  end
end
