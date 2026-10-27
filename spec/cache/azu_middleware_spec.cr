require "../spec_helper"
require "http/server"

# The shape of `Azu::App` that `setup!` relies on: handlers are an array, chained in front of the router.
private class AzuShapedApp
  getter seen_request_id : String?

  def default_handlers : Array(HTTP::Handler)
    [] of HTTP::Handler
  end

  def dispatcher(handlers : Array(HTTP::Handler)) : HTTP::Handler
    HTTP::Server.build_middleware(handlers, ->(_context : HTTP::Server::Context) {
      @seen_request_id = CQL::Cache::RequestQueryCacheHelper.stats["request_id"].as(String)
      nil
    })
  end
end

# The shape of `Azu::HandlerPipeline`: `use` adds a handler and returns the pipeline.
private class PipelineWithUse
  getter handlers = [] of HTTP::Handler

  def use(handler : HTTP::Handler) : self
    @handlers << handler
    self
  end
end

private class OtherHandler
  include HTTP::Handler

  def call(context : HTTP::Server::Context)
    call_next(context)
  end
end

private def serve(app : AzuShapedApp, handlers : Array(HTTP::Handler), request_id : String) : Nil
  request = HTTP::Request.new("GET", "/", HTTP::Headers{"X-Request-ID" => request_id})
  context = HTTP::Server::Context.new(request, HTTP::Server::Response.new(IO::Memory.new))
  app.dispatcher(handlers).call(context)
end

describe CQL::Cache::Middleware::Azu do
  describe ".setup!" do
    it "adds the cache handler to the app's handlers, which then run each request in its own cache" do
      app = AzuShapedApp.new
      handlers = CQL::Cache::Middleware::Azu.setup!(app.default_handlers)

      serve(app, handlers, "req-azu-1")

      app.seen_request_id.should eq("req-azu-1")
      CQL::Cache::RequestQueryCacheHelper.stats["request_id"].should eq("none")
    end

    it "appends the handler to the same array, after the handlers already there" do
      other = OtherHandler.new
      handlers = [other] of HTTP::Handler

      CQL::Cache::Middleware::Azu.setup!(handlers).should be(handlers)
      handlers.first.should be(other)
      handlers.last.should be_a(CQL::Cache::Middleware::Azu::Handler)
      handlers.size.should eq(2)
    end

    it "calls use on a pipeline that has it, as Azu::HandlerPipeline does, and returns what use returns" do
      pipeline = PipelineWithUse.new

      CQL::Cache::Middleware::Azu.setup!(pipeline).should be(pipeline)
      pipeline.handlers.size.should eq(1)
      pipeline.handlers.first.should be_a(CQL::Cache::Middleware::Azu::Handler)
    end

    it "adds the handler once" do
      handlers = CQL::Cache::Middleware::Azu.setup!([] of HTTP::Handler)

      CQL::Cache::Middleware::Azu.setup!(handlers).count(&.is_a?(CQL::Cache::Middleware::Azu::Handler)).should eq(1)
    end
  end
end
