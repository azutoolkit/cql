require "../spec_helper"
require "../../src/postgres"

private def wire_postgres_reachable? : Bool
  CQL::Postgres::Session.connect(CQL::Postgres::Config.parse(postgres_database_url)).close
  true
rescue
  false
end

describe "playground/postgres_async_demo.cr" do
  it "runs end to end against a live server and prints every section" do
    pending! "needs a PostgreSQL server reachable through DATABASE_URL" unless wire_postgres_reachable?

    output = IO::Memory.new
    process = Process.new("crystal", ["run", "playground/postgres_async_demo.cr"], env: {"DATABASE_URL" => postgres_database_url}, output: output, error: output)
    finished = Channel(Process::Status).new(1)
    spawn { finished.send(process.wait) }
    status = select
    when result = finished.receive then result
    when timeout(10.minutes)
      process.terminate
      fail "the demo did not finish within 10 minutes"
    end

    status.success?.should be_true, output.to_s
    (1..8).each { |section| output.to_s.should contain("== #{section}. ") }
    output.to_s.should contain("rolled back: payment gateway down")
    output.to_s.should contain("after a rolled-back savepoint: shipped")
    output.to_s.should contain("CQL::Postgres::UniqueViolation")
    output.to_s.should_not contain("x'; DROP")
    output.to_s.should_not contain("(customer)=(ada)")
  end
end
