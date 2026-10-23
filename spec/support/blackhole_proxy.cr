require "socket"

# A TCP proxy that can turn into a black hole: after `blackhole!` it stops forwarding in both directions
# without closing anything, and stops reading, so the sender's buffers fill like they would on a path that
# silently drops packets. Connections made afterwards are accepted and ignored.
class BlackholeProxy
  getter port : Int32
  getter accepted = Atomic(Int32).new(0)

  def initialize(@target_port : Int32)
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.local_address.port
    @sockets = [] of TCPSocket
    @blackholed = false
    spawn do
      while client = @server.accept?
        @accepted.add(1)
        @sockets << client
        spawn forward(client) unless @blackholed
      end
    end
  end

  def blackhole! : Nil
    @blackholed = true
  end

  # Closes every socket the proxy holds (both sides), as a test's cleanup.
  def close : Nil
    @server.close
    @sockets.each { |socket| socket.close rescue nil }
  end

  private def forward(client : TCPSocket) : Nil
    upstream = TCPSocket.new("127.0.0.1", @target_port)
    @sockets << upstream
    spawn pump(client, upstream)
    pump(upstream, client)
  rescue IO::Error
    client.close rescue nil
  end

  private def pump(from : TCPSocket, to : TCPSocket) : Nil
    buffer = Bytes.new(16 * 1024)
    until @blackholed
      from.read_timeout = 50.milliseconds
      count = begin
        from.read(buffer)
      rescue IO::TimeoutError
        next
      end
      break if count == 0 || @blackholed # what was read after the switch is dropped
      to.write(buffer[0, count])
    end
    # Black hole: neither read nor close; the sockets stay open until `close`.

  rescue IO::Error
    to.close rescue nil
  end
end
