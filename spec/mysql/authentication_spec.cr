require "spec"
require "../../src/cql/mysql"

private alias Auth = CQL::MySQL::Authentication
private alias AuthError = CQL::MySQL::AuthenticationError
private alias MyOptions = CQL::MySQL::Options

private def mysql_options(port = 3306, extra = "ssl-mode=disabled")
  MyOptions.from_uri(URI.parse("mysql://user:secret@127.0.0.1:#{port}/test?#{extra}"))
end

private def mysql_packet(socket : IO, sequence : UInt8, payload : Bytes)
  socket.write(Bytes[payload.size.to_u8!, (payload.size >> 8).to_u8!, (payload.size >> 16).to_u8!, sequence])
  socket.write(payload)
  socket.flush
end

private def mysql_read(socket : IO) : Bytes
  header = Bytes.new(4)
  socket.read_fully(header)
  size = header[0].to_i | header[1].to_i << 8 | header[2].to_i << 16
  bytes = Bytes.new(size)
  socket.read_fully(bytes)
  bytes
end

private def mysql_hello(plugin = "caching_sha2_password", tls = false) : Bytes
  io = IO::Memory.new
  io.write_byte(10)
  io << "8.4.0\0"
  io.write_bytes(1_u32, IO::ByteFormat::LittleEndian)
  io << "12345678\0"
  flags = Auth::PROTOCOL_41 | Auth::SECURE_CONNECTION | Auth::PLUGIN_AUTH
  flags |= Auth::SSL if tls
  io.write_bytes(flags.to_u16!, IO::ByteFormat::LittleEndian)
  io.write_byte(45)
  io.write_bytes(2_u16, IO::ByteFormat::LittleEndian)
  io.write_bytes((flags >> 16).to_u16, IO::ByteFormat::LittleEndian)
  io.write_byte(21)
  io.write(Bytes.new(10))
  io << "901234567890\0" << plugin << '\0'
  io.to_slice
end

private def mysql_server(&block : TCPSocket -> Nil)
  server = TCPServer.new("127.0.0.1", 0)
  result = Channel(Exception?).new(1)
  spawn do
    error = begin
      socket = server.accept
      socket.read_timeout = socket.write_timeout = 2.seconds
      block.call(socket)
      nil
    rescue ex
      ex
    ensure
      socket.try(&.close)
    end
    result.send(error)
  end
  {server, result}
end

private def mysql_finish(server, result)
  server.close
  if error = result.receive
    raise error
  end
end

describe CQL::MySQL::Authentication do
  it "defaults to identity verification and redacts both option renderings" do
    options = mysql_options(extra: "")
    options.tls.should be_true
    options.verify.should be_true
    options.inspect.should_not contain "secret"
    options.to_s.should_not contain "secret"
    options.timeout.should eq 5.seconds
  end

  it "rejects unsupported policies, invalid deadlines and embedded NULs" do
    ["ssl-mode=preferred", "connect_timeout=nan", "connect_timeout=-1", "connect_timeout=0", "connect_timeout=no", "connect_timeout=301"].each do |query|
      expect_raises(ArgumentError) { mysql_options(extra: query) }
    end
    expect_raises(ArgumentError) { MyOptions.from_uri(URI.parse("mysql://user:secret%00@localhost/db")) }
  end

  it "matches independently computed SHA256 and legacy SHA1 scrambles" do
    nonce = "12345678901234567890".to_slice
    Auth.scramble("caching_sha2_password", "secret", nonce).hexstring.should eq "51ecd6dedbd34d5445c0a190d4f51acf0d23b94db66c91f3f789faa9193751cd"
    Auth.scramble("mysql_native_password", "secret", nonce).hexstring.should eq "0f8b9033e0897c0a8338ebe3dea9010dda47ab56"
    Auth.scramble("caching_sha2_password", "", nonce).should be_empty
    error = expect_raises(AuthError) { Auth.scramble("secret echoed by server", "secret", nonce) }
    error.message.to_s.should_not contain "secret"
    expect_raises(AuthError) { Auth.scramble("caching_sha2_password", "secret", Bytes[1]) }
  end

  it "handles an authentication switch followed by fast authentication" do
    server, result = mysql_server do |socket|
      mysql_packet(socket, 0_u8, mysql_hello("mysql_native_password"))
      mysql_read(socket)
      mysql_packet(socket, 2_u8, ("\xfe" + "caching_sha2_password\0" + "12345678901234567890\0").to_slice)
      mysql_read(socket).should eq Auth.scramble("caching_sha2_password", "secret", "12345678901234567890".to_slice)
      mysql_packet(socket, 4_u8, Bytes[1, 3])
      mysql_packet(socket, 5_u8, Bytes[0, 0, 0, 2, 0, 0, 0])
    end
    Auth.connect(mysql_options(server.local_address.port)).close
    mysql_finish(server, result)
  end

  it "refuses full password authentication on plaintext without sending the password" do
    server, result = mysql_server do |socket|
      mysql_packet(socket, 0_u8, mysql_hello)
      mysql_read(socket)
      mysql_packet(socket, 2_u8, Bytes[1, 4])
      socket.read_byte.should be_nil
    end
    expect_raises(AuthError, "requires TLS") { Auth.connect(mysql_options(server.local_address.port)) }
    mysql_finish(server, result)
  end

  it "refuses a server without TLS before sending credentials" do
    server, result = mysql_server do |socket|
      mysql_packet(socket, 0_u8, mysql_hello)
      socket.read_byte.should be_nil
    end
    expect_raises(AuthError, "does not offer TLS") { Auth.connect(mysql_options(server.local_address.port, "")) }
    mysql_finish(server, result)
  end

  it "sanitizes server errors and rejects malformed authentication responses" do
    [Bytes[0xff, 0x15, 0x04] + "secret echoed by server".to_slice,
     Bytes[0], Bytes[1, 9], Bytes[1, 3, 0], Bytes[0xfe, 0]].each do |response|
      server, result = mysql_server do |socket|
        mysql_packet(socket, 0_u8, mysql_hello)
        mysql_read(socket)
        mysql_packet(socket, 2_u8, response)
      end
      error = expect_raises(AuthError) { Auth.connect(mysql_options(server.local_address.port)) }
      error.message.to_s.should_not contain "secret"
      mysql_finish(server, result)
    end
  end

  it "rejects oversized, out-of-sequence and truncated greetings" do
    [Bytes[1, 0, 1, 0], Bytes[1, 0, 0, 9, 10], Bytes[1, 0, 0, 0, 10]].each do |bytes|
      server, result = mysql_server { |socket| socket.write(bytes); socket.flush }
      expect_raises(AuthError) { Auth.connect(mysql_options(server.local_address.port)) }
      mysql_finish(server, result)
    end
  end

  it "bounds a stalled TLS handshake before sending credentials" do
    server, result = mysql_server do |socket|
      mysql_packet(socket, 0_u8, mysql_hello(tls: true))
      mysql_read(socket).size.should eq 32 # SSLRequest, no credentials
      sleep 200.milliseconds
    end
    started = Time.instant
    expect_raises(IO::TimeoutError) { Auth.connect(mysql_options(server.local_address.port, "connect_timeout=0.05")) }
    (Time.instant - started).should be < 400.milliseconds
    mysql_finish(server, result)
  end

  it "enforces a total deadline even when the peer trickles bytes" do
    server, result = mysql_server do |socket|
      (Bytes[mysql_hello.size.to_u8, 0, 0, 0] + mysql_hello).each do |byte|
        socket.write_byte(byte)
        socket.flush
        sleep 10.milliseconds
      end
    rescue IO::Error
      # Expected: the client closes the timed-out transport.
    end
    started = Time.instant
    expect_raises(IO::TimeoutError) { Auth.connect(mysql_options(server.local_address.port, "ssl-mode=disabled&connect_timeout=0.05")) }
    (Time.instant - started).should be < 400.milliseconds
    mysql_finish(server, result)
  end
end
