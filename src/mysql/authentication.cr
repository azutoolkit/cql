require "socket"
require "openssl"
require "digest/sha1"
require "digest/sha256"
require "uri"

module CQL::MySQL
  class AuthenticationError < ::DB::Error; end

  record Options, host : String, port : Int32, username : String, password : String,
    database : String?, charset : UInt8, tls : Bool, verify : Bool, ca : String?, timeout : Time::Span do
    def self.from_uri(uri : URI) : self
      params = uri.query_params
      mode = params["ssl-mode"]?.try(&.downcase.tr("-", "_")) || "verify_identity"
      unless {"verify_identity", "required", "disabled"}.includes?(mode)
        raise ArgumentError.new("MySQL ssl-mode must be verify_identity (default), required or disabled")
      end
      seconds = params["connect_timeout"]?.try(&.to_f64?) || 5.0
      unless seconds.finite? && 0 < seconds <= 300
        raise ArgumentError.new("MySQL connect_timeout must be between 0 and 300 seconds, excluding 0")
      end
      raise ArgumentError.new("MySQL connect_timeout must be numeric") if params.has_key?("connect_timeout") && !params["connect_timeout"].to_f64?
      host = uri.hostname.try(&.presence) || raise ArgumentError.new("MySQL integration requires a TCP host")
      username, password = URI.decode(uri.user || ""), URI.decode(uri.password || "")
      database = uri.path.lstrip('/').presence.try { |value| URI.decode(value) }
      if [username, password, database].any? { |value| value.try(&.includes?('\0')) }
        raise ArgumentError.new("MySQL credentials and database must not contain NUL")
      end
      charset = ::MySql::Collations.id_for_collation(params.fetch("encoding", ::MySql::Collations.default_collation)).to_u8
      new(host, uri.port || 3306, username, password, database, charset, mode != "disabled",
        mode == "verify_identity", params["ssl-ca"]?, seconds.seconds)
    end

    def to_s(io : IO) : Nil
      inspect(io)
    end

    def inspect(io : IO) : Nil
      io << "#<CQL::MySQL::Options host=" << host << " port=" << port << ">"
    end
  end

  # Authentication packets are small and bounded. Full caching_sha2_password
  # authentication sends the password only inside TLS. RSA key retrieval and
  # authentication plugins other than caching_sha2_password/mysql_native_password
  # are deliberately unsupported.
  class Authentication
    PROTOCOL_41       = 0x00000200_u32
    SSL               = 0x00000800_u32
    SECURE_CONNECTION = 0x00008000_u32
    PLUGIN_AUTH       = 0x00080000_u32
    CONNECT_WITH_DB   = 0x00000008_u32
    MAX_PACKET        =          65536

    @sequence = 0_u8
    @stream : TCPSocket | OpenSSL::SSL::Socket::Client

    def self.connect(options : Options) : TCPSocket | OpenSSL::SSL::Socket::Client
      deadline = Time.instant + options.timeout
      socket = TCPSocket.new(options.host, options.port, dns_timeout: options.timeout, connect_timeout: options.timeout)
      begin
        remaining = deadline - Time.instant
        raise IO::TimeoutError.new("MySQL authentication exceeded connect_timeout") unless remaining.positive?
        completed = Channel(TCPSocket | OpenSSL::SSL::Socket::Client | Exception).new(1)
        spawn do
          result = begin
            new(options, socket, deadline).run
          rescue ex
            ex
          end
          completed.send(result)
        end
        select
        when result = completed.receive
          raise IO::TimeoutError.new("MySQL authentication exceeded connect_timeout") if Time.instant >= deadline
          raise result if result.is_a?(Exception)
          result
        when timeout(remaining)
          raise IO::TimeoutError.new("MySQL authentication exceeded connect_timeout")
        end
      rescue ex
        socket.close
        raise ex
      end
    end

    def initialize(@options : Options, @socket : TCPSocket, @deadline : Time::Instant)
      @stream = @socket
    end

    def run : TCPSocket | OpenSSL::SSL::Socket::Client
      hello = IO::Memory.new(read_packet)
      raise AuthenticationError.new("unsupported MySQL handshake protocol") unless hello.read_byte == 10
      cstring(hello)                                         # server version; not used to select an authentication policy
      hello.read_bytes(UInt32, IO::ByteFormat::LittleEndian) # connection id
      nonce = Bytes.new(20)
      hello.read_fully(nonce[0, 8])
      hello.read_byte
      capabilities = hello.read_bytes(UInt16, IO::ByteFormat::LittleEndian).to_u32
      hello.read_byte                                        # server charset
      hello.read_bytes(UInt16, IO::ByteFormat::LittleEndian) # server status
      capabilities |= hello.read_bytes(UInt16, IO::ByteFormat::LittleEndian).to_u32 << 16
      length = hello.read_byte
      required = PROTOCOL_41 | SECURE_CONNECTION | PLUGIN_AUTH
      raise AuthenticationError.new("MySQL server lacks protocol 4.1/plugin authentication") unless capabilities & required == required
      raise AuthenticationError.new("invalid MySQL authentication nonce length") unless length == 21
      hello.skip(10)
      hello.read_fully(nonce[8, 12])
      raise AuthenticationError.new("invalid MySQL nonce terminator") unless hello.read_byte == 0
      plugin = cstring(hello)
      response = self.class.scramble(plugin, @options.password, nonce)
      flags = required | 1_u32 | 4_u32
      flags |= CONNECT_WITH_DB if @options.database
      if @options.tls
        raise AuthenticationError.new("MySQL server does not offer TLS; refusing authentication") if capabilities & SSL == 0
        flags |= SSL
        write_packet(header(flags))
        context = OpenSSL::SSL::Context::Client.new
        context.verify_mode = @options.verify ? OpenSSL::SSL::VerifyMode::PEER : OpenSSL::SSL::VerifyMode::NONE
        @options.ca.try { |path| context.ca_certificates = path }
        bound
        @stream = OpenSSL::SSL::Socket::Client.new(@socket, context: context, sync_close: true, hostname: @options.host)
      end
      body = IO::Memory.new
      body.write(header(flags))
      body << @options.username << '\0'
      body.write_byte(response.size.to_u8)
      body.write(response)
      @options.database.try { |database| body << database << '\0' }
      body << plugin << '\0'
      write_packet(body.to_slice)
      authenticate(plugin)
      @socket.read_timeout = @socket.write_timeout = nil
      @stream
    rescue ex : IO::EOFError | IndexError
      raise AuthenticationError.new("truncated MySQL authentication packet", cause: ex)
    end

    def self.scramble(plugin : String, password : String, nonce : Bytes) : Bytes
      raise AuthenticationError.new("unsupported MySQL authentication plugin (expected caching_sha2_password or mysql_native_password)") unless {"caching_sha2_password", "mysql_native_password"}.includes?(plugin)
      raise AuthenticationError.new("invalid MySQL authentication nonce") unless nonce.size == 20
      return Bytes.empty if password.empty?
      if plugin == "caching_sha2_password"
        first = Digest::SHA256.digest(password)
        mask = Digest::SHA256.digest(Digest::SHA256.digest(first) + nonce)
      else
        first = Digest::SHA1.digest(password)
        mask = Digest::SHA1.digest(nonce + Digest::SHA1.digest(first))
      end
      Bytes.new(first.size) { |i| first[i] ^ mask[i] }
    end

    private def authenticate(plugin : String) : Nil
      switched = false
      full = false
      8.times do
        bytes = read_packet
        case bytes[0]
        when 0x00
          validate_ok(bytes)
          return
        when 0xff
          code = bytes.size >= 3 ? bytes[1].to_i | (bytes[2].to_i << 8) : 0
          raise AuthenticationError.new("MySQL authentication rejected (server error #{code})")
        when 0xfe
          raise AuthenticationError.new("repeated MySQL authentication switch") if switched || full
          switched = true
          packet = IO::Memory.new(bytes[1..])
          plugin = cstring(packet)
          nonce = Bytes.new(20)
          packet.read_fully(nonce)
          raise AuthenticationError.new("invalid MySQL authentication switch nonce") unless packet.read_byte == 0 && packet.read_byte.nil?
          write_packet(self.class.scramble(plugin, @options.password, nonce))
        when 0x01
          raise AuthenticationError.new("unexpected MySQL authentication continuation") if plugin != "caching_sha2_password" || bytes.size != 2 || full
          case bytes[1]
          when 3 # cached authentication succeeded; the next packet must be OK
            reply = read_packet
            raise AuthenticationError.new("MySQL fast authentication was not confirmed") unless reply[0] == 0
            validate_ok(reply)
            return
          when 4
            raise AuthenticationError.new("MySQL full password authentication requires TLS; use ssl-mode=verify_identity") unless @stream.is_a?(OpenSSL::SSL::Socket::Client)
            full = true
            write_packet((@options.password + '\0').to_slice)
          else
            raise AuthenticationError.new("unsupported MySQL authentication continuation")
          end
        else
          raise AuthenticationError.new("unexpected MySQL authentication packet")
        end
      end
      raise AuthenticationError.new("too many MySQL authentication exchanges")
    end

    private def validate_ok(bytes : Bytes) : Nil
      # Authentication OK has zero affected rows/insert id, status and warnings.
      unless bytes.size >= 7 && bytes[0] == 0 && bytes[1] == 0 && bytes[2] == 0
        raise AuthenticationError.new("malformed MySQL authentication OK packet")
      end
    end

    private def header(flags : UInt32) : Bytes
      io = IO::Memory.new
      io.write_bytes(flags, IO::ByteFormat::LittleEndian)
      io.write_bytes(0x01000000_u32, IO::ByteFormat::LittleEndian)
      io.write_byte(@options.charset)
      io.write(Bytes.new(23))
      io.to_slice
    end

    private def cstring(io : IO) : String
      String.build do |buffer|
        loop do
          byte = io.read_byte || raise AuthenticationError.new("unterminated MySQL authentication field")
          break if byte == 0
          buffer.write_byte(byte)
        end
      end
    end

    private def bound : Nil
      remaining = @deadline - Time.instant
      raise IO::TimeoutError.new("MySQL authentication exceeded connect_timeout") unless remaining.positive?
      @socket.read_timeout = @socket.write_timeout = remaining
    end

    private def read_packet : Bytes
      bound
      header = Bytes.new(4)
      @stream.read_fully(header)
      size = header[0].to_i | (header[1].to_i << 8) | (header[2].to_i << 16)
      raise AuthenticationError.new("invalid MySQL authentication packet length") unless 0 < size <= MAX_PACKET
      raise AuthenticationError.new("invalid MySQL authentication packet sequence") unless header[3] == @sequence
      @sequence &+= 1
      bytes = Bytes.new(size)
      @stream.read_fully(bytes)
      bytes
    end

    private def write_packet(bytes : Bytes) : Nil
      bound
      header = Bytes[bytes.size.to_u8!, (bytes.size >> 8).to_u8!, (bytes.size >> 16).to_u8!, @sequence]
      @sequence &+= 1
      @stream.write(header)
      @stream.write(bytes)
      @stream.flush
    end
  end
end
