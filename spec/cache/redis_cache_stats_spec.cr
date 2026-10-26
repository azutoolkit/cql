require "../spec_helper"
require "socket"
require "../../src/cache/redis_cache"

# A Redis stand-in that answers INFO only once `release_info` is sent, so a spec can hold
# INFO in flight and see what other cache operations do meanwhile.
private class SlowInfoRedis
  getter info_received = Channel(Nil).new(1)
  getter release_info = Channel(Nil).new(1)
  @server = TCPServer.new("127.0.0.1", 0)

  def url : String
    "redis://127.0.0.1:#{@server.local_address.port}"
  end

  def start : self
    spawn do
      while client = @server.accept?
        spawn serve(client)
      end
    end
    self
  end

  def close : Nil
    @server.close
  end

  private def serve(client : TCPSocket) : Nil
    while command = read_command(client)
      reply(client, command.first.upcase)
    end
  rescue IO::Error
  ensure
    client.close
  end

  private def reply(client : TCPSocket, command : String) : Nil
    case command
    when "INFO"
      info_received.send(nil)
      release_info.receive
      body = "used_memory:1\r\nconnected_clients:1\r\n"
      client << "$" << body.bytesize << "\r\n" << body << "\r\n"
    when "GET"
      client << "$-1\r\n"
    else
      client << "+OK\r\n"
    end
    client.flush
  end

  private def read_command(client : TCPSocket) : Array(String)?
    header = client.gets(chomp: true) || return
    Array(String).new(header.lchop('*').to_i) do
      length = (client.gets(chomp: true) || return).lchop('$').to_i
      argument = client.read_string(length)
      client.skip(2)
      argument
    end
  end
end

describe CQL::Cache::RedisCache do
  describe "#stats" do
    it "lets other operations run while it waits for Redis INFO" do
      fake = SlowInfoRedis.new.start
      cache = CQL::Cache::RedisCache.new(fake.url, "stats_lock")
      get_done = Channel(String?).new(1)

      spawn { cache.stats }
      select
      when fake.info_received.receive
      when timeout(2.seconds)
        fail "RedisCache#stats never sent INFO"
      end
      spawn { get_done.send(cache.get("other_key")) }

      select
      when value = get_done.receive
        value.should be_nil
      when timeout(2.seconds)
        fail "RedisCache#get waited for #stats to finish its INFO round trip"
      end
    ensure
      fake.try &.release_info.send(nil)
      fake.try &.close
    end
  end
end
