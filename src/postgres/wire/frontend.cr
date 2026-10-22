require "../types/param"
require "../protocol_version"
require "../errors"

module CQL::Postgres::Wire
  # Encoders for the messages a client sends. Each writes one complete frame
  # to *io*, so several can be buffered and flushed together (pipelining).
  module Frontend
    SSL_REQUEST    = 80877103_i32
    CANCEL_REQUEST = 80877102_i32

    def self.startup(io : IO, parameters : Hash(String, String), version : ProtocolVersion = ProtocolVersion::V3_0) : Nil
      frame(io, nil) do |body|
        int32(body, version.code)
        parameters.each do |name, value|
          cstring(body, name)
          cstring(body, value)
        end
        body.write_byte(0_u8)
      end
    end

    def self.ssl_request(io : IO) : Nil
      frame(io, nil) { |body| int32(body, SSL_REQUEST) }
    end

    # The secret key runs to the end of the message (4 bytes before protocol 3.2).
    def self.cancel_request(io : IO, process_id : Int32, secret_key : Bytes) : Nil
      frame(io, nil) do |body|
        int32(body, CANCEL_REQUEST)
        int32(body, process_id)
        body.write(secret_key)
      end
    end

    def self.password(io : IO, password : String) : Nil
      frame(io, 'p') { |body| cstring(body, password) }
    end

    def self.sasl_initial_response(io : IO, mechanism : String, response : Bytes) : Nil
      frame(io, 'p') do |body|
        cstring(body, mechanism)
        int32(body, response.size)
        body.write(response)
      end
    end

    def self.sasl_response(io : IO, response : Bytes) : Nil
      frame(io, 'p', &.write(response))
    end

    def self.query(io : IO, sql : String) : Nil
      frame(io, 'Q') { |body| cstring(body, sql) }
    end

    def self.parse(io : IO, name : String, sql : String) : Nil
      frame(io, 'P') do |body|
        cstring(body, name)
        cstring(body, sql)
        int16(body, 0) # let the server infer every parameter type
      end
    end

    def self.bind(io : IO, statement : String, params : Array(Types::Param), result_formats : Array(Int16)) : Nil
      raise ArgumentError.new("a statement takes at most #{UInt16::MAX} parameters, got #{params.size}") if params.size > UInt16::MAX
      raise ArgumentError.new("at most #{UInt16::MAX} result formats can be requested") if result_formats.size > UInt16::MAX
      frame(io, 'B') do |body|
        cstring(body, "") # unnamed portal
        cstring(body, statement)
        int16(body, params.size)
        params.each { |param| int16(body, param.format) }
        int16(body, params.size)
        params.each { |param| bytes_or_null(body, param.value) }
        int16(body, result_formats.size)
        result_formats.each { |format| int16(body, format) }
      end
    end

    def self.describe_statement(io : IO, name : String) : Nil
      frame(io, 'D') do |body|
        body.write_byte('S'.ord.to_u8)
        cstring(body, name)
      end
    end

    def self.execute(io : IO) : Nil
      frame(io, 'E') do |body|
        cstring(body, "")
        int32(body, 0) # no row limit
      end
    end

    def self.close_statement(io : IO, name : String) : Nil
      frame(io, 'C') do |body|
        body.write_byte('S'.ord.to_u8)
        cstring(body, name)
      end
    end

    def self.sync(io : IO) : Nil
      frame(io, 'S') { }
    end

    def self.flush(io : IO) : Nil
      frame(io, 'H') { }
    end

    def self.terminate(io : IO) : Nil
      frame(io, 'X') { }
    end

    def self.copy_data(io : IO, chunk : Bytes) : Nil
      frame(io, 'd', &.write(chunk))
    end

    def self.copy_done(io : IO) : Nil
      frame(io, 'c') { }
    end

    def self.copy_fail(io : IO, reason : String) : Nil
      frame(io, 'f') { |body| cstring(body, reason) }
    end

    private def self.frame(io : IO, type : Char?, & : IO::Memory ->) : Nil
      body = IO::Memory.new
      yield body
      io.write_byte(type.ord.to_u8) if type
      int32(io, body.size + 4)
      io.write(body.to_slice)
    end

    private def self.int16(io : IO, value : Int) : Nil
      io.write_bytes(value.to_u16!, IO::ByteFormat::NetworkEndian)
    end

    private def self.int32(io : IO, value : Int) : Nil
      io.write_bytes(value.to_i32, IO::ByteFormat::NetworkEndian)
    end

    private def self.cstring(io : IO, text : String) : Nil
      raise ArgumentError.new("NUL bytes cannot be sent in a protocol string") if text.includes?('\0')
      io << text
      io.write_byte(0_u8)
    end

    private def self.bytes_or_null(io : IO, value : Bytes?) : Nil
      return int32(io, -1) unless value
      int32(io, value.size)
      io.write(value)
    end
  end
end
