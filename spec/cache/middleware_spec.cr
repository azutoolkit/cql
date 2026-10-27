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
  cache.enabled = false # also forgets active requests
  cache.end_request     # with none active: drops the request id
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

  it "runs the request with its X-Request-ID as the request id and ends it afterwards" do
    request_id_inside(HTTP::Headers{"X-Request-ID" => "req-1"}) { }.should eq("req-1")

    current_request_id.should eq("none")
    CQL::Cache::RequestQueryCacheHelper.enabled?.should be_false
  end

  it "generates a 16-character hex id when the request has no X-Request-ID" do
    request_id_inside { }.not_nil!.should match(/\A[0-9a-f]{16}\z/)
  end

  it "ends the request when the rest of the chain raises" do
    expect_raises(SpecFailure) do
      request_id_inside(HTTP::Headers{"X-Request-ID" => "req-2"}) { raise SpecFailure.new }
    end

    current_request_id.should eq("none")
    CQL::Cache::RequestQueryCacheHelper.enabled?.should be_false
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
