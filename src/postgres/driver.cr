require "db"
require "./connection"
require "./refusal"

module CQL::Postgres
  # Lets crystal-db open `postgres://` and `postgresql://` URLs with the wire
  # driver, so `CQL::Schema` and `DB.open` use it unless another PostgreSQL
  # driver (the `pg` shard) registered those names first. `cockroachdb://` is
  # opt-in (`register_cockroachdb`, or compile with
  # `-Dcql_postgres_driver_cockroachdb`) because only CockroachDB 24.3 was
  # checked against a real server.
  # crystal-db keeps its own pool; the options it owns are removed from the URL
  # before the rest is read as a `Config`.
  class Driver < ::DB::Driver
    NAMES            = {Connection::DRIVER_NAME, "postgresql"}
    COCKROACHDB_NAME = "cockroachdb"
    DB_OWNED_KEYS    = {"initial_pool_size", "max_pool_size", "max_idle_pool_size", "checkout_timeout", "retry_attempts", "retry_delay", "prepared_statements", "prepared_statements_cache"}

    class Builder < ::DB::ConnectionBuilder
      def initialize(@config : Config, @options : ::DB::Connection::Options)
      end

      # Transport failures become `DB::ConnectionRefused`, which crystal-db's
      # pool retries (`retry_attempts`, `retry_delay`); server errors do not.
      def build : ::DB::Connection
        Refusal.translate { Connection.open(@config, @options) }
      end
    end

    # Registers the driver under every default name nobody has claimed yet.
    def self.register : Nil
      NAMES.each { |name| register(name) }
    end

    # Opts `DB.open("cockroachdb://...")` in to this driver.
    def self.register_cockroachdb : Nil
      register(COCKROACHDB_NAME)
    end

    private def self.register(name : String) : Nil
      ::DB.register_driver(name, self) unless registered?(name)
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

# Compile with `-Dcql_no_postgres_driver` to keep crystal-db's registry untouched.
{% unless flag?(:cql_no_postgres_driver) %}
  CQL::Postgres::Driver.register
  {% if flag?(:cql_postgres_driver_cockroachdb) %}
    CQL::Postgres::Driver.register_cockroachdb
  {% end %}
{% end %}
