require "../spec_helper"
require "http/server"

private class SpecFailure < Exception
end

# The shape of `Azu::HandlerPipeline`: `use` adds a handler and returns the pipeline.
private class PipelineWithUse
  getter handlers = [] of HTTP::Handler

  def use(handler : HTTP::Handler) : self
    @handlers << handler
    self
  end
end

private def reset_request_query_cache : Nil
  cache = CQL::Cache::RequestQueryCache.instance
  cache.enabled = false # forgets every request and stops tracking outside requests
  cache.clear           # outside a request: drops the process-wide tracker's statements
end

# Runs the block with the request query cache switched on or off in `CQL.config.cache`, then restores the switches.
private def with_request_cache_switch(on : Bool, &) : Nil
  cache_config = CQL.config.cache
  was_on, had_request_cache = cache_config.on?, cache_config.request_cache?
  cache_config.on = on
  cache_config.request_cache = true
  begin
    yield
  ensure
    cache_config.on = was_on
    cache_config.request_cache = had_request_cache
  end
end

private def current_request_id : String
  CQL::Cache::RequestQueryCacheHelper.stats["request_id"].as(String)
end

# Runs one request through `CQL::Cache::Middleware::HTTP` and returns the request id seen inside it.
private def request_id_inside(headers : HTTP::Headers = HTTP::Headers.new, &on_request : -> Nil) : String?
  seen = nil
  handlers = [CQL::Cache::Middleware::HTTP.new] of HTTP::Handler
  handler = HTTP::Server.build_middleware(handlers, ->(_context : HTTP::Server::Context) {
    seen = current_request_id
    on_request.call
  })
  context = HTTP::Server::Context.new(HTTP::Request.new("GET", "/", headers), HTTP::Server::Response.new(IO::Memory.new))
  handler.call(context)
  seen
end

describe CQL::Cache::Middleware::HTTP do
  before_each { reset_request_query_cache }
  after_each { reset_request_query_cache }
  around_each { |example| with_request_cache_switch(on: true) { example.run } }

  it "runs the request with its X-Request-ID as the request id and ends it afterwards" do
    request_id_inside(HTTP::Headers{"X-Request-ID" => "req-1"}) { }.should eq("req-1")

    current_request_id.should eq("none")
    CQL::Cache::RequestQueryCacheHelper.enabled?.should be_false
  end

  it "generates a 16-character hex id when the request has no X-Request-ID" do
    request_id_inside { }.not_nil!.should match(/\A[0-9a-f]{16}\z/)
  end

  it "keeps a valid client X-Request-ID unchanged" do
    id = "Req_1.a-B#{"x" * 119}" # 128 characters
    request_id_inside(HTTP::Headers{"X-Request-ID" => id}) { }.should eq(id)
  end

  it "replaces a client X-Request-ID that is not 1 to 128 of A-Z a-z 0-9 . _ -" do
    # HTTP::Headers refuses CR, LF and NUL itself; those reach the shared start through other hooks (below)
    ["", "tab\there", "spaced id", "é-unicode", "a;b", "x" * 129, "x" * 16_384].each do |id|
      request_id_inside(HTTP::Headers{"X-Request-ID" => id}) { }.not_nil!.should match(/\A[0-9a-f]{16}\z/)
    end
  end

  it "ends the request when the rest of the chain raises" do
    expect_raises(SpecFailure) do
      request_id_inside(HTTP::Headers{"X-Request-ID" => "req-2"}) { raise SpecFailure.new }
    end

    current_request_id.should eq("none")
    CQL::Cache::RequestQueryCacheHelper.enabled?.should be_false
  end
end

describe "CQL::Cache::Middleware with the request cache switched off" do
  before_each { reset_request_query_cache }
  after_each { reset_request_query_cache }

  it "tracks nothing and still passes the request on" do
    with_request_cache_switch(on: false) do
      passed_on = false
      request_id_inside(HTTP::Headers{"X-Request-ID" => "req-off"}) { passed_on = true }.should eq("none")

      passed_on.should be_true
      CQL::Cache::RequestQueryCacheHelper.enabled?.should be_false
    end
  end

  it "still ends a request that started before the switch was turned off" do
    with_request_cache_switch(on: true) do
      CQL::Cache::Middleware::Manual.start_request("req-before-off")
      CQL.config.cache.on = false
      CQL::Cache::Middleware::Manual.end_request
    end

    CQL::Cache::RequestQueryCache.instance.active_requests.should eq(0)
    current_request_id.should eq("none")
  end

  it "still ends a request the block form started when the switch is turned off inside it" do
    with_request_cache_switch(on: true) do
      CQL::Cache::Middleware::Manual.with_request("req-block") { CQL.config.cache.on = false }
    end

    CQL::Cache::RequestQueryCache.instance.active_requests.should eq(0)
    current_request_id.should eq("none")
  end

  it "does not end a request started outside the block form (CQL.with_request_cache, Manual, HTTP)" do
    with_request_cache_switch(on: false) do
      CQL::Cache::RequestQueryCacheHelper.start_request("outer")
      begin
        CQL.with_request_cache("inner") { }
        current_request_id.should eq("outer")
        CQL::Cache::Middleware::Manual.with_request("inner") { }
        current_request_id.should eq("outer")
        request_id_inside(HTTP::Headers{"X-Request-ID" => "inner"}) { }.should eq("outer")
        current_request_id.should eq("outer")
      ensure
        CQL::Cache::RequestQueryCacheHelper.end_request
      end
    end

    CQL::Cache::RequestQueryCache.instance.active_requests.should eq(0)
  end
end

describe "CQL::Cache::Middleware request ids in every integration" do
  around_each { |example| with_request_cache_switch(on: true) { example.run } }

  it "replaces an invalid id passed to the shared start (Manual, Kemal, Lucky, ...)" do
    ["bad\nid", "good-id\n", "a\r\nSet-Cookie: x=1", "nul\0", "esc\e[31m", "", "x" * 16_384].each do |id|
      CQL::Cache::Middleware::Manual.with_request(id) do
        CQL::Cache::RequestQueryCache.instance.current_request_id.not_nil!.should match(/\A[0-9a-f]{16}\z/)
      end
    end
    CQL::Cache::Middleware::Manual.with_request("good-id") do
      CQL::Cache::RequestQueryCache.instance.current_request_id.should eq("good-id")
    end
  end
end

describe "CQL::Cache::Middleware::Azu (deprecated)" do
  it "keeps Handler as the HTTP handler and setup! as a call to use" do
    CQL::Cache::Middleware::Azu::Handler.new.should be_a(CQL::Cache::Middleware::HTTP)

    pipeline = PipelineWithUse.new
    CQL::Cache::Middleware::Azu.setup!(pipeline).should be(pipeline)
    pipeline.handlers.size.should eq(1)
    pipeline.handlers.first.should be_a(CQL::Cache::Middleware::Azu::Handler)
  end
end
