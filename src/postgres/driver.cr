require "db"
require "./connection"

module CQL::Postgres
  # Lets crystal-db open `postgres://`, `postgresql://` and `cockroachdb://`
  # URLs with the wire driver, so `CQL::Schema` and `DB.open` use it unless
  # another PostgreSQL driver (the `pg` shard) registered its names first.
  # crystal-db keeps its own pool; the options it owns are removed from the URL
  # before the rest is read as a `Config`.
  class Driver < ::DB::Driver
    NAMES         = {"postgres", "postgresql", "cockroachdb"}
    DB_OWNED_KEYS = {"initial_pool_size", "max_pool_size", "max_idle_pool_size", "checkout_timeout", "retry_attempts", "retry_delay", "prepared_statements", "prepared_statements_cache"}

    class Builder < ::DB::ConnectionBuilder
      def initialize(@config : Config, @options : ::DB::Connection::Options)
      end

      def build : ::DB::Connection
        Connection.open(@config, @options)
      end
    end

    # Registers the driver under every name nobody has claimed yet.
    def self.register : Nil
      NAMES.each do |name|
        ::DB.register_driver(name, self) unless registered?(name)
      end
    end

    def self.registered?(name : String) : Bool
      ::DB.driver_class(name)
      true
    rescue ArgumentError
      false
    end

    def connection_builder(uri : URI) : ::DB::ConnectionBuilder
      params = HTTP::Params.parse(uri.query || "")
      options = connection_options(params).copy_with(prepared_statements_cache: false)
      Builder.new(Config.from_uri(uri, ignoring: DB_OWNED_KEYS), options)
    end
  end
end

CQL::Postgres::Driver.register
