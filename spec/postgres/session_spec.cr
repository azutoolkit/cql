require "../spec_helper"
require "../support/fake_pg_server"
require "../../src/postgres"

private alias PG = CQL::Postgres
private alias Types = CQL::Postgres::Types

private def connect(server : FakePG, **options)
  PG::Session.connect(PG::Config.parse(server.url(**options)))
end

private def be_int32(value : Int32) : Bytes
  Bytes.new(4).tap { |bytes| IO::ByteFormat::NetworkEndian.encode(value, bytes) }
end

private def int4_column
  [{"n", 23_u32}]
end

private def parse_bind(payload : Bytes)
  reader = PG::Wire::Reader.new(payload)
  portal = reader.cstring
  statement = reader.cstring
  formats = Array.new(reader.uint16.to_i) { reader.int16 }
  values = Array.new(reader.uint16.to_i) do
    length = reader.int32
    length < 0 ? nil : String.new(reader.bytes(length))
  end
  result_formats = Array.new(reader.uint16.to_i) { reader.int16 }
  {portal: portal, statement: statement, formats: formats, values: values, result_formats: result_formats}
end

# Serves one prepare + execute round of "SELECT n" returning 42.
private def serve_select_42(client : FakePG::Client) : Nil
  client.serve_prepare([] of UInt32, int4_column)
  client.serve_execute([[be_int32(42).as(Bytes?)]], "SELECT 1")
end

describe CQL::Postgres::Session do
  it "runs the simple protocol, returning text rows and one result per statement" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('Q').should eq "SELECT 1; UPDATE t SET a = 1\0".to_slice
      client.row_description([{"one", 23_u32}])
      client.data_row(["1".to_slice.as(Bytes?)])
      client.command_complete("SELECT 1")
      client.command_complete("UPDATE 3")
      client.ready
    end
    results = connect(server).simple_query("SELECT 1; UPDATE t SET a = 1")
    results.size.should eq 2
    results[0].rows.should eq [["1"]]
    results[0].columns.first.name.should eq "one"
    results[1].rows_affected.should eq 3
  end

  it "prepares once, then reuses the statement and decodes binary results by type" do
    received = [] of Char
    bind = nil
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.serve_prepare([20_u32], int4_column)
      client.serve_execute([[be_int32(42).as(Bytes?)]], "SELECT 1")
      client.expect('B').tap { |payload| bind = parse_bind(payload) }
      client.expect('E'); client.expect('S')
      client.send('2'); client.data_row([be_int32(7).as(Bytes?)]); client.command_complete("SELECT 1"); client.ready
      received.concat(client.received)
    end
    session = connect(server)
    first = session.query("SELECT n FROM t WHERE id = $1", [Types::ParamEncoder.encode(5)])
    first.rows.should eq [[42]]
    second = session.query("SELECT n FROM t WHERE id = $1", [Types::ParamEncoder.encode(6)])
    second.rows.should eq [[7]]
    session.close
    server.await
    received.should eq ['P', 'D', 'S', 'B', 'E', 'S', 'B', 'E', 'S']
    bind.not_nil![:statement].should eq "cql_1"
    bind.not_nil![:result_formats].should eq [1_i16]
  end

  it "sends bound values as parameters and never inlines them into the SQL text" do
    parse_sql = nil
    bound = nil
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      parse_sql = client.cstrings(client.expect('P'))[1]
      client.expect('D'); client.expect('S')
      client.send('1'); client.parameter_description([25_u32, 20_u32]); client.send('n'); client.ready
      bound = parse_bind(client.expect('B'))
      client.expect('E'); client.expect('S')
      client.send('2'); client.command_complete("UPDATE 1"); client.ready
    end
    result = connect(server).query("UPDATE t SET name = $1 WHERE id = $2", [Types::ParamEncoder.encode("x'; DROP TABLE t; --"), Types::ParamEncoder.encode(9_i64)])
    result.rows_affected.should eq 1
    parse_sql.not_nil!.should eq "UPDATE t SET name = $1 WHERE id = $2"
    bound.not_nil![:values].should eq ["x'; DROP TABLE t; --", "9"]
    bound.not_nil![:formats].should eq [0_i16, 0_i16]
  end

  it "checks the parameter count before sending anything" do
    received = [] of Char
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.serve_prepare([23_u32], int4_column)
      client.read_message
      received.concat(client.received)
    end
    session = connect(server)
    expect_raises(ArgumentError, /takes 1 parameters, got 0/) { session.query("SELECT n FROM t WHERE id = $1") }
    session.closed?.should be_false
    session.close
    server.await
    received.should eq ['P', 'D', 'S', 'X']
  end

  it "raises typed errors, stays in sync, and keeps the session usable" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.serve_prepare([] of UInt32, [] of {String, UInt32})
      client.expect('B'); client.expect('E'); client.expect('S')
      client.send('2')
      client.error("23505", "duplicate key value violates unique constraint \"users_email_key\"", {'D' => "Key (email)=(a@b.c) already exists.", 'n' => "users_email_key"})
      client.ready
      client.serve_prepare([] of UInt32, int4_column)
      client.serve_execute([[be_int32(1).as(Bytes?)]], "SELECT 1")
    end
    session = connect(server)
    error = expect_raises(PG::UniqueViolation) { session.query("INSERT INTO users DEFAULT VALUES") }
    error.constraint.should eq "users_email_key"
    error.message.to_s.should_not contain "a@b.c"
    session.closed?.should be_false
    session.query("SELECT n FROM t").rows.should eq [[1]]
  end

  it "re-prepares once when the server's cached plan went stale, then closes the retired statement" do
    received = [] of Char
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.serve_prepare([] of UInt32, int4_column)
      client.expect('B'); client.expect('E'); client.expect('S')
      client.send('2')
      client.error("0A000", "cached plan must not change result type", {'R' => "RevalidateCachedQuery"})
      client.ready
      client.expect('C'); client.expect('P'); client.expect('D'); client.expect('S')
      client.send('3'); client.send('1'); client.parameter_description([] of UInt32); client.row_description(int4_column); client.ready
      client.serve_execute([[be_int32(42).as(Bytes?)]], "SELECT 1")
      client.serve_prepare([] of UInt32, int4_column)
      client.serve_execute([[be_int32(43).as(Bytes?)]], "SELECT 1")
      received.concat(client.received)
    end
    session = connect(server)
    session.query("SELECT n FROM t").rows.should eq [[42]]
    session.query("SELECT other").rows.should eq [[43]]
    received.should eq ['P', 'D', 'S', 'B', 'E', 'S', 'C', 'P', 'D', 'S', 'B', 'E', 'S', 'P', 'D', 'S', 'B', 'E', 'S']
  end

  it "survives callbacks that raise" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('Q')
      client.notice("careful")
      client.send('A', be_int32(1) + "chan\0data\0".to_slice)
      client.command_complete("OK")
      client.ready
    end
    session = connect(server)
    session.on_notice = ->(_fields : Hash(Char, String)) { raise "notice handler bug" }
    session.on_notification = ->(_note : PG::Notification) { raise "notification handler bug" }
    session.simple_query("SELECT 1").first.tag.should eq "OK"
    session.closed?.should be_false
  end

  it "evicts the least recently used statement and closes it on the server" do
    received = [] of Char
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      serve_select_42(client)
      client.expect('C'); client.expect('P'); client.expect('D'); client.expect('S')
      client.send('3'); client.send('1'); client.parameter_description([] of UInt32); client.row_description(int4_column); client.ready
      client.serve_execute([[be_int32(43).as(Bytes?)]], "SELECT 1")
      received.concat(client.received)
    end
    config = PG::Config.parse(server.url(query: "sslmode=disable&statement_cache_size=1"))
    session = PG::Session.connect(config)
    session.query("SELECT a").rows.should eq [[42]]
    session.query("SELECT b").rows.should eq [[43]]
    received.first(7).should eq ['P', 'D', 'S', 'B', 'E', 'S', 'C']
  end

  it "uses the unnamed statement when caching is off, describing it without a Sync so Bind stays in the same request" do
    statement = nil
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('P'); client.expect('D'); client.expect('H') # no Sync: a pooler must not move the request
      client.send('1'); client.parameter_description([] of UInt32); client.row_description(int4_column)
      statement = parse_bind(client.expect('B'))[:statement]
      client.expect('E'); client.expect('S')
      client.send('2'); client.command_complete("SELECT 0"); client.ready
    end
    config = PG::Config.parse(server.url(query: "sslmode=disable&statement_cache_size=0"))
    PG::Session.connect(config).query("SELECT n FROM t")
    statement.should eq ""
  end

  it "pipelines statements: all requests are written before any reply is read" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      2.times { client.expect('P'); client.expect('D'); client.expect('S') }
      2.times do
        client.send('1'); client.parameter_description([] of UInt32); client.row_description(int4_column); client.ready
      end
      # Three Bind/Execute/Sync triples must all arrive before any reply is sent;
      # a client that waited for each answer would deadlock here.
      6.times { client.read_message }
      client.send('2'); client.data_row([be_int32(1).as(Bytes?)]); client.command_complete("SELECT 1"); client.ready
      client.send('2'); client.error("22012", "division by zero"); client.ready
      client.send('2'); client.data_row([be_int32(3).as(Bytes?)]); client.command_complete("SELECT 1"); client.ready
    end
    session = connect(server)
    results = session.pipeline([{"SELECT 1", [] of Types::Param}, {"SELECT 1/0", [] of Types::Param}, {"SELECT 1", [] of Types::Param}])
    results[0].as(PG::Result).rows.should eq [[1]]
    results[1].should be_a PG::ServerError
    results[2].as(PG::Result).rows.should eq [[3]]
    session.closed?.should be_false
  end

  it "keeps pipelined statements that did not fail when one cannot be prepared" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      2.times { client.expect('P'); client.expect('D'); client.expect('S') }
      client.send('1'); client.parameter_description([] of UInt32); client.row_description(int4_column); client.ready
      client.error("42601", "syntax error at or near \"SELEC\""); client.ready
      client.expect('B'); client.expect('E'); client.expect('S')
      client.send('2'); client.data_row([be_int32(5).as(Bytes?)]); client.command_complete("SELECT 1"); client.ready
    end
    results = connect(server).pipeline([{"SELECT 5", [] of Types::Param}, {"SELEC 1", [] of Types::Param}])
    results[0].as(PG::Result).rows.should eq [[5]]
    results[1].should be_a PG::SyntaxOrAccessError
  end

  it "refuses to pipeline without a statement cache" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
    end
    config = PG::Config.parse(server.url(query: "sslmode=disable&statement_cache_size=0"))
    expect_raises(ArgumentError, /statement cache/) { PG::Session.connect(config).pipeline([{"SELECT 1", [] of Types::Param}]) }
  end

  it "streams COPY FROM STDIN and returns the row count" do
    body = IO::Memory.new
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('Q')
      client.send('G', Bytes[0, 0, 1, 0, 0])
      while message = client.read_message
        break if message[0] == 'c'
        body.write(message[1])
      end
      client.command_complete("COPY 2")
      client.ready
    end
    rows = connect(server).copy_in("COPY t FROM STDIN") { |copy| copy << "1\tada\n"; copy << "2\tbob\n" }
    rows.should eq 2
    String.new(body.to_slice).should eq "1\tada\n2\tbob\n"
  end

  it "aborts COPY FROM STDIN with CopyFail when the block raises and re-raises the block's error" do
    failed = false
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('Q')
      client.send('G', Bytes[0, 0, 1, 0, 0])
      loop do
        message = client.read_message || break
        if message[0] == 'f'
          failed = true
          break
        end
      end
      client.error("57014", "COPY from stdin failed: the client aborted the COPY")
      client.ready
    end
    session = connect(server)
    expect_raises(Exception, "boom") { session.copy_in("COPY t FROM STDIN") { |_| raise "boom" } }
    failed.should be_true
    session.closed?.should be_false
  end

  it "streams COPY TO STDOUT chunks" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('Q')
      client.send('H', Bytes[0, 0, 1, 0, 0])
      client.send('d', "1\tada\n".to_slice)
      client.send('d', "2\tbob\n".to_slice)
      client.send('c')
      client.command_complete("COPY 2")
      client.ready
    end
    chunks = [] of String
    rows = connect(server).copy_out("COPY t TO STDOUT") { |chunk| chunks << String.new(chunk) }
    rows.should eq 2
    chunks.should eq ["1\tada\n", "2\tbob\n"]
  end

  it "delivers notices and notifications to callbacks without disturbing the query" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('Q')
      client.notice("table does not exist, skipping")
      client.send('A', be_int32(99) + "jobs\0ready\0".to_slice)
      client.command_complete("DROP TABLE")
      client.ready
    end
    notices = [] of String
    notifications = [] of {String, String}
    session = connect(server)
    session.on_notice = ->(fields : Hash(Char, String)) { notices << fields['M'] }
    session.on_notification = ->(note : PG::Notification) { notifications << {note.channel, note.payload} }
    session.simple_query("DROP TABLE IF EXISTS t")
    notices.should eq ["table does not exist, skipping"]
    notifications.should eq [{"jobs", "ready"}]
  end

  it "pings with an empty query and reports a dead connection as false" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('Q').should eq "\0".to_slice
      client.send('I')
      client.ready
    end
    session = connect(server)
    session.ping.should be_true
    server.await
    session.ping.should be_false
    session.closed?.should be_true
  end

  it "says Terminate on close" do
    received = [] of Char
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.read_message
      received.concat(client.received)
    end
    session = connect(server)
    session.close
    session.closed?.should be_true
    server.await
    received.should eq ['X']
  end

  it "raises ConnectionLost and closes when the server hangs up mid-request" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('P')
    end
    session = connect(server)
    expect_raises(PG::ConnectionLost) { session.query("SELECT 1") }
    session.closed?.should be_true
    expect_raises(PG::ConnectionLost, /closed/) { session.query("SELECT 1") }
  end

  it "closes the session when the server breaks the protocol mid-request" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('Q')
      client.send('Z', Bytes['X'.ord.to_u8])
    end
    session = connect(server)
    expect_raises(PG::ProtocolError) { session.simple_query("SELECT 1") }
    session.closed?.should be_true
  end

  it "queues requests from several fibers so replies never interleave" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      2.times do
        sql = client.cstrings(client.expect('P'))[1]
        client.expect('D'); client.expect('S')
        client.send('1'); client.parameter_description([] of UInt32); client.row_description(int4_column); client.ready
        client.expect('B'); client.expect('E'); client.expect('S')
        sleep 20.milliseconds
        client.send('2'); client.data_row([be_int32(sql.ends_with?("1") ? 1 : 2).as(Bytes?)]); client.command_complete("SELECT 1"); client.ready
      end
    end
    session = connect(server)
    done = Channel({Int32, Int32}).new
    {1, 2}.each do |number|
      spawn { done.send({number, session.query("SELECT #{number}").rows.first.first.as(Int32)}) }
    end
    results = [done.receive, done.receive].to_h
    results.should eq({1 => 1, 2 => 2})
  end

  it "cancels a statement that exceeds its timeout and stays usable" do
    cancelled = Channel({Int32, String}).new(1)
    server = FakePG.start do |client|
      startup = client.read_startup
      if startup["protocol"] == "cancel"
        cancelled.send({startup["pid"].to_i, startup["secret"]})
        next
      end
      client.ok_handshake
      client.serve_prepare([] of UInt32, int4_column)
      client.expect('B'); client.expect('E'); client.expect('S')
      cancelled.receive
      client.send('2')
      client.error("57014", "canceling statement due to user request")
      client.ready
    end
    session = connect(server)
    expect_raises(PG::QueryTimeout, /canceled after/) { session.query("SELECT pg_sleep(10)", timeout: 50.milliseconds) }
    session.closed?.should be_false
  end

  it "drops a session whose cancel was sent but not confirmed, since it could hit the next statement" do
    sent = Channel(Nil).new(1)
    server = FakePG.start do |client|
      startup = client.read_startup
      if startup["protocol"] == "cancel"
        sent.send(nil)
        next
      end
      client.ok_handshake
      client.serve_prepare([] of UInt32, int4_column)
      client.expect('B'); client.expect('E'); client.expect('S')
      sent.receive
      client.send('2'); client.data_row([be_int32(1).as(Bytes?)]); client.command_complete("SELECT 1"); client.ready
    end
    session = connect(server)
    session.query("SELECT 1", timeout: 30.milliseconds).rows.should eq [[1]]
    session.closed?.should be_true
  end

  it "keeps the session when the statement finishes before its deadline" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      serve_select_42(client)
    end
    session = connect(server)
    session.query("SELECT n", timeout: 5.seconds).rows.should eq [[42]]
    session.closed?.should be_false
  end

  it "splits a pipeline into batches that fit the socket buffers, waiting for each batch's replies" do
    waited_for_reply = false
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('P'); client.expect('D'); client.expect('S')
      client.send('1'); client.parameter_description([25_u32]); client.row_description(int4_column); client.ready
      first = parse_bind(client.expect('B'))
      client.expect('E'); client.expect('S')
      # The second batch must not have been written while the first is unanswered.
      client.io.read_timeout = 200.milliseconds
      begin
        client.io.read_byte
      rescue IO::TimeoutError
        waited_for_reply = true
      end
      client.io.read_timeout = nil
      client.send('2'); client.data_row([be_int32(first[:values].first.to_s.size).as(Bytes?)]); client.command_complete("SELECT 1"); client.ready
      client.expect('B'); client.expect('E'); client.expect('S')
      client.send('2'); client.data_row([be_int32(2).as(Bytes?)]); client.command_complete("SELECT 1"); client.ready
    end
    big = Types::ParamEncoder.encode("x" * 20_000)
    results = connect(server).pipeline([{"SELECT length($1)", [big]}, {"SELECT length($1)", [big]}])
    waited_for_reply.should be_true
    results.map { |result| result.as(PG::Result).rows.first.first }.should eq [20_000, 2]
  end

  it "leaves nothing half-written when a pipelined statement cannot be encoded" do
    parsed = nil
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      parsed = client.cstrings(client.expect('P'))[1]
      client.expect('D'); client.expect('S')
      client.send('1'); client.parameter_description([] of UInt32); client.row_description(int4_column); client.ready
      client.serve_execute([[be_int32(42).as(Bytes?)]], "SELECT 1")
    end
    session = connect(server)
    expect_raises(ArgumentError, /NUL/) { session.pipeline([{"SELECT 1", [] of Types::Param}, {"SELECT 'a\0'", [] of Types::Param}]) }
    session.closed?.should be_false
    session.query("SELECT 42").rows.should eq [[42]]
    parsed.should eq "SELECT 42"
  end

  it "reads every reply of a pipeline when a value cannot be decoded, and stays in sync" do
    infinity = Bytes[0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      3.times { client.expect('P'); client.expect('D'); client.expect('S') }
      client.send('1'); client.parameter_description([] of UInt32); client.row_description([{"t", 1184_u32}]); client.ready
      2.times do
        client.send('1'); client.parameter_description([] of UInt32); client.row_description(int4_column); client.ready
      end
      3.times { client.expect('B'); client.expect('E'); client.expect('S') }
      client.send('2'); client.data_row([infinity.as(Bytes?)]); client.command_complete("SELECT 1"); client.ready
      2.times { client.send('2'); client.data_row([be_int32(2).as(Bytes?)]); client.command_complete("SELECT 1"); client.ready }
      serve_select_42(client)
    end
    session = connect(server)
    statements = [{"SELECT 'infinity'::timestamptz", [] of Types::Param}, {"SELECT 2", [] of Types::Param}, {"SELECT 3", [] of Types::Param}]
    expect_raises(PG::UnsupportedValue, /infinite/) { session.pipeline(statements) }
    session.closed?.should be_false
    session.query("SELECT 42").rows.should eq [[42]]
  end

  it "refuses a COPY FROM STDIN sent through the wrong entry point instead of hanging" do
    refused = [] of Char
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.serve_prepare([] of UInt32, [] of {String, UInt32})
      client.expect('B'); client.expect('E'); client.expect('S')
      client.send('G', Bytes[0, 0, 1, 0, 0])
      refused << client.expect_type('f')
      # The Sync sent with the request was ignored while the server waited for COPY data.
      refused << client.expect_type('S')
      client.error("57014", "COPY from stdin failed")
      client.ready
      client.expect('Q')
      client.send('G', Bytes[0, 0, 1, 0, 0])
      refused << client.expect_type('f')
      client.error("57014", "COPY from stdin failed")
      client.ready
    end
    session = connect(server)
    expect_raises(PG::QueryCanceled) { session.query("COPY t FROM STDIN") }
    expect_raises(PG::QueryCanceled) { session.copy_out("COPY t FROM STDIN") { |_| } }
    session.closed?.should be_false
    refused.should eq ['f', 'S', 'f']
  end

  it "refuses to pipeline a COPY" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
    end
    session = connect(server)
    expect_raises(ArgumentError, /COPY cannot be pipelined/) { session.pipeline([{"  copy t from stdin", [] of Types::Param}]) }
    session.closed?.should be_false
  end

  it "re-raises an IO error from the caller's own block unchanged, without treating the connection as lost" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('Q')
      client.send('G', Bytes[0, 0, 1, 0, 0])
      client.expect('f')
      client.error("57014", "COPY from stdin failed")
      client.ready
    end
    session = connect(server)
    error = expect_raises(IO::Error, "disk gone") { session.copy_in("COPY t FROM STDIN") { |_| raise IO::Error.new("disk gone") } }
    error.should_not be_a PG::ConnectionLost
    session.closed?.should be_false
  end

  it "stops calling a copy_out block once it raised, still reads the rest, and keeps the session" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('Q')
      client.send('H', Bytes[0, 0, 1, 0, 0])
      3.times { |index| client.send('d', "row #{index}\n".to_slice) }
      client.send('c')
      client.command_complete("COPY 3")
      client.ready
      client.expect('Q')
      client.command_complete("OK")
      client.ready
    end
    session = connect(server)
    seen = [] of String
    expect_raises(Exception, "sink full") do
      session.copy_out("COPY t TO STDOUT") do |chunk|
        seen << String.new(chunk)
        raise "sink full"
      end
    end
    seen.should eq ["row 0\n"]
    session.closed?.should be_false
    session.simple_query("SELECT 1").size.should eq 1
  end

  it "refuses to write to a COPY stream after its block ended" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('Q')
      client.send('G', Bytes[0, 0, 1, 0, 0])
      client.read_message
      client.command_complete("COPY 0")
      client.ready
    end
    escaped = nil
    connect(server).copy_in("COPY t FROM STDIN") { |copy| escaped = copy }
    expect_raises(PG::Error, /only usable inside/) { escaped.not_nil! << "late" }
  end

  it "re-prepares a statement that went stale inside a pipeline on the next call" do
    received = [] of Char
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.serve_prepare([] of UInt32, int4_column)
      client.expect('B'); client.expect('E'); client.expect('S')
      client.send('2')
      client.error("0A000", "cached plan must not change result type", {'R' => "RevalidateCachedQuery"})
      client.ready
      client.expect('C'); client.expect('P'); client.expect('D'); client.expect('S')
      client.send('3'); client.send('1'); client.parameter_description([] of UInt32); client.row_description(int4_column); client.ready
      client.serve_execute([[be_int32(42).as(Bytes?)]], "SELECT 1")
      received.concat(client.received)
    end
    session = connect(server)
    statement = {"SELECT n FROM t", [] of Types::Param}
    session.pipeline([statement]).first.as(PG::ServerError).stale_plan?.should be_true
    session.pipeline([statement]).first.as(PG::Result).rows.should eq [[42]]
    received.should eq ['P', 'D', 'S', 'B', 'E', 'S', 'C', 'P', 'D', 'S', 'B', 'E', 'S']
  end

  it "raises the server's FATAL error when the server then hangs up" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('Q')
      client.error("57P01", "terminating connection due to administrator command", {'S' => "FATAL", 'V' => "FATAL"})
    end
    session = connect(server)
    error = expect_raises(PG::ServerError, /57P01/) { session.simple_query("SELECT pg_sleep(10)") }
    error.severity.should eq "FATAL"
    session.closed?.should be_true
  end

  it "re-prepares after the server forgot its prepared statements, but only once" do
    prepares = 0
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      3.times do
        client.serve_prepare([] of UInt32, int4_column)
        prepares += 1
        client.expect('B'); client.expect('E'); client.expect('S')
        client.send('2')
        client.error("26000", "prepared statement \"cql_1\" does not exist")
        client.ready
      end
    end
    session = connect(server)
    expect_raises(PG::ServerError, /26000/) { session.query("SELECT n FROM t") }
    session.closed?.should be_false
    prepares.should eq 2
  end

  it "recovers from DEALLOCATE ALL by preparing again" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.serve_prepare([] of UInt32, int4_column)
      client.expect('B'); client.expect('E'); client.expect('S')
      client.send('2')
      client.error("26000", "prepared statement \"cql_1\" does not exist")
      client.ready
      serve_select_42(client)
    end
    connect(server).query("SELECT n FROM t").rows.should eq [[42]]
  end

  it "drops the session when a timed-out statement cannot be canceled, instead of waiting forever" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.serve_prepare([] of UInt32, int4_column)
      client.expect('B'); client.expect('E'); client.expect('S')
      client.read_message # blocks until the client hangs up
    end
    session = connect(server)
    server.close # no new connections: the cancel request cannot be delivered
    started = Time.instant
    expect_raises(PG::QueryTimeout, /could not be delivered/) { session.query("SELECT pg_sleep(10)", timeout: 100.milliseconds) }
    (Time.instant - started).should be < 3.seconds
    session.closed?.should be_true
  end

  it "forgets a stale statement even inside a transaction, so the next attempt after rollback re-prepares" do
    received = [] of Char
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('Q'); client.command_complete("BEGIN"); client.ready('T')
      client.serve_prepare([] of UInt32, int4_column)
      client.expect('B'); client.expect('E'); client.expect('S')
      client.send('2')
      client.error("0A000", "cached plan must not change result type", {'R' => "RevalidateCachedQuery"})
      client.ready('E')
      client.expect('Q'); client.command_complete("ROLLBACK"); client.ready
      client.expect('C'); client.expect('P'); client.expect('D'); client.expect('S')
      client.send('3'); client.send('1'); client.parameter_description([] of UInt32); client.row_description(int4_column); client.ready
      client.serve_execute([[be_int32(42).as(Bytes?)]], "SELECT 1")
      received.concat(client.received)
    end
    session = connect(server)
    session.simple_query("BEGIN")
    expect_raises(PG::ServerError, /0A000/) { session.query("SELECT n FROM t") }
    session.simple_query("ROLLBACK")
    session.query("SELECT n FROM t").rows.should eq [[42]]
    received.should eq ['Q', 'P', 'D', 'S', 'B', 'E', 'S', 'Q', 'C', 'P', 'D', 'S', 'B', 'E', 'S']
  end

  it "closes quietly even when the TLS layer fails to shut down" do
    outcome = PG::Handshake::Outcome.new(1, Bytes[0, 0, 0, 2], {} of String => String, 'I')
    session = PG::Session.new(PG::Config.new, ScriptedIO.new(close_raises: true), outcome)
    session.hard_close
    session.closed?.should be_true
  end

  it "reports a failed write as a lost connection, with the session closed" do
    outcome = PG::Handshake::Outcome.new(1, Bytes[0, 0, 0, 2], {} of String => String, 'I')
    session = PG::Session.new(PG::Config.new, ScriptedIO.new(fail_writes_after: 0), outcome)
    expect_raises(PG::ConnectionLost, /Broken pipe/) { session.simple_query("SELECT 1") }
    session.closed?.should be_true
  end

  it "reports a connection that dies while streaming COPY data as lost, not as a raw IO error" do
    copy_in_response = FakePG.frame('G', Bytes[0, 0, 1, 0, 0])
    outcome = PG::Handshake::Outcome.new(1, Bytes[0, 0, 0, 2], {} of String => String, 'I')
    session = PG::Session.new(PG::Config.new, ScriptedIO.new(copy_in_response, fail_writes_after: 1), outcome)
    expect_raises(PG::ConnectionLost, /Broken pipe/) { session.copy_in("COPY t FROM STDIN") { |copy| copy.write(Bytes.new(100_000)) } }
    session.closed?.should be_true
  end

  it "raises a server FATAL that arrives in the middle of a pipeline instead of a closed-stream error" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      3.times { client.expect('P'); client.expect('D'); client.expect('S') }
      3.times do
        client.send('1'); client.parameter_description([] of UInt32); client.row_description(int4_column); client.ready
      end
      9.times { client.read_message }
      client.send('2'); client.data_row([be_int32(1).as(Bytes?)]); client.command_complete("SELECT 1"); client.ready
      client.error("57P01", "terminating connection due to administrator command", {'S' => "FATAL", 'V' => "FATAL"})
    end
    session = connect(server)
    statements = [{"SELECT 1", [] of Types::Param}, {"SELECT 2", [] of Types::Param}, {"SELECT 3", [] of Types::Param}]
    error = expect_raises(PG::ServerError, /57P01/) { session.pipeline(statements) }
    error.severity.should eq "FATAL"
    session.closed?.should be_true
  end

  it "bounds a whole pipeline by its timeout: the running statement is canceled, the rest abandoned" do
    canceled = Channel(Nil).new(1)
    server = FakePG.start do |client|
      startup = client.read_startup
      if startup["protocol"] == "cancel"
        canceled.send(nil)
        next
      end
      client.ok_handshake
      3.times { client.expect('P'); client.expect('D'); client.expect('S') }
      3.times do
        client.send('1'); client.parameter_description([] of UInt32); client.row_description(int4_column); client.ready
      end
      9.times { client.read_message }
      canceled.receive
      client.send('2'); client.error("57014", "canceling statement due to user request"); client.ready
      sleep 2.seconds # the remaining statements would take this long
    end
    session = connect(server)
    statements = [{"SELECT 1", [] of Types::Param}, {"SELECT 2", [] of Types::Param}, {"SELECT 3", [] of Types::Param}]
    started = Time.instant
    expect_raises(PG::QueryTimeout, /pipeline timed out/) { session.pipeline(statements, timeout: 150.milliseconds) }
    (Time.instant - started).should be < 1.5.seconds
    session.closed?.should be_true
  end

  it "rejects a COPY anywhere in a pipeline, comments included, before any statement is sent" do
    received = [] of Char
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.read_message
      received.concat(client.received)
    end
    session = connect(server)
    big = Types::ParamEncoder.encode("x" * 40_000)
    ["COPY t FROM STDIN", "/* load */ COPY t FROM STDIN", "-- load\nCOPY t FROM STDIN", "  \n copy t to stdout"].each do |copy|
      expect_raises(ArgumentError, /COPY cannot be pipelined/) do
        session.pipeline([{"SELECT $1", [big]}, {"SELECT $1 || 'again'", [big]}, {copy, [] of Types::Param}])
      end
    end
    session.close
    server.await
    received.should eq ['X']
  end

  it "still closes statements the cache gave up when a later statement could not be encoded" do
    received = [] of Char
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      serve_select_42(client)
      client.expect('C'); client.expect('P'); client.expect('D'); client.expect('S')
      client.send('3'); client.send('1'); client.parameter_description([] of UInt32); client.row_description(int4_column); client.ready
      client.serve_execute([[be_int32(43).as(Bytes?)]], "SELECT 1")
      received.concat(client.received)
    end
    config = PG::Config.parse(server.url(query: "sslmode=disable&statement_cache_size=1"))
    session = PG::Session.connect(config)
    session.query("SELECT a").rows.should eq [[42]]
    expect_raises(ArgumentError, /NUL/) { session.pipeline([{"SELECT b", [] of Types::Param}, {"SELECT 'x\0'", [] of Types::Param}]) }
    session.query("SELECT c").rows.should eq [[43]]
    received.should eq ['P', 'D', 'S', 'B', 'E', 'S', 'C', 'P', 'D', 'S', 'B', 'E', 'S']
  end

  it "treats a failing TLS stream like any lost connection, on requests and on close" do
    outcome = PG::Handshake::Outcome.new(1, Bytes[0, 0, 0, 2], {} of String => String, 'I')
    session = PG::Session.new(PG::Config.new, ScriptedIO.new(fail_writes_after: 0, tls_failure: true), outcome)
    expect_raises(PG::ConnectionLost, /SSL_write/) { session.simple_query("SELECT 1") }
    session.closed?.should be_true

    closing = PG::Session.new(PG::Config.new, ScriptedIO.new(fail_writes_after: 0, tls_failure: true), outcome)
    closing.close
    closing.closed?.should be_true
  end

  it "reports a copy_in whose cancel could not be delivered as a timeout, not as a lost connection" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('Q')
      client.send('G', Bytes[0, 0, 1, 0, 0])
      sleep 3.seconds # never reads, so the client's writes eventually block
    end
    session = connect(server)
    server.close # the cancel request has nowhere to go
    started = Time.instant
    expect_raises(PG::QueryTimeout, /could not be delivered/) do
      session.copy_in("COPY t FROM STDIN", timeout: 150.milliseconds) { |copy| loop { copy.write(Bytes.new(65_536)) } }
    end
    (Time.instant - started).should be < 2.seconds
    session.closed?.should be_true
  end

  it "retries with protocol 3.0 when the server rejects the newer version outright" do
    asked = [] of String
    server = FakePG.start do |client|
      asked << client.read_startup["protocol"]
      if asked.size == 1
        client.error("0A000", "unsupported frontend protocol 3.2: server supports 1.0 to 3.0", {'S' => "FATAL", 'V' => "FATAL"})
      else
        client.ok_handshake
      end
    end
    session = connect(server)
    asked.should eq ["3.2", "3.0"]
    session.protocol_version.should eq CQL::Postgres::ProtocolVersion::V3_0
  end

  it "tries exactly twice when both versions are rejected, and not at all when 3.0 is the ceiling" do
    asked = [] of String
    server = FakePG.start do |client|
      asked << client.read_startup["protocol"]
      client.error("08P01", "unsupported protocol", {'S' => "FATAL", 'V' => "FATAL"})
    end
    expect_raises(PG::ServerError, /08P01/) { connect(server) }
    asked.should eq ["3.2", "3.0"]

    capped = [] of String
    ceiling = FakePG.start do |client|
      capped << client.read_startup["protocol"]
      client.error("0A000", "unsupported frontend protocol", {'S' => "FATAL", 'V' => "FATAL"})
    end
    config = PG::Config.parse(ceiling.url(query: "sslmode=disable&max_protocol_version=3.0"))
    expect_raises(PG::ServerError, /0A000/) { PG::Session.connect(config) }
    capped.should eq ["3.0"]
  end

  it "retries with protocol 3.0 when the first reply is not a protocol message (CockroachDB answers HTTP/2)" do
    asked = [] of String
    server = FakePG.start do |client|
      asked << client.read_startup["protocol"]
      if asked.size == 1
        client.io.write(Bytes[0, 0, 0x12, 0x04, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0x40, 0, 0, 3, 0x7f])
      else
        client.ok_handshake
      end
    end
    connect(server).protocol_version.should eq CQL::Postgres::ProtocolVersion::V3_0
    asked.should eq ["3.2", "3.0"]
  end

  it "retries once when the first reply is garbage, never a third time, and not when 3.0 is the floor or ceiling" do
    garbage = Bytes[0, 0, 0x12, 0x04, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0x40, 0, 0, 3, 0x7f]
    asked = [] of String
    server = FakePG.start do |client|
      asked << client.read_startup["protocol"]
      client.io.write(garbage)
    end
    expect_raises(PG::UnrecognizedStartupReply) { connect(server) }
    asked.should eq ["3.2", "3.0"]

    floor = [] of String
    pinned = FakePG.start do |client|
      floor << client.read_startup["protocol"]
      client.io.write(garbage)
    end
    expect_raises(PG::UnrecognizedStartupReply) { PG::Session.connect(PG::Config.parse(pinned.url(query: "sslmode=disable&min_protocol_version=3.2"))) }
    expect_raises(PG::UnrecognizedStartupReply) { PG::Session.connect(PG::Config.parse(pinned.url(query: "sslmode=disable&max_protocol_version=3.0"))) }
    floor.should eq ["3.2", "3.0"]
  end

  it "keeps garbage that arrives after a valid message a plain protocol error" do
    server = FakePG.start do |client|
      client.read_startup
      client.auth(0)
      client.io.write(Bytes[0, 0, 0x12, 0x04, 0, 0, 0, 0])
    end
    error = expect_raises(PG::ProtocolError) { connect(server) }
    error.should_not be_a PG::UnrecognizedStartupReply
  end

  it "explains prepared-statement collisions behind a transaction-mode pooler" do
    PG::ServerError.from({'S' => "ERROR", 'C' => "42P05", 'M' => "prepared statement \"cql_1\" already exists"}).message.to_s.should contain "statement_cache_size=0"
    PG::ServerError.from({'S' => "ERROR", 'C' => "26000", 'M' => "prepared statement \"cql_1\" does not exist"}).message.to_s.should contain "statement_cache_size=0"
  end

  it "ends the open request with a Sync when an unnamed statement cannot be bound, and stays usable" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('P'); client.expect('D'); client.expect('H')
      client.send('1'); client.parameter_description([23_u32]); client.row_description(int4_column)
      client.expect('S'); client.ready # the wrong parameter count is caught before any Bind
      client.idle
    end
    session = PG::Session.connect(PG::Config.parse(server.url(query: "sslmode=disable&statement_cache_size=0")))
    expect_raises(ArgumentError, /takes 1 parameters/) { session.query("SELECT n FROM t WHERE n = $1") }
    session.closed?.should be_false
    session.ping.should be_true
  end

  it "describes a statement without rows (NoData) and runs it in the same request" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('P'); client.expect('D'); client.expect('H')
      client.send('1'); client.parameter_description([] of UInt32); client.send('n')
      client.expect('B'); client.expect('E'); client.expect('S')
      client.send('2'); client.command_complete("INSERT 0 1"); client.ready
    end
    session = PG::Session.connect(PG::Config.parse(server.url(query: "sslmode=disable&statement_cache_size=0")))
    session.query("INSERT INTO t DEFAULT VALUES").rows_affected.should eq 1
  end

  it "raises the server's FATAL, not a lost connection, when it hangs up while describing the unnamed statement" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('P'); client.expect('D'); client.expect('H')
      client.error("57P01", "terminating connection due to administrator command", {'S' => "FATAL", 'V' => "FATAL"})
    end
    session = PG::Session.connect(PG::Config.parse(server.url(query: "sslmode=disable&statement_cache_size=0")))
    expect_raises(PG::ServerError, /57P01/) { session.query("SELECT 1") }
    session.closed?.should be_true
  end

  it "ends the open request with a Sync when describing the unnamed statement fails" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.expect('P'); client.expect('D'); client.expect('H')
      client.error("42601", "syntax error")
      client.expect('S'); client.ready
      client.idle
    end
    session = PG::Session.connect(PG::Config.parse(server.url(query: "sslmode=disable&statement_cache_size=0")))
    expect_raises(PG::ServerError) { session.query("SELEC") }
    session.ping.should be_true
  end

  it "gives up on a ping the server never answers and closes the socket" do
    server = FakePG.start do |client|
      client.read_startup
      client.ok_handshake
      client.read_message # the ping, never answered
      sleep 5.seconds
    end
    session = connect(server)
    started = Time.instant
    session.ping(200.milliseconds).should be_false
    (Time.instant - started).should be < 2.seconds
    session.closed?.should be_true
  end

  it "closes the socket when a timed-out request is still blocked after the cancel grace" do
    server = FakePG.start do |client|
      startup = client.read_startup
      next if startup["protocol"] == "cancel" # the cancel request: accepted, never acted on
      client.ok_handshake
      client.read_message
      sleep 5.seconds
    end
    session = connect(server)
    session.cancel_grace = 200.milliseconds
    started = Time.instant
    expect_raises(PG::QueryTimeout) { session.query("SELECT 1", timeout: 200.milliseconds) }
    (Time.instant - started).should be < 3.seconds
    session.closed?.should be_true
  end

  it "hard-closes the socket under the stream, not the stream's own close (a TLS close_notify could block)" do
    stream = ScriptedIO.new
    socket = ScriptedIO.new
    config = PG::Config.parse("postgres://u@127.0.0.1/db")
    session = PG::Session.new(config, stream, PG::Handshake::Outcome.new(1, Bytes[0, 0, 0, 1], {} of String => String, 'I', PG::ProtocolVersion::V3_0), socket)
    session.hard_close
    session.closed?.should be_true
    socket.closed?.should be_true
    stream.closed?.should be_false
  end

  it "bounds a timed-out request by the grace even when the cancel peer accepts the connection and never hangs up" do
    server = FakePG.start do |client|
      startup = client.read_startup
      if startup["protocol"] == "cancel"
        sleep 5.seconds # accepts the cancel and never hangs up
        next
      end
      client.ok_handshake
      client.read_message
      sleep 5.seconds
    end
    session = connect(server)
    session.cancel_grace = 200.milliseconds
    started = Time.instant
    expect_raises(PG::QueryTimeout) { session.query("SELECT 1", timeout: 100.milliseconds) }
    (Time.instant - started).should be < 2.seconds
    session.closed?.should be_true
  end

  it "does not take a cancel the driver raised itself for the server's confirmation, and drops the session" do
    server = FakePG.start do |client|
      startup = client.read_startup
      next if startup["protocol"] == "cancel"
      client.ok_handshake
      client.serve_prepare([] of UInt32, [{"n", 23_u32}])
      client.expect('B'); client.expect('E'); client.expect('H')
      client.send('2'); client.data_row([Bytes[0, 0, 0, 1]] of Bytes?); client.send('s')
      sleep 3.seconds
    end
    session = connect(server)
    expect_raises(PG::QueryTimeout) do
      session.stream("SELECT n", fetch_size: 1, timeout: 150.milliseconds) do |rows|
        rows.next
        sleep 400.milliseconds # the deadline passes: the watchdog cancels, no Close/Sync can follow
        raise PG::QueryCanceled.user_request
      end
    end
    session.closed?.should be_true # a portal is still open and nothing confirmed the cancel
  end

  it "starts cockroachdb:// URLs at protocol 3.0" do
    PG::Config.parse("cockroachdb://root@h/db").max_protocol_version.should eq CQL::Postgres::ProtocolVersion::V3_0
    PG::Config.parse("cockroachdb://root@h/db?max_protocol_version=3.2").max_protocol_version.should eq CQL::Postgres::ProtocolVersion::V3_2
    PG::Config.parse("postgres://root@h/db").max_protocol_version.should eq CQL::Postgres::ProtocolVersion::V3_2
  end

  it "recognises a stale plan by the server's message when the routine is not reported" do
    error = PG::ServerError.from({'S' => "ERROR", 'C' => "0A000", 'M' => "cached plan must not change result type"})
    error.stale_plan?.should be_true
    PG::ServerError.from({'S' => "ERROR", 'C' => "0A000", 'M' => "feature not supported"}).stale_plan?.should be_false
  end

  it "does not retry a rejection when the minimum version forbids 3.0, or for other errors" do
    asked = [] of String
    server = FakePG.start do |client|
      asked << client.read_startup["protocol"]
      client.error("0A000", "unsupported frontend protocol 3.2", {'S' => "FATAL", 'V' => "FATAL"})
    end
    config = PG::Config.parse(server.url(query: "sslmode=disable&min_protocol_version=3.2"))
    expect_raises(PG::ServerError, /0A000/) { PG::Session.connect(config) }
    asked.should eq ["3.2"]

    auth_failure = [] of String
    other = FakePG.start do |client|
      auth_failure << client.read_startup["protocol"]
      client.error("28P01", "password authentication failed")
    end
    expect_raises(PG::InvalidAuthorization) { connect(other) }
    auth_failure.should eq ["3.2"]
  end

  it "cancels with the full secret key of a protocol 3.2 session" do
    key = Bytes.new(32) { |index| (index + 1).to_u8 }
    received = Channel(Hash(String, String)).new(1)
    server = FakePG.start do |client|
      startup = client.read_startup
      if startup["protocol"] == "cancel"
        received.send(startup)
        next
      end
      client.ok_handshake(secret: key)
    end
    session = connect(server)
    session.cancel
    select
    when startup = received.receive
      startup["secret"].should eq key.hexstring
      startup["pid"].should eq "4242"
    when timeout(2.seconds)
      fail "no cancel request arrived"
    end
  end
end
