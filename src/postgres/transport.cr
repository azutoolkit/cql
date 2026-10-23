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
    # The byte stream to talk over, and the socket under it. Closing the socket
    # ends the connection at once; closing a TLS stream first sends close_notify,
    # which can block for good on a dead path with a full send buffer.
    record Stream, io : IO, socket : IO

    def self.connect(config : Config) : IO
      open_stream(config).io
    end

    def self.open_stream(config : Config) : Stream
      socket = open(config)
      begin
        Stream.new(socket.is_a?(TCPSocket) ? negotiate_tls(socket, config) : socket, socket)
      rescue ex
        socket.close
        raise ex
      end
    rescue ex : TLSRefused
      raise ex
    rescue ex : IO::TimeoutError
      raise IO::TimeoutError.new("cannot connect to #{config.address}: #{ex.message}", cause: ex)
    rescue ex : Socket::Error | IO::Error
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
    def self.cancel(config : Config, process_id : Int32, secret_key : Bytes) : Nil
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
      when nil     then raise IO::Error.new("the server closed the connection after the SSLRequest")
      when 'S'.ord then tls(socket, config)
      when 'N'.ord then config.ssl_mode.prefer? ? socket : raise TLSRefused.new("#{config.address} does not support TLS, which the sslmode requires")
      else              raise TLSRefused.new("#{config.address} answered the SSLRequest with #{answer.chr.inspect}, not S or N")
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
    rescue ex : OpenSSL::Error
      # A peer that hangs up mid-handshake is a network event a retry can fix; a refusal or a bad certificate is not.
      raise IO::Error.new("the server closed the connection during the TLS handshake", cause: ex) if ex.message.try(&.matches?(/unexpected eof/i))
      raise TLSRefused.new("TLS to #{config.address} failed: #{ex.message}", cause: ex)
    end
  end
end
