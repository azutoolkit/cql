require "socket"
require "openssl"
require "./config"
require "./wire/frontend"

# Crystal 1.22's stdlib does not bind this (needed for the empty pass phrase in `tls`); delete once a later one does.
lib LibSSL
  fun ssl_ctx_set_default_passwd_cb_userdata = SSL_CTX_set_default_passwd_cb_userdata(ctx : SSLContext, u : Void*) : Void
end

module CQL::Postgres
  # Opens the byte stream to the server: TCP or Unix socket, optionally
  # upgraded to TLS through the protocol's SSLRequest. Each blocking step of
  # connecting and starting up is bounded by `connect_timeout`, or by the time
  # left before a deadline when one is given, which then also ends the whole
  # connect once the socket exists (`watch`); call `relax` once the session is up.
  module Transport
    # The byte stream to talk over, and the socket under it. Closing the socket
    # ends the connection at once; closing a TLS stream first sends close_notify,
    # which can block for good on a dead path with a full send buffer.
    record Stream, io : IO, socket : IO

    def self.connect(config : Config) : IO
      open_stream(config, &.io)
    end

    # Yields the stream (to start a session on it) and closes its socket if the block raises. With a *deadline*,
    # opening the stream and the block end by it: see `watch`.
    def self.open_stream(config : Config, deadline : Time::Instant? = nil, & : Stream -> T) : T forall T
      socket = naming_server(config) { open(config, deadline.try { |due| time_left(due) }) }
      begin
        watch(socket, deadline, config) do
          io = naming_server(config) { socket.is_a?(TCPSocket) ? negotiate_tls(socket, config, deadline) : socket }
          yield Stream.new(io, socket)
        rescue ex : OpenSSL::SSL::Error
          # TLS 1.3 ends the client's handshake before the server checks its certificate: a refusal comes on a read.
          # Only protocol-level SSL errors reach here; network failures arrive as IO::Error.
          raise tls_failure(ex, config)
        end
      rescue ex
        socket.close
        raise ex
      end
    end

    # A slow peer can answer each read in time and still stretch a connect, so a watchdog closes *socket* (never a
    # TLS stream over it, whose close can block) if the block still runs at *deadline*. Whatever the block then makes
    # of the closed socket (an EOF, a failed TLS handshake, an unrecognized startup reply), the connect ran out of
    # time. The watchdog and the block settle atomically who came first, so a socket the block finished with stays open.
    private def self.watch(socket : IO, deadline : Time::Instant?, config : Config, &)
      return yield unless deadline
      settled = Atomic(Bool).new(false)
      finished = Channel(Nil).new
      spawn do
        select
        when finished.receive?
        when timeout(deadline - Time.instant) then socket.close unless settled.swap(true)
        end
      end
      begin
        yield
      ensure
        finished.close
        raise IO::TimeoutError.new("cannot connect to #{config.address}: #{RAN_OUT}") if settled.swap(true)
      end
    end

    private def self.naming_server(config : Config, &)
      yield
    rescue ex : TLSRefused
      raise ex
    rescue ex : IO::TimeoutError
      raise IO::TimeoutError.new("cannot connect to #{config.address}: #{ex.message}", cause: ex)
    rescue ex : Socket::Error | IO::Error
      raise IO::Error.new("cannot connect to #{config.address}: #{ex.message}", cause: ex)
    end

    # recv(2) flags LibC does not bind: look without consuming, never wait.
    private MSG_PEEK     = 0x02
    private MSG_DONTWAIT = {% if flag?(:linux) %} 0x40 {% else %} 0x80 {% end %} # 0x80 on macOS and the BSDs

    # True when the kernel holds bytes, an end of stream or an error for *socket*: an idle session should have
    # nothing to read, so the server wrote or hung up while it sat unused. Never blocks. For TLS the bytes are
    # still encrypted, which is enough to know. Off Unix, or for a non-socket stream, the answer is false.
    def self.input_pending?(socket : IO) : Bool
      {% if flag?(:unix) %}
        return false unless socket.is_a?(Socket)
        byte = 0_u8
        LibC.recv(socket.fd, pointerof(byte), 1, MSG_PEEK | MSG_DONTWAIT) >= 0 || Errno.value != Errno::EAGAIN
      {% else %}
        false
      {% end %}
    end

    # Bounds the next step of connecting by `connect_timeout`, or by the time left before *deadline* when that is sooner.
    def self.limit(io : IO, config : Config, deadline : Time::Instant?) : Nil
      return unless deadline && io.responds_to?(:read_timeout=) && io.responds_to?(:write_timeout=)
      io.read_timeout = io.write_timeout = [config.connect_timeout, time_left(deadline)].compact.min
    end

    private RAN_OUT = "the time to connect ran out"

    private def self.time_left(deadline : Time::Instant) : Time::Span
      left = deadline - Time.instant
      raise IO::TimeoutError.new(RAN_OUT) unless left.positive?
      left
    end

    # Lifts the startup time limits so queries may run as long as they need.
    def self.relax(io : IO) : Nil
      return unless io.responds_to?(:read_timeout=) && io.responds_to?(:write_timeout=)
      io.read_timeout = nil
      io.write_timeout = nil
    end

    # Sends an out-of-band CancelRequest for the session identified by the key.
    # The request itself is never encrypted, as in libpq before version 17.
    # Returns once the postmaster has hung up, which it does after signalling the
    # backend. Connecting and waiting for that are each capped at *wait* (a proxy
    # may accept and sit).
    def self.cancel(config : Config, process_id : Int32, secret_key : Bytes, wait : Time::Span) : Nil
      io = open(config, connect_wait: wait)
      Wire::Frontend.cancel_request(io, process_id, secret_key)
      io.flush
      wait_for_hang_up(io, wait)
    ensure
      io.try(&.close)
    end

    # The postmaster closes its side once it has signalled the backend, so
    # waiting for that (as libpq does) means the cancel cannot land on a
    # statement sent after this returns.
    private def self.wait_for_hang_up(io : IO, wait : Time::Span) : Nil
      io.read_timeout = wait if io.responds_to?(:read_timeout=)
      io.read(Bytes.new(1))
    rescue IO::Error
    end

    private def self.open(config : Config, connect_wait : Time::Span? = nil) : TCPSocket | UNIXSocket
      connect_timeout = [config.connect_timeout, connect_wait].compact.min?
      socket = if config.unix_socket?
                 UNIXSocket.new(config.socket_path)
               else
                 TCPSocket.new(config.host, config.port, dns_timeout: connect_timeout, connect_timeout: connect_timeout).tap do |tcp|
                   tcp.tcp_nodelay = true
                   tcp.keepalive = true
                 end
               end
      socket.read_timeout = socket.write_timeout = connect_timeout
      socket
    end

    private def self.negotiate_tls(socket : TCPSocket, config : Config, deadline : Time::Instant?) : IO
      return socket if config.ssl_mode.disable?
      limit(socket, config, deadline)
      Wire::Frontend.ssl_request(socket)
      case answer = read_unbuffered_byte(socket)
      when nil     then raise IO::Error.new("the server closed the connection after the SSLRequest")
      when 'S'.ord then tls(socket, config, deadline)
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

    private def self.tls(socket : TCPSocket, config : Config, deadline : Time::Instant?) : IO
      limit(socket, config, deadline)
      context = OpenSSL::SSL::Context::Client.new
      if config.ssl_mode.verify_full?
        config.ssl_root_cert.try { |path| context.ca_certificates = path }
      else
        context.verify_mode = OpenSSL::SSL::VerifyMode::NONE
      end
      # An empty pass phrase: OpenSSL fails an encrypted file as a bad decrypt instead of asking the terminal or stdin.
      LibSSL.ssl_ctx_set_default_passwd_cb_userdata(context, "".to_unsafe.as(Void*))
      config.ssl_cert.try { |path| load_pem(config, "sslcert", path) { context.certificate_chain = path } }
      config.ssl_key.try { |path| load_pem(config, "sslkey", path) { context.private_key = path } }
      OpenSSL::SSL::Socket::Client.new(socket, context: context, sync_close: true, hostname: config.host)
    rescue ex : OpenSSL::Error
      raise tls_failure(ex, config)
    end

    # A peer that hangs up mid-handshake is a network event a retry can fix; a refusal or a bad certificate is not.
    private def self.tls_failure(ex : OpenSSL::Error, config : Config) : Exception
      return IO::Error.new("the server closed the connection during the TLS handshake", cause: ex) if ex.message.try(&.matches?(/unexpected eof/i))
      TLSRefused.new("TLS to #{config.address} failed: #{ex.message}", cause: ex)
    end

    # Read on every connect, so a replaced file is picked up. OpenSSL's error text names a reason, never file content.
    private def self.load_pem(config : Config, option : String, path : String, &) : Nil
      yield
    rescue ex : OpenSSL::Error
      problem = ex.message.try(&.includes?("bad decrypt")) ? "is encrypted; sslpassword is not supported" : "could not be loaded: #{ex.message}"
      raise TLSRefused.new("TLS to #{config.address} failed: #{option} #{path} #{problem}", cause: ex)
    end
  end
end
