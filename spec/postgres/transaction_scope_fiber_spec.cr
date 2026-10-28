require "../spec_helper"
require "../support/fake_pg_server"

describe "native transaction scope ownership" do
  it "rejects child-fiber queries, streams and savepoints before lending the connection" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.idle
    end
    engine = CQL::Postgres::AsyncEngine.connect(server.url(query: "sslmode=disable&pool_size=1"))
    rejected = Channel(Exception?).new(1)
    engine.transaction do |scope|
      spawn do
        expect_raises(CQL::Postgres::WrongFiber) { scope.exec_query { fail "foreign fiber acquired connection" } }
        expect_raises(CQL::Postgres::WrongFiber) { scope.stream("SELECT 1") { fail "foreign fiber opened stream" } }
        expect_raises(CQL::Postgres::WrongFiber) { scope.savepoint { fail "foreign fiber opened savepoint" } }
        rejected.send(nil)
      rescue ex
        rejected.send(ex)
      end
      select
      when error = rejected.receive
        raise error if error
      when timeout(1.second) then fail "foreign fiber was not rejected"
      end
      scope.exec_query(&.unprepared.exec("SELECT owner"))
      scope.savepoint { |nested| nested.exec_query(&.unprepared.exec("SELECT nested_owner")) }
    end
    engine.exec("SELECT next_borrower")
    engine.pool.stats.in_use.should eq 0
  ensure
    engine.try(&.close)
    server.try(&.close)
  end
end
