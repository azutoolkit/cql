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
      raise ArgumentError.new("a parameter still waits for the statement's types") if params.any?(&.deferred)
      check_cstring(statement)
      unbuffered_frame(io, 'B') do |body|
        write_cstring(body, "") # unnamed portal
        write_cstring(body, statement)
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

    # Runs the unnamed portal, returning at most *max_rows* rows (0: all of them).
    def self.execute(io : IO, max_rows : Int32 = 0) : Nil
      unbuffered_frame(io, 'E') do |body|
        write_cstring(body, "")
        int32(body, max_rows)
      end
    end

    def self.close_portal(io : IO) : Nil
      frame(io, 'C') do |body|
        body.write_byte('P'.ord.to_u8)
        cstring(body, "")
      end
    end

    def self.close_statement(io : IO, name : String) : Nil
      frame(io, 'C') do |body|
        body.write_byte('S'.ord.to_u8)
        cstring(body, name)
      end
    end

    def self.sync(io : IO) : Nil
      unbuffered_frame(io, 'S') { }
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

    # For the per-query messages (Bind, Execute, Sync), whose body cannot fail once its inputs are
    # checked: written in place into the session's buffer and the length filled in afterwards,
    # instead of through a body buffer that is then copied. A body that raised would leave a
    # partial frame behind, so every other message goes through `frame`.
    private def self.unbuffered_frame(io : IO, type : Char, & : IO ->) : Nil
      return frame(io, type) { |body| yield body } unless io.is_a?(IO::Memory)

      io.write_byte(type.ord.to_u8)
      start = io.pos
      int32(io, 0)
      yield io
      length = (io.pos - start).to_i32
      header = io.to_slice
      4.times { |index| header[start + index] = (length >> (24 - 8 * index)).to_u8! }
    end

    # Big-endian bytes written in one call: `write_bytes` with `NetworkEndian` reverses a
    # StaticArray per value, which costs more than the rest of a Bind message.
    private def self.int16(io : IO, value : Int) : Nil
      word = value.to_u16!
      io.write(StaticArray[(word >> 8).to_u8!, word.to_u8!].to_slice)
    end

    private def self.int32(io : IO, value : Int) : Nil
      word = value.to_i32
      io.write(StaticArray[(word >> 24).to_u8!, (word >> 16).to_u8!, (word >> 8).to_u8!, word.to_u8!].to_slice)
    end

    private def self.cstring(io : IO, text : String) : Nil
      check_cstring(text)
      write_cstring(io, text)
    end

    private def self.check_cstring(text : String) : Nil
      raise ArgumentError.new("NUL bytes cannot be sent in a protocol string") if text.includes?('\0')
    end

    private def self.write_cstring(io : IO, text : String) : Nil
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
