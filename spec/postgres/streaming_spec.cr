require "../spec_helper"
require "../support/fake_pg_server"
require "../../src/postgres"

private alias PG = CQL::Postgres

private LIVE_URL = postgres_database_url

private def int4(value : Int32) : Bytes
  slice = Bytes.new(4)
  IO::ByteFormat::BigEndian.encode(value, slice)
  slice
end

private def number_row(value : Int32) : Array(Bytes?)
  [int4(value)] of Bytes?
end

private def int4_columns
  [{"n", 23_u32}]
end

private def max_rows(execute_payload : Bytes) : Int32
  IO::ByteFormat::BigEndian.decode(Int32, execute_payload[execute_payload.size - 4, 4])
end

private def connect(server : FakePG) : PG::Session
  PG::Session.connect(PG::Config.parse(server.url(query: "sslmode=disable")))
end

private def uncached(server : FakePG) : PG::Session
  PG::Session.connect(PG::Config.parse(server.url(query: "sslmode=disable&statement_cache_size=0")))
end

describe "CQL::Postgres streaming" do
  describe "protocol (fake server)" do
    it "fetches through a portal in row-limited Execute+Flush rounds and ends with one Sync" do
      limits = [] of Int32
      server = FakePG.start do |client|
        client.read_startup
        client.ok_handshake
        client.serve_prepare([] of UInt32, int4_columns)
        client.expect('B')
        limits << max_rows(client.expect('E')); client.expect('H')
        client.send('2'); client.data_row(number_row(1)); client.data_row(number_row(2)); client.send('s')
        limits << max_rows(client.expect('E')); client.expect('H')
        client.data_row(number_row(3)); client.command_complete("SELECT 3")
        client.expect('C'); client.expect('S'); client.send('3'); client.ready
        client.idle
      end
      session = connect(server)
      seen = session.stream("SELECT n", fetch_size: 2) do |rows|
        values = rows.map(&.first).to_a
        {values, rows.peak_buffered, rows.tag, rows.finished?}
      end
      seen.should eq({[1, 2, 3] of PG::Types::Value, 2, "SELECT 3", true})
      limits.should eq [2, 2]
      session.closed?.should be_false
      session.ping.should be_true
    end

    it "closes the portal with a Sync when the consumer stops early, leaving the session usable" do
      server = FakePG.start do |client|
        client.read_startup
        client.ok_handshake
        client.serve_prepare([] of UInt32, int4_columns)
        client.expect('B'); client.expect('E'); client.expect('H')
        client.send('2'); client.data_row(number_row(1)); client.data_row(number_row(2)); client.send('s')
        client.expect('C'); client.expect('S'); client.send('3'); client.ready
        client.expect('B'); client.expect('E'); client.expect('S')
        client.send('2'); client.data_row(number_row(9)); client.command_complete("SELECT 1"); client.ready
      end
      session = connect(server)
      session.stream("SELECT n", fetch_size: 2, &.first).should eq [1]
      session.closed?.should be_false
      session.query("SELECT n").rows.should eq [[9]]
    end

    it "resynchronises after an error between fetches and raises it" do
      server = FakePG.start do |client|
        client.read_startup
        client.ok_handshake
        client.serve_prepare([] of UInt32, int4_columns)
        client.expect('B'); client.expect('E'); client.expect('H')
        client.send('2'); client.data_row(number_row(1)); client.send('s')
        client.expect('E'); client.expect('H')
        client.error("22012", "division by zero")
        client.expect('S'); client.ready
        client.expect('B'); client.expect('E'); client.expect('S')
        client.send('2'); client.data_row(number_row(5)); client.command_complete("SELECT 1"); client.ready
      end
      session = connect(server)
      expect_raises(PG::ServerError, /22012/) { session.stream("SELECT n", fetch_size: 1, &.to_a) }
      session.closed?.should be_false
      session.query("SELECT n").rows.should eq [[5]]
    end

    it "closes the portal and syncs when the consumer's block raises, and cannot be read afterwards" do
      server = FakePG.start do |client|
        client.read_startup
        client.ok_handshake
        client.serve_prepare([] of UInt32, int4_columns)
        client.expect('B'); client.expect('E'); client.expect('H')
        client.send('2'); client.data_row(number_row(1)); client.send('s')
        client.expect('C'); client.expect('S'); client.send('3'); client.ready
        client.idle
      end
      session = connect(server)
      escaped = nil
      expect_raises(Exception, "consumer failed") do
        session.stream("SELECT n", fetch_size: 1) do |rows|
          escaped = rows
          raise "consumer failed"
        end
      end
      session.closed?.should be_false
      session.ping.should be_true
      escaped.not_nil!.next.should eq [1] # what was buffered is still readable
      expect_raises(PG::StreamClosed) { escaped.not_nil!.next }
    end

    it "treats an empty query as an empty stream" do
      server = FakePG.start do |client|
        client.read_startup
        client.ok_handshake
        client.serve_prepare([] of UInt32, [] of {String, UInt32})
        client.expect('B'); client.expect('E'); client.expect('H')
        client.send('2'); client.send('I')
        client.expect('C'); client.expect('S'); client.send('3'); client.ready
      end
      connect(server).stream("", &.to_a).should be_empty
    end

    it "re-prepares and retries when the first fetch hits a stale plan, but not after rows were delivered" do
      parses = 0
      server = FakePG.start do |client|
        client.read_startup
        client.ok_handshake
        client.serve_prepare([] of UInt32, int4_columns); parses += 1
        client.expect('B'); client.expect('E'); client.expect('H')
        client.error("0A000", "cached plan must not change result type", {'R' => "RevalidateCachedQuery"})
        client.expect('S'); client.ready
        client.expect('C'); client.send('3') # the stale statement is closed along with the re-prepare
        client.serve_prepare([] of UInt32, int4_columns); parses += 1
        client.expect('B'); client.expect('E'); client.expect('H')
        client.send('2'); client.data_row(number_row(7)); client.command_complete("SELECT 1")
        client.expect('C'); client.expect('S'); client.send('3'); client.ready
      end
      connect(server).stream("SELECT n", &.to_a).should eq [[7]]
      parses.should eq 2
    end

    it "keeps the session in sync when a value cannot be decoded, and raises after the fetch" do
      infinity = Bytes[0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
      server = FakePG.start do |client|
        client.read_startup
        client.ok_handshake
        client.serve_prepare([] of UInt32, [{"t", 1184_u32}])
        client.expect('B'); client.expect('E'); client.expect('H')
        client.send('2'); client.data_row([infinity] of Bytes?); client.data_row([infinity] of Bytes?); client.send('s')
        client.expect('S'); client.ready
        client.idle
      end
      session = connect(server)
      expect_raises(PG::UnsupportedValue) { session.stream("SELECT t", fetch_size: 2, &.to_a) }
      session.closed?.should be_false
      session.ping.should be_true
    end

    it "refuses COPY, tells the server, and stays in sync" do
      server = FakePG.start do |client|
        client.read_startup
        client.ok_handshake
        client.serve_prepare([] of UInt32, [] of {String, UInt32})
        client.expect('B'); client.expect('E'); client.expect('H')
        client.send('2'); client.send('G', Bytes[0, 0, 0, 0, 0])
        client.expect('f')
        client.expect('S')
        client.error("57014", "COPY from stdin failed")
        client.ready
        client.idle
      end
      session = connect(server)
      expect_raises(ArgumentError, /COPY cannot be streamed/) { session.stream("COPY t FROM STDIN", &.to_a) }
      session.closed?.should be_false
      session.ping.should be_true
    end

    it "streams through Connection and AsyncEngine as a DB::ResultSet" do
      server = FakePG.start do |client|
        client.read_startup
        client.ok_handshake
        client.serve_prepare([] of UInt32, int4_columns)
        client.expect('B'); client.expect('E'); client.expect('H')
        client.send('2'); client.data_row(number_row(1)); client.data_row(number_row(2)); client.command_complete("SELECT 2")
        client.expect('C'); client.expect('S'); client.send('3'); client.ready
        client.idle
      end
      engine = PG::AsyncEngine.new(PG::Pool.new(PG::Config.parse(server.url(query: "sslmode=disable"))))
      values = engine.stream("SELECT n") do |rows|
        rows.column_count.should eq 1
        rows.column_name(0).should eq "n"
        found = [] of Int32
        rows.each { found << rows.read(Int32) }
        found
      end
      values.should eq [1, 2]
      engine.pool.stats.in_use.should eq 0
    end

    it "streams an uncached statement in one request: Parse+Describe+Flush, Bind+Execute+Flush, then Close+Sync" do
      server = FakePG.start do |client|
        client.read_startup
        client.ok_handshake
        client.expect('P'); client.expect('D'); client.expect('H')
        client.send('1'); client.parameter_description([] of UInt32); client.row_description(int4_columns)
        client.expect('B'); client.expect('E'); client.expect('H')
        client.send('2'); client.data_row(number_row(1)); client.data_row(number_row(2)); client.send('s')
        client.expect('E'); client.expect('H')
        client.data_row(number_row(3)); client.command_complete("SELECT 3")
        client.expect('C'); client.expect('S'); client.send('3'); client.ready
      end
      session = PG::Session.connect(PG::Config.parse(server.url(query: "sslmode=disable&statement_cache_size=0")))
      session.stream("SELECT n", fetch_size: 2, &.to_a).should eq [[1], [2], [3]]
    end

    it "refuses to be read from a fiber other than the one that opened it" do
      server = FakePG.start do |client|
        client.read_startup
        client.ok_handshake
        client.serve_prepare([] of UInt32, int4_columns)
        client.expect('B'); client.expect('E'); client.expect('H')
        client.send('2'); client.data_row(number_row(1)); client.send('s')
        client.expect('C'); client.expect('S'); client.send('3'); client.ready
      end
      outcome = connect(server).stream("SELECT n", fetch_size: 1) do |rows|
        result = Channel(Exception?).new
        spawn do
          rows.next
          result.send(nil)
        rescue ex
          result.send(ex)
        end
        result.receive
      end
      outcome.should be_a PG::Error
    end

    describe "uncached statements (statement_cache_size=0)" do
      it "ends the open request with a Sync when the parameter count is wrong, and stays usable" do
        server = FakePG.start do |client|
          client.read_startup
          client.ok_handshake
          client.expect('P'); client.expect('D'); client.expect('H')
          client.send('1'); client.parameter_description([23_u32]); client.row_description(int4_columns)
          client.expect('S'); client.ready # no Bind was sent
          client.idle
        end
        session = uncached(server)
        expect_raises(ArgumentError, /takes 1 parameters/) { session.stream("SELECT n FROM t WHERE n = $1", &.to_a) }
        session.closed?.should be_false
        session.ping.should be_true
      end

      it "ends the open request with a Sync when describing fails, and stays usable" do
        server = FakePG.start do |client|
          client.read_startup
          client.ok_handshake
          client.expect('P'); client.expect('D'); client.expect('H')
          client.error("42601", "syntax error")
          client.expect('S'); client.ready
          client.idle
        end
        session = uncached(server)
        expect_raises(PG::ServerError, /42601/) { session.stream("SELEC", &.to_a) }
        session.closed?.should be_false
        session.ping.should be_true
      end

      it "drops the session, sending no Bind, when the deadline passes between Describe and Bind" do
        received = Channel(Array(Char)).new(1)
        server = FakePG.start do |client|
          startup = client.read_startup
          next if startup["protocol"] == "cancel"
          client.ok_handshake
          client.expect('P'); client.expect('D'); client.expect('H')
          sleep 400.milliseconds # the 200ms deadline passes while the describe is outstanding
          client.send('1'); client.parameter_description([] of UInt32); client.row_description(int4_columns)
          while client.read_message
          end
          received.send(client.received.dup)
        end
        session = uncached(server)
        expect_raises(PG::QueryTimeout) { session.stream("SELECT n", timeout: 200.milliseconds, &.to_a) }
        session.closed?.should be_true
        select
        when seen = received.receive then seen.should_not contain 'B'
        when timeout(3.seconds) then fail "the server never saw the client hang up"
        end
      end
    end

    it "raises WrongFiber when read from a fiber other than the one that opened it" do
      server = FakePG.start do |client|
        client.read_startup
        client.ok_handshake
        client.serve_prepare([] of UInt32, int4_columns)
        client.expect('B'); client.expect('E'); client.expect('H')
        client.send('2'); client.data_row(number_row(1)); client.send('s')
        client.expect('C'); client.expect('S'); client.send('3'); client.ready
      end
      outcome = connect(server).stream("SELECT n", fetch_size: 1) do |rows|
        result = Channel(Exception?).new
        spawn do
          rows.next
          result.send(nil)
        rescue ex
          result.send(ex)
        end
        result.receive
      end
      outcome.should be_a PG::WrongFiber
    end

    it "rejects a fetch size of zero" do
      expect_raises(ArgumentError, /fetch_size/) { connect(FakePG.start { |client| client.read_startup; client.ok_handshake; client.idle }).stream("SELECT 1", fetch_size: 0, &.to_a) }
    end
  end

  describe "against a live server" do
    live = begin
      PG::Session.connect(PG::Config.parse(LIVE_URL)).close
      true
    rescue
      false
    end

    it "streams a large result with memory bounded by the fetch size" do
      pending! "needs a PostgreSQL server reachable through DATABASE_URL" unless live
      session = PG::Session.connect(PG::Config.parse(LIVE_URL))
      sum, peak, count = session.stream("SELECT g::int4 FROM generate_series(1, 20000) g", fetch_size: 250) do |rows|
        total = 0_i64
        rows.each { |row| total += row.first.as(Int32) }
        {total, rows.peak_buffered, rows.rows_read}
      end
      sum.should eq (1_i64..20000_i64).sum
      peak.should eq 250
      count.should eq 20000
      session.close
    end

    it "stops early without leaving the connection mid-stream, in or out of a transaction" do
      pending! "needs a PostgreSQL server reachable through DATABASE_URL" unless live
      session = PG::Session.connect(PG::Config.parse(LIVE_URL))
      session.stream("SELECT g::int4 FROM generate_series(1, 1000000) g", fetch_size: 10, &.first(25).to_a).size.should eq 25
      session.in_transaction?.should be_false
      session.query("SELECT 42").rows.should eq [[42]]
      session.simple_query("BEGIN")
      session.stream("SELECT g::int4 FROM generate_series(1, 1000000) g", fetch_size: 10, &.first(3).to_a).size.should eq 3
      session.in_transaction?.should be_true
      session.simple_query("COMMIT")
      session.query("SELECT 43").rows.should eq [[43]]
      session.close
    end

    it "raises a server error from a later fetch and stays usable" do
      pending! "needs a PostgreSQL server reachable through DATABASE_URL" unless live
      session = PG::Session.connect(PG::Config.parse(LIVE_URL))
      expect_raises(PG::ServerError) { session.stream("SELECT (10 / (g - 25))::int4 FROM generate_series(1, 50) g", fetch_size: 5, &.to_a) }
      session.query("SELECT 44").rows.should eq [[44]]
      session.close
    end

    it "is canceled from another fiber in the middle of a stream and stays usable" do
      pending! "needs a PostgreSQL server reachable through DATABASE_URL" unless live
      session = PG::Session.connect(PG::Config.parse(LIVE_URL))
      spawn do
        sleep 250.milliseconds
        session.cancel
      end
      expect_raises(PG::QueryCanceled) { session.stream("SELECT g::int4, pg_sleep(0.05)::text FROM generate_series(1, 1000) g", fetch_size: 1, &.to_a) }
      session.closed?.should be_false
      session.query("SELECT 45").rows.should eq [[45]]
      session.close
    end

    it "times out a stream as a whole" do
      pending! "needs a PostgreSQL server reachable through DATABASE_URL" unless live
      session = PG::Session.connect(PG::Config.parse(LIVE_URL))
      expect_raises(PG::QueryTimeout) do
        session.stream("SELECT g::int4, pg_sleep(0.05)::text FROM generate_series(1, 1000) g", fetch_size: 1, timeout: 400.milliseconds, &.to_a)
      end
      session.close
      PG::Session.connect(PG::Config.parse(LIVE_URL)).close
    end

    it "streams through the engine as a DB::ResultSet and returns the connection to the pool in sync" do
      pending! "needs a PostgreSQL server reachable through DATABASE_URL" unless live
      engine = PG::AsyncEngine.connect("#{LIVE_URL}#{LIVE_URL.includes?('?') ? '&' : '?'}pool_size=1")
      names = [] of String
      engine.stream("SELECT g::int8, 'row ' || g FROM generate_series(1, 5000) g", [] of ::DB::Any, fetch_size: 100) do |rows|
        rows.each do
          id, name = rows.read(Int64), rows.read(String)
          names << name if id <= 3
          break if id == 1000
        end
      end
      names.should eq ["row 1", "row 2", "row 3"]
      engine.pool.stats.in_use.should eq 0
      engine.exec_query(&.scalar("SELECT 46")).should eq 46
      engine.close
    end
  end
end
