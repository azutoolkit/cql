require "socket"
require "openssl"
require "./config"
require "./wire/frontend"

module CQL::Postgres
  # Opens the byte stream to the server: TCP or Unix socket, optionally
  # upgraded to TLS through the protocol's SSLRequest. Each blocking step of
  # connecting and starting up is bounded by `connect_timeout`; call `relax`
  # once the session is up.
  module Transport
    def self.connect(config : Config) : IO
      socket = open(config)
      begin
        socket.is_a?(TCPSocket) ? negotiate_tls(socket, config) : socket
      rescue ex
        socket.close
        raise ex
      end
    rescue ex : IO::TimeoutError
      raise IO::TimeoutError.new("cannot connect to #{config.address}: #{ex.message}", cause: ex)
    rescue ex : Socket::Error | IO::Error | OpenSSL::Error
      raise IO::Error.new("cannot connect to #{config.address}: #{ex.message}", cause: ex)
    end

    # Lifts the startup time limits so queries may run as long as they need.
    def self.relax(io : IO) : Nil
      return unless io.responds_to?(:read_timeout=) && io.responds_to?(:write_timeout=)
      io.read_timeout = nil
      io.write_timeout = nil
    end

    # Sends an out-of-band CancelRequest for the session identified by the key.
    # The request itself is never encrypted, as in libpq before version 17.
    def self.cancel(config : Config, process_id : Int32, secret_key : Int32) : Nil
      io = open(config)
      Wire::Frontend.cancel_request(io, process_id, secret_key)
      io.flush
    ensure
      io.try(&.close)
    end

    private def self.open(config : Config) : TCPSocket | UNIXSocket
      socket = if config.unix_socket?
                 UNIXSocket.new(config.socket_path)
               else
                 TCPSocket.new(config.host, config.port, connect_timeout: config.connect_timeout).tap do |tcp|
                   tcp.tcp_nodelay = true
                   tcp.keepalive = true
                 end
               end
      socket.read_timeout = socket.write_timeout = config.connect_timeout
      socket
    end

    private def self.negotiate_tls(socket : TCPSocket, config : Config) : IO
      return socket if config.ssl_mode.disable?
      Wire::Frontend.ssl_request(socket)
      case answer = read_unbuffered_byte(socket)
      when 'S'.ord then tls(socket, config)
      when 'N'.ord then config.ssl_mode.prefer? ? socket : raise IO::Error.new("the server does not support TLS")
      else              raise IO::Error.new("unexpected reply #{answer.try(&.chr).inspect} to SSLRequest")
      end
    end

    # Reading exactly one byte keeps anything a hostile peer appends after the
    # reply out of the buffer that would later be mistaken for TLS data.
    private def self.read_unbuffered_byte(socket : TCPSocket) : Int32?
      socket.read_buffering = false
      byte = socket.read_byte
      socket.read_buffering = true
      byte.try(&.to_i)
    end

    private def self.tls(socket : TCPSocket, config : Config) : IO
      context = OpenSSL::SSL::Context::Client.new
      if config.ssl_mode.verify_full?
        config.ssl_root_cert.try { |path| context.ca_certificates = path }
      else
        context.verify_mode = OpenSSL::SSL::VerifyMode::NONE
      end
      OpenSSL::SSL::Socket::Client.new(socket, context: context, sync_close: true, hostname: config.host)
    end
  end
end
