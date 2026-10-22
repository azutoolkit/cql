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

    record Outcome, process_id : Int32, secret_key : Int32, parameters : Hash(String, String), status : Char

    def initialize(@config : Config, @io : IO)
      @parameters = {} of String => String
      @process_id = 0
      @secret_key = 0
    end

    def run : Outcome
      send { |buffer| Wire::Frontend.startup(buffer, @config.startup_parameters) }
      scram = nil
      authenticated = false
      loop do
        case message = Wire::Backend.read(@io, MAX_MESSAGE_SIZE)
        when Wire::Backend::NoticeResponse, Wire::Backend::NegotiateProtocolVersion
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
          @process_id, @secret_key = message.process_id, message.secret_key
        when Wire::Backend::ReadyForQuery
          raise ProtocolError.new("the server skipped authentication") unless authenticated
          return Outcome.new(@process_id, @secret_key, @parameters, message.status)
        when Wire::Backend::ErrorResponse
          raise ServerError.from(message.fields)
        else
          unexpected(message)
        end
      end
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
