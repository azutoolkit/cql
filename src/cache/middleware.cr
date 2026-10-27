require "./request_query_cache"
require "http/server"

module CQL
  module Cache
    # Middleware helpers for integrating per-request query caching with various web frameworks
    module Middleware
      # A client-supplied request id is kept only when it matches this: 1 to 128 ASCII letters, digits, `.`, `_` or `-`.
      VALID_REQUEST_ID = /\A[A-Za-z0-9._-]{1,128}\z/

      # *request_id* when it is valid, else a random 16-character hex id; nil stays nil (the tracker then picks one).
      def self.trusted_request_id(request_id : String?) : String?
        return if request_id.nil?

        request_id.matches?(VALID_REQUEST_ID) ? request_id : Random::Secure.hex(8)
      end

      # Base middleware functionality that can be adapted for different frameworks
      module BaseMiddleware
        # Call this at the start of each request. Tracks only when `CQL.config.cache.on?` and
        # `CQL.config.cache.request_cache?` (`CQL.start_request_cache`).
        def start_request_cache(request_id : String? = nil) : Nil
          CQL.start_request_cache(Middleware.trusted_request_id(request_id))
        end

        # Call this at the end of each request (`CQL.end_request_cache`). It ends the fiber's request even when the
        # switches are off; `with_request_cache` ends only a request it started.
        def end_request_cache : Nil
          CQL.end_request_cache
        end

        # Runs the block as one request (`CQL.with_request_cache`, with the id validated): it starts and ends a
        # request only when the switches are on at the start.
        def with_request_cache(request_id : String? = nil, &)
          CQL.with_request_cache(Middleware.trusted_request_id(request_id)) { yield }
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
          CQL::Cache::Middleware::Amber.with_request_cache(request_id) { call_next(context) }
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

      # Generic HTTP::Server middleware. It starts a request on the request query tracker (`RequestQueryCacheHelper`)
      # for the fiber serving the request, with its `X-Request-ID` when valid (or a random id), and ends it in an
      # `ensure`. It tracks only when `cache.on` and `cache.request_cache` are set in `CQL.configure`.
      # Usage:
      #   server = HTTP::Server.new([
      #     CQL::Cache::Middleware::HTTP.new,
      #     # ... other handlers
      #   ])
      #
      # In an Azu app, after `Azu::Handler::RequestId` (whose id it then reuses):
      #   app.start(app.default_handlers + [CQL::Cache::Middleware::HTTP.new] of HTTP::Handler)
      class HTTP
        include ::HTTP::Handler
        include BaseMiddleware

        def call(context : ::HTTP::Server::Context)
          request_id = context.request.headers["X-Request-ID"]? || Random::Secure.hex(8)
          with_request_cache(request_id) { call_next(context) }
        end
      end

      # Azu framework middleware (deprecated). An `Azu::App` takes its handlers as an array and has no `use`, and Azu
      # endpoints have no `before_action`/`after_action`: mount `CQL::Cache::Middleware::HTTP` instead (see above).
      # Azu's own `require "azu/cql"` bridge (`Azu::CQL::Middleware`) is the Azu-aware piece: request tagging,
      # telemetry and per-request transactions.
      #
      # `before_request(ctx)` / `after_request(ctx)` can still be called from a handler of your own.
      module Azu
        extend BaseMiddleware

        # The same handler as `CQL::Cache::Middleware::HTTP`, under its old name.
        @[Deprecated("Use CQL::Cache::Middleware::HTTP")]
        class Handler < CQL::Cache::Middleware::HTTP
        end

        # Controller mixin for frameworks with `before_action`/`after_action`; Azu endpoints have neither.
        @[Deprecated("Azu endpoints have no before_action/after_action: mount CQL::Cache::Middleware::HTTP in the app's handlers")]
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

        # Convenience method to set up automatic middleware
        # Usage: CQL::Cache::Middleware::Azu.setup!(app)
        @[Deprecated("Azu::App has no `use`: app.start(app.default_handlers + [CQL::Cache::Middleware::HTTP.new] of HTTP::Handler). Azu::HandlerPipeline#use still accepts the handler.")]
        def self.setup!(app)
          # This would integrate with Azu's middleware system
          # The exact implementation depends on Azu's API
          app.use(Handler.new)
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
          with_request_cache(request_id) { yield }
        end
      end
    end
  end
end
