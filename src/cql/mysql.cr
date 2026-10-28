# Optional integration: retains crystal-mysql's statements and row decoding,
# adding modern authentication and verified TLS before handing it the transport.
require "mysql"
require "../cql"
require "../mysql/authentication"

class MySql::Connection
  # A distinct overload leaves the upstream driver's constructor intact.
  def initialize(options : ::DB::Connection::Options, mysql_options : CQL::MySQL::Options)
    super(options)
    @socket = CQL::MySQL::Authentication.connect(mysql_options)
  end
end

module CQL::MySQL
  class Driver < ::MySql::Driver
    class Builder < ::DB::ConnectionBuilder
      def initialize(@options : ::DB::Connection::Options, @mysql : Options)
      end

      def build : ::DB::Connection
        ::MySql::Connection.new(@options, @mysql)
      end
    end

    def connection_builder(uri : URI) : ::DB::ConnectionBuilder
      Builder.new(connection_options(HTTP::Params.parse(uri.query || "")), Options.from_uri(uri))
    end
  end
end

DB.register_driver "mysql", CQL::MySQL::Driver
