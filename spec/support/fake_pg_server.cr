require "socket"
require "digest/sha256"
require "openssl/hmac"
require "openssl/pkcs5"
require "base64"

# A scripted PostgreSQL server on a loopback port. It builds and parses frames
# by hand (no driver code), so specs exercise the real wire format.
class FakePG
  # One accepted client connection with helpers to read frontend and write
  # backend messages.
  class Client
    getter io : TCPSocket
    getter received = [] of Char

    def initialize(@io : TCPSocket)
    end

    def read_startup : Hash(String, String)
      length = @io.read_bytes(Int32, IO::ByteFormat::NetworkEndian)
      body = Bytes.new(length - 4)
      @io.read_fully(body)
      protocol = IO::ByteFormat::NetworkEndian.decode(Int32, body[0, 4])
      if protocol == 80877102
        return {"protocol" => "cancel", "pid" => IO::ByteFormat::NetworkEndian.decode(Int32, body[4, 4]).to_s,
                "secret" => body[8..].hexstring}
      end
      return {"protocol" => protocol.to_s} unless protocol >> 16 == 3
      pairs = String.new(body[4..]).split('\0')
      {"protocol" => "#{protocol >> 16}.#{protocol & 0xffff}"}.merge(pairs.each_slice(2).select { |pair| pair.size == 2 && !pair[0].empty? }.to_h { |pair| {pair[0], pair[1]} })
    end

    # {type, payload}; nil when the client hung up.
    def read_message : {Char, Bytes}?
      type = @io.read_byte || return nil
      length = @io.read_bytes(Int32, IO::ByteFormat::NetworkEndian)
      payload = Bytes.new(length - 4)
      @io.read_fully(payload)
      @received << type.chr
      {type.chr, payload}
    end

    def expect(type : Char) : Bytes
      message = read_message || raise "client closed while the server expected #{type}"
      raise "expected #{type}, got #{message[0]}" unless message[0] == type
      message[1]
    end

    # Like `expect`, returning the message type for specs that record it.
    def expect_type(type : Char) : Char
      expect(type)
      type
    end

    def cstrings(payload : Bytes) : Array(String)
      String.new(payload).split('\0')
    end

    def send(type : Char, payload : Bytes = Bytes.empty) : Nil
      @io.write(FakePG.frame(type, payload))
      @io.flush
    end

    def int32(value : Int32) : Bytes
      Bytes.new(4).tap { |bytes| IO::ByteFormat::NetworkEndian.encode(value, bytes) }
    end

    def int16(value : Int16) : Bytes
      Bytes.new(2).tap { |bytes| IO::ByteFormat::NetworkEndian.encode(value, bytes) }
    end

    def build(&) : Bytes
      memory = IO::Memory.new
      yield memory
      memory.to_slice
    end

    def cstr(io : IO, text : String) : Nil
      io << text
      io.write_byte(0_u8)
    end

    def auth(code : Int32, extra : Bytes = Bytes.empty) : Nil
      send('R', int32(code) + extra)
    end

    def ok_handshake(parameters = {"server_version" => "16.0", "client_encoding" => "UTF8"}, pid = 4242, secret : Int32 | Bytes = 777) : Nil
      auth(0)
      parameters.each { |name, value| send('S', build { |io| cstr(io, name); cstr(io, value) }) }
      send('K', int32(pid) + (secret.is_a?(Bytes) ? secret : int32(secret)))
      ready
    end

    def ready(status : Char = 'I') : Nil
      send('Z', Bytes[status.ord.to_u8])
    end

    # Columns as {name, type_oid}.
    def row_description(columns : Array({String, UInt32})) : Nil
      send('T', build do |io|
        io.write(int16(columns.size.to_i16))
        columns.each do |(name, oid)|
          cstr(io, name)
          io.write(int32(0)); io.write(int16(0_i16))
          io.write(int32(oid.to_i32)); io.write(int16(4_i16)); io.write(int32(-1)); io.write(int16(0_i16))
        end
      end)
    end

    def data_row(values : Array(Bytes?)) : Nil
      send('D', build do |io|
        io.write(int16(values.size.to_i16))
        values.each do |value|
          if value
            io.write(int32(value.size)); io.write(value)
          else
            io.write(int32(-1))
          end
        end
      end)
    end

    def command_complete(tag : String) : Nil
      send('C', build { |io| cstr(io, tag) })
    end

    def error(code : String, message : String, extra = {} of Char => String) : Nil
      fields = {'S' => "ERROR", 'V' => "ERROR", 'C' => code, 'M' => message}.merge(extra)
      send('E', build do |io|
        fields.each { |key, value| io.write_byte(key.ord.to_u8); cstr(io, value) }
        io.write_byte(0_u8)
      end)
    end

    def notice(message : String) : Nil
      send('N', build { |io| io.write_byte('M'.ord.to_u8); cstr(io, message); io.write_byte(0_u8) })
    end

    def parameter_description(oids : Array(UInt32)) : Nil
      send('t', int16(oids.size.to_i16) + build { |io| oids.each { |oid| io.write(int32(oid.to_i32)) } })
    end

    # Answers Parse + Describe(S) + Sync for a statement with the given shape.
    def serve_prepare(param_oids : Array(UInt32), columns : Array({String, UInt32})) : Nil
      expect('P'); expect('D'); expect('S')
      send('1')
      parameter_description(param_oids)
      columns.empty? ? send('n') : row_description(columns)
      ready
    end

    # Answers Bind + Execute + Sync with the given rows (text/binary as supplied).
    def serve_execute(rows : Array(Array(Bytes?)), tag : String) : Nil
      expect('B'); expect('E'); expect('S')
      send('2')
      rows.each { |row| data_row(row) }
      command_complete(tag)
      ready
    end

    # Answers empty queries (pings) and any other simple query with OK until the client leaves.
    def idle(&on_query : String ->) : Nil
      while message = read_message
        case message[0]
        when 'Q'
          sql = String.new(message[1]).chomp('\0')
          on_query.call(sql)
          sql.empty? ? send('I') : command_complete("OK")
          ready
        when 'X' then break
        else          raise "unexpected message #{message[0]}"
        end
      end
    end

    def idle : Nil
      idle { |_| }
    end
  end

  @@running = [] of FakePG

  # One backend message, built by hand.
  def self.frame(type : Char, payload : Bytes = Bytes.empty) : Bytes
    frame = IO::Memory.new
    frame.write_byte(type.ord.to_u8)
    frame.write_bytes(payload.size + 4, IO::ByteFormat::NetworkEndian)
    frame.write(payload)
    frame.to_slice
  end

  getter port : Int32
  getter failures = [] of Exception
  # Connections accepted so far, and the most that were open at once.
  getter accepted = 0
  getter max_open = 0
  @open = 0
  @finished = Channel(Nil).new(1024)
  @server : TCPServer

  def initialize(&@script : Client ->)
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.local_address.port
    spawn(name: "fake-pg") { accept_loop }
  end

  # Starts a server for one example; `FakePG.finish` (run after each example)
  # closes it and re-raises anything its script raised, assertions included.
  def self.start(&script : Client ->) : FakePG
    new(&script).tap { |server| @@running << server }
  end

  def self.finish : Nil
    servers = @@running.dup
    @@running.clear
    servers.each(&.close)
    failure = servers.flat_map(&.failures).first?
    raise failure if failure
  end

  def url(user = "ada", password : String? = "secret", database = "app", query = "sslmode=disable") : String
    credentials = password ? "#{user}:#{password}" : user
    "postgres://#{credentials}@127.0.0.1:#{@port}/#{database}?#{query}"
  end

  # Blocks until one more client script has run to its end.
  def await(timeout : Time::Span = 3.seconds) : Nil
    select
    when @finished.receive
    when timeout(timeout)
      raise "the fake server's client script did not finish within #{timeout}"
    end
  end

  def close : Nil
    @server.close
  end

  private def accept_loop : Nil
    while accepted = @server.accept?
      serve(accepted)
    end
  end

  private def serve(socket : TCPSocket) : Nil
    socket.sync = true
    client = Client.new(socket)
    @accepted += 1
    @max_open = Math.max(@max_open, @open += 1)
    spawn(name: "fake-pg-client") do
      @script.call(client)
    rescue IO::Error
    rescue ex
      @failures << ex
    ensure
      @open -= 1
      socket.close rescue nil
      @finished.send(nil)
    end
  end
end

# Server half of SCRAM-SHA-256 (RFC 5802), written from the RFC so a client
# implemented from the same RFC is checked against an independent computation.
class FakeScramServer
  @password : String

  # The server stores the SASLprep-normalised password.
  def initialize(password : String, @salt : Bytes = "saltsaltsalt".to_slice, @iterations : Int32 = 4096)
    @password = password.unicode_normalize(Unicode::NormalizationForm::NFKC)
  end

  def run(client : FakePG::Client) : Bool
    payload = client.expect('p')
    mechanism_end = payload.index!(0_u8)
    initial_length = IO::ByteFormat::NetworkEndian.decode(Int32, payload[mechanism_end + 1, 4])
    client_first = String.new(payload[mechanism_end + 5, initial_length])
    bare = client_first.sub(/\An,,/, "")
    client_nonce = bare.split(',').find!(&.starts_with?("r=")).sub("r=", "")
    nonce = client_nonce + "ServerPart"
    server_first = "r=#{nonce},s=#{Base64.strict_encode(@salt)},i=#{@iterations}"
    client.auth(11, server_first.to_slice)

    client_final = String.new(client.expect('p'))
    without_proof, _, proof_part = client_final.rpartition(",p=")
    salted = OpenSSL::PKCS5.pbkdf2_hmac(@password, @salt, @iterations, OpenSSL::Algorithm::SHA256, 32)
    client_key = OpenSSL::HMAC.digest(OpenSSL::Algorithm::SHA256, salted, "Client Key")
    stored_key = Digest::SHA256.digest(client_key)
    auth_message = "#{bare},#{server_first},#{without_proof}"
    signature = OpenSSL::HMAC.digest(OpenSSL::Algorithm::SHA256, stored_key, auth_message)
    expected_proof = Bytes.new(32) { |index| client_key[index] ^ signature[index] }
    valid = Base64.decode(proof_part) == expected_proof
    server_key = OpenSSL::HMAC.digest(OpenSSL::Algorithm::SHA256, salted, "Server Key")
    server_signature = OpenSSL::HMAC.digest(OpenSSL::Algorithm::SHA256, server_key, auth_message)
    client.auth(12, "v=#{Base64.strict_encode(server_signature)}".to_slice) if valid
    valid
  end
end

# A stream that replays prepared backend frames and can fail like a broken
# socket, to reach error paths a real loopback connection cannot be made to hit.
class ScriptedIO < IO
  getter written = IO::Memory.new

  def initialize(backend_frames : Bytes = Bytes.empty, @fail_writes_after : Int32? = nil, @close_raises : Bool = false, @tls_failure : Bool = false)
    @input = IO::Memory.new(backend_frames)
    @writes = 0
  end

  def read(slice : Bytes) : Int32
    @input.read(slice)
  end

  def write(slice : Bytes) : Nil
    @writes += 1
    limit = @fail_writes_after
    if limit && @writes > limit
      raise OpenSSL::Error.new("SSL_write: broken pipe") if @tls_failure
      raise IO::Error.new("Broken pipe")
    end
    @written.write(slice)
  end

  def close : Nil
    raise OpenSSL::Error.new("SSL_shutdown: shutdown while in init") if @close_raises
    super
  end
end

Spec.after_each { FakePG.finish }
