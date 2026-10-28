require "spec"
require "../src/cql"

describe "threaded native engine under contention" do
  it "isolates pipelines, bounds streaming buffers and returns all leases" do
    url = ENV.fetch("DATABASE_URL")
    separator = url.includes?('?') ? '&' : '?'
    engine = CQL::Postgres::AsyncEngine.connect("#{url}#{separator}pool_size=4&checkout_timeout=20&query_timeout=10&connect_failure_threshold=3")
    outcomes = Channel(Exception?).new(64)
    64.times do |worker|
      spawn do
        5.times do
          statements = [
            {"SELECT $1::int4", [worker.as(DB::Any)]},
            {"SELECT 1 / 0", [] of DB::Any},
            {"SELECT $1::int4 + 1", [worker.as(DB::Any)]},
          ]
          results = engine.pipeline(statements)
          results[0].as(CQL::Postgres::PipelineResult).all(as: Int32).should eq [worker]
          results[1].should be_a(CQL::Postgres::ServerError)
          results[2].as(CQL::Postgres::PipelineResult).all(as: Int32).should eq [worker + 1]
          engine.with_connection do |connection|
            connection.session.stream("SELECT generate_series(1, 1000)", fetch_size: 7) do |rows|
              20.times { rows.next.should_not be_a(Iterator::Stop); Fiber.yield }
              rows.peak_buffered.should be <= 7
            end
          end
        end
        outcomes.send(nil)
      rescue ex
        outcomes.send(ex)
      end
    end
    64.times do
      select
      when error = outcomes.receive
        raise error if error
      when timeout(60.seconds) then fail "stress worker did not finish"
      end
    end
    engine.pool.stats.in_use.should eq 0
    engine.pool.stats.idle.should be <= 4
    engine.exec("SELECT 1")
  ensure
    engine.try(&.close)
  end
end
