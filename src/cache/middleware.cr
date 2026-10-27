require "./request_query_cache"
require "http/server"

module CQL
  module Cache
    # Middleware helpers for integrating per-request query caching with various web frameworks
    module Middleware
      # Base middleware functionality that can be adapted for different frameworks
      module BaseMiddleware
        # Call this at the start of each request
        def start_request_cache(request_id : String? = nil) : Nil
          CQL::Cache::RequestQueryCacheHelper.start_request(request_id)
        end

        # Call this at the end of each request
        def end_request_cache : Nil
          CQL::Cache::RequestQueryCacheHelper.end_request
        end

        # Enable/disable query caching
        def enable_query_cache(enabled : Bool = true) : Nil
          CQL::Cache::RequestQueryCacheHelper.enabled = enabled
        end

        # Get cache statistics (useful for debugging)
        def query_cache_stats : Hash(String, String | Int32 | Int64 | Float64)
          CQL::Cache::RequestQueryCacheHelper.stats
        end
      end

      # Kemal framework middleware
      # Usage:
      #   require "cql/cache/middleware"
      #
      #   # Enable per-request query caching
      #   before_all do |env|
      #     CQL::Cache::Middleware::Kemal.before_request(env)
      #   end
      #
      #   after_all do |env|
      #     CQL::Cache::Middleware::Kemal.after_request(env)
      #   end
      module Kemal
        extend BaseMiddleware

        def self.before_request(env)
          request_id = env.request.headers["X-Request-ID"]? || Random::Secure.hex(8)
          start_request_cache(request_id)
        end

        def self.after_request(env)
          end_request_cache
        end

        # Convenience method to set up automatic middleware
        def self.setup!
          # This would need to be called after requiring kemal
          # before_all { |env| CQL::Cache::Middleware::Kemal.before_request(env) }
          # after_all { |env| CQL::Cache::Middleware::Kemal.after_request(env) }
        end
      end

      # Lucky framework integration
      # Usage:
      #   # In src/actions/application_action.cr
      #   abstract class ApplicationAction < Lucky::Action
      #     include CQL::Cache::Middleware::Lucky
      #   end
      module Lucky
        extend BaseMiddleware

        macro included
          before start_query_cache
          after end_query_cache
        end

        def start_query_cache
          request_id = request.headers["X-Request-ID"]? || Random::Secure.hex(8)
          CQL::Cache::Middleware::Lucky.start_request_cache(request_id)
        end

        def end_query_cache
          CQL::Cache::Middleware::Lucky.end_request_cache
        end
      end

      # Amber framework middleware
      # Usage:
      #   # Create a pipe in src/pipes/query_cache_pipe.cr
      #   class QueryCachePipe < Amber::Pipe::Base
      #     include CQL::Cache::Middleware::Amber
      #   end
      #
      #   # In config/routes.cr
      #   pipeline :web, [QueryCachePipe]
      module Amber
        extend BaseMiddleware

        def call(context)
          request_id = context.request.headers["X-Request-ID"]? || Random::Secure.hex(8)
          CQL::Cache::Middleware::Amber.start_request_cache(request_id)

          begin
            call_next(context)
          ensure
            CQL::Cache::Middleware::Amber.end_request_cache
          end
        end
      end

      # Spider-Gazelle framework middleware
      # Usage:
      #   # In your controller
      #   class ApplicationController < SpiderGazelle::Controller
      #     include CQL::Cache::Middleware::SpiderGazelle
      #   end
      module SpiderGazelle
        extend BaseMiddleware

        macro included
          before_action :start_query_cache
          after_action :end_query_cache
        end

        def start_query_cache
          request_id = request.headers["X-Request-ID"]? || Random::Secure.hex(8)
          CQL::Cache::Middleware::SpiderGazelle.start_request_cache(request_id)
        end

        def end_query_cache
          CQL::Cache::Middleware::SpiderGazelle.end_request_cache
        end
      end

      # Azu framework middleware. An Azu app takes its handlers as an array (`Azu::App#start`, `#server`), so the
      # cache is a handler in that array. Put it after `Azu::Handler::RequestId`, whose `X-Request-ID` it reuses:
      #
      #   app = Azu::App.default # or Azu::App.new
      #   app.start(CQL::Cache::Middleware::Azu.setup!(app.default_handlers))
      #   # the same as: app.start(app.default_handlers + [CQL::Cache::Middleware::Azu::Handler.new] of HTTP::Handler)
      #
      # Azu's own bridge (`require "azu/cql"`) mounts `Azu::CQL::Middleware` (request tagging, per-request
      # transactions) the same way; the two are independent and can both be in the array.
      #
      # `Controller` relies on `before_action`/`after_action` macros, which Azu endpoints do not have.
      module Azu
        extend BaseMiddleware

        # HTTP Handler implementation for Azu
        class Handler
          include ::HTTP::Handler
          include BaseMiddleware

          def call(context : ::HTTP::Server::Context)
            request_id = context.request.headers["X-Request-ID"]? || Random::Secure.hex(8)
            start_request_cache(request_id)

            begin
              call_next(context)
            ensure
              end_request_cache
            end
          end
        end

        # Controller mixin for Azu controllers
        module Controller
          extend BaseMiddleware

          macro included
            # Add before/after hooks if Azu supports them
            before_action :start_azu_query_cache
            after_action :end_azu_query_cache
          end

          def start_azu_query_cache
            request_id = request.headers["X-Request-ID"]? || Random::Secure.hex(8)
            CQL::Cache::Middleware::Azu.start_request_cache(request_id)
          end

          def end_azu_query_cache
            CQL::Cache::Middleware::Azu.end_request_cache
          end
        end

        # Hook-based integration for Azu applications
        def self.before_request(context)
          request_id = context.request.headers["X-Request-ID"]? || Random::Secure.hex(8)
          start_request_cache(request_id)
        end

        def self.after_request(context)
          end_request_cache
        end

        # Appends a `Handler` to *handlers*, unless one is there, and returns the array: pass it to
        # `Azu::App#start` or `Azu::App#server`. Type the array `of HTTP::Handler`, as `default_handlers` is: an array of
        # one handler class (`[Azu::Handler::Rescuer.new]`) fails to compile at `<<`.
        def self.setup!(handlers : Array(::HTTP::Handler)) : Array(::HTTP::Handler)
          handlers.any?(Handler) ? handlers : handlers << Handler.new
        end

        # For anything with a `use(handler)`, such as `Azu::HandlerPipeline`: returns `pipeline.use(Handler.new)`.
        # `Azu::App` has no `use`, so passing the app fails to compile and names the array overload.
        def self.setup!(pipeline : T) forall T
          {% if T.has_method?(:use) || T.ancestors.any?(&.has_method?(:use)) %}
            pipeline.use(Handler.new)
          {% else %}
            {% raise "CQL::Cache::Middleware::Azu.setup! takes the app's Array(HTTP::Handler) or a pipeline with `use` (Azu::HandlerPipeline), not #{T}: app.start(CQL::Cache::Middleware::Azu.setup!(app.default_handlers))" %}
          {% end %}
        end
      end

      # Generic HTTP::Server middleware
      # Usage:
      #   server = HTTP::Server.new([
      #     CQL::Cache::Middleware::HTTP.new,
      #     # ... other handlers
      #   ])
      class HTTP
        include ::HTTP::Handler
        include BaseMiddleware

        def call(context : ::HTTP::Server::Context)
          request_id = context.request.headers["X-Request-ID"]? || Random::Secure.hex(8)
          start_request_cache(request_id)

          begin
            call_next(context)
          ensure
            end_request_cache
          end
        end
      end

      # Manual integration helper for any framework
      # Usage:
      #   # At the start of each request:
      #   CQL::Cache::Middleware::Manual.start_request
      #
      #   # At the end of each request:
      #   CQL::Cache::Middleware::Manual.end_request
      module Manual
        extend BaseMiddleware

        def self.start_request(request_id : String? = nil)
          start_request_cache(request_id)
        end

        def self.end_request
          end_request_cache
        end

        def self.with_request(request_id : String? = nil, &)
          start_request(request_id)
          begin
            yield
          ensure
            end_request
          end
        end
      end
    end
  end
end
