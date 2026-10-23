require "./config"
require "./transport"
require "./auth/*"
require "./wire/backend"

module CQL::Postgres
  # Runs the startup exchange on a fresh stream: StartupMessage, authentication
  # in whichever method the server asks for, then the parameter and key
  # messages up to the first ReadyForQuery.
  class Handshake
    # Startup messages are small; refuse anything bigger before authenticating.
    MAX_MESSAGE_SIZE = 64 * 1024

    record Outcome, process_id : Int32, secret_key : Bytes, parameters : Hash(String, String), status : Char,
      version : ProtocolVersion = ProtocolVersion::V3_0

    # Asks for *requested* and settles for the highest version the server offers,
    # as long as it is not older than the config's minimum.
    def initialize(@config : Config, @io : IO, @requested : ProtocolVersion = config.max_protocol_version)
      @parameters = {} of String => String
      @process_id = 0
      @secret_key = Bytes.empty
      @version = @requested
      @heard = false
    end

    def run : Outcome
      send { |buffer| Wire::Frontend.startup(buffer, @config.startup_parameters, @requested) }
      scram = nil
      authenticated = false
      loop do
        case message = read_message
        when Wire::Backend::NoticeResponse
        when Wire::Backend::NegotiateProtocolVersion
          raise ProtocolError.new("protocol negotiation after authentication started") if authenticated || scram
          negotiate(message)
        when Wire::Backend::AuthenticationOk
          raise ProtocolError.new("the server finished authentication in the middle of SCRAM") if scram && !scram.verified?
          authenticated = true
        when Wire::Backend::AuthenticationCleartext
          send { |buffer| Wire::Frontend.password(buffer, @config.password_for_authentication) }
        when Wire::Backend::AuthenticationMD5
          digest = Auth::MD5Password.digest(@config.user, @config.password_for_authentication, message.salt)
          send { |buffer| Wire::Frontend.password(buffer, digest) }
        when Wire::Backend::AuthenticationSASL
          scram = begin_scram(message)
        when Wire::Backend::AuthenticationSASLContinue
          response = (scram || unexpected(message)).continue(message.data)
          send { |buffer| Wire::Frontend.sasl_response(buffer, response) }
        when Wire::Backend::AuthenticationSASLFinal
          (scram || unexpected(message)).verify(message.data)
        when Wire::Backend::ParameterStatus
          @parameters[message.name] = message.value
        when Wire::Backend::BackendKeyData
          raise ProtocolError.new("a #{message.secret_key.size}-byte cancel key is not valid for protocol #{@version}") unless @version.valid_secret_key?(message.secret_key)
          @process_id, @secret_key = message.process_id, message.secret_key
        when Wire::Backend::ReadyForQuery
          raise ProtocolError.new("the server skipped authentication") unless authenticated
          return Outcome.new(@process_id, @secret_key, @parameters, message.status, @version)
        when Wire::Backend::ErrorResponse
          raise ServerError.from(message.fields)
        else
          unexpected(message)
        end
      end
    end

    # A first reply that does not parse means the peer is not speaking the
    # protocol version we asked for (see `UnrecognizedStartupReply`).
    private def read_message
      Wire::Backend.read(@io, MAX_MESSAGE_SIZE).tap { @heard = true }
    rescue ex : ProtocolError
      raise @heard ? ex : UnrecognizedStartupReply.new(ex.message)
    rescue ex : IO::TimeoutError
      raise ex # a stall is not a rejection
    rescue ex : IO::Error
      # The peer hung up (EOF) or reset the connection (Odyssey does, on a 3.2 startup)
      # before saying anything.
      raise @heard ? ex : UnrecognizedStartupReply.new("the server closed the connection without answering the startup message", cause: ex)
    end

    # The server cannot speak the requested minor version and names the newest it
    # can. Options it did not recognise are ignored (they are settings the URL
    # asked for, or names a hostile server made up, so they are only logged).
    private def negotiate(message : Wire::Backend::NegotiateProtocolVersion) : Nil
      @version = @requested.negotiated(message.newest_minor)
      if @version < @config.min_protocol_version
        raise UnsupportedProtocol.new("the server supports protocol #{@version} at most, but #{@config.min_protocol_version} or newer was required")
      end
      Session::Log.warn { "the server ignored these startup options: #{message.unrecognized.join(", ")}" } unless message.unrecognized.empty?
    end

    private def begin_scram(message : Wire::Backend::AuthenticationSASL) : Auth::ScramSha256
      unless message.mechanisms.includes?(Auth::ScramSha256::MECHANISM)
        raise AuthenticationError.new("the server offers only unsupported SASL mechanisms: #{message.mechanisms.join(", ")}")
      end
      Auth::ScramSha256.new(@config.password_for_authentication).tap do |scram|
        send { |buffer| Wire::Frontend.sasl_initial_response(buffer, Auth::ScramSha256::MECHANISM, scram.initial_response) }
      end
    end

    private def send(& : IO::Memory ->) : Nil
      buffer = IO::Memory.new
      yield buffer
      @io.write(buffer.to_slice)
      @io.flush
    end

    private def unexpected(message) : NoReturn
      raise ProtocolError.new("unexpected #{message.class.name.split("::").last} during startup")
    end
  end
end
