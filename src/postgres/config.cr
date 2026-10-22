require "uri"
require "./errors"

module CQL::Postgres
  enum SSLMode
    Disable
    Prefer
    Require
    VerifyFull

    def self.parse_mode(text : String) : SSLMode
      case text
      when "disable"     then Disable
      when "prefer"      then Prefer
      when "require"     then Require
      when "verify-full" then VerifyFull
      else                    raise ArgumentError.new("unsupported sslmode #{text.inspect} (use disable, prefer, require or verify-full)")
      end
    end
  end

  # Everything needed to open a connection. The password never appears in
  # `inspect`, `to_s` or error messages.
  #
  # Query-string keys other than the ones listed here are sent to the server as
  # startup parameters (`?search_path=app`). `user`, `database`,
  # `client_encoding` and `replication` cannot be set that way, and libpq-only
  # options the driver does not honour are rejected instead of ignored, so a
  # typo can never silently weaken a connection.
  #
  # `sslmode=prefer` and `require` encrypt without verifying the server, like
  # libpq, so `sslrootcert` is only accepted with `verify-full`, where it adds a
  # CA to the system trust store (Crystal's TLS context cannot drop the system
  # roots). Query values are percent-decoded only; `+` stays a plus.
  class Config
    SCHEMES              = {"postgres", "postgresql", "cockroachdb"}
    DRIVER_OPTION_KEYS   = {"pool_size", "checkout_timeout", "health_check_after"}
    RESERVED_PARAMETERS  = {"user", "database", "dbname", "password", "hostaddr", "client_encoding", "replication"}
    UNSUPPORTED_LIBPQ    = {"sslcert", "sslkey", "sslcrl", "sslcompression", "sslsni", "sslpassword", "channel_binding", "require_auth", "target_session_attrs", "passfile", "service", "gssencmode", "krbsrvname"}
    DEFAULT_CONNECT_WAIT = 10.0

    getter host : String
    getter port : Int32
    getter user : String
    getter database : String
    getter ssl_mode : SSLMode
    getter ssl_root_cert : String?
    # How long each step of connecting and starting up may block (TCP connect,
    # TLS, every server reply), not a total deadline; nil waits indefinitely.
    getter connect_timeout : Time::Span?
    getter application_name : String
    getter statement_cache_size : Int32
    getter startup_options : Hash(String, String)
    getter driver_options : Hash(String, String)
    protected getter password : String?

    def initialize(@host = "localhost", @port = 5432, @user = "postgres", @password = nil, database : String? = nil,
                   @ssl_mode = SSLMode::Prefer, @ssl_root_cert = nil, @connect_timeout = DEFAULT_CONNECT_WAIT.seconds,
                   @application_name = "cql", @statement_cache_size = 256,
                   @startup_options = {} of String => String, @driver_options = {} of String => String)
      @database = database || @user
    end

    # Parses `postgres://user:pass@host:5432/db?sslmode=require&application_name=app`.
    # A host starting with `/` (percent-encoded in the authority, or given as
    # `?host=`) is the directory of a Unix socket.
    def self.parse(url : String) : Config
      uri = URI.parse(url)
      raise ArgumentError.new("expected a postgres:// URL, got scheme #{uri.scheme.inspect}") unless SCHEMES.includes?(uri.scheme)
      params = query_parameters(uri.query)
      user, password = userinfo(url)
      driver_options = DRIVER_OPTION_KEYS.each_with_object({} of String => String) do |key, options|
        pop(params, key).try { |value| options[key] = value }
      end
      ssl_mode = SSLMode.parse_mode(pop(params, "sslmode") || "prefer")
      ssl_root_cert = pop(params, "sslrootcert")
      raise ArgumentError.new("sslrootcert needs sslmode=verify-full; other modes do not verify the server") if ssl_root_cert && !ssl_mode.verify_full?
      new(
        host: pop(params, "host") || uri.hostname.presence.try { |host| URI.decode(host) } || ENV["PGHOST"]? || "localhost",
        port: number(pop(params, "port"), "port") || uri.port || ENV["PGPORT"]?.try(&.to_i?) || 5432,
        user: user || ENV["PGUSER"]? || "postgres",
        password: password || ENV["PGPASSWORD"]?,
        database: uri.path.lstrip('/').presence.try { |name| URI.decode(name) },
        ssl_mode: ssl_mode,
        ssl_root_cert: ssl_root_cert,
        connect_timeout: timeout(pop(params, "connect_timeout")),
        application_name: pop(params, "application_name") || "cql",
        statement_cache_size: number(pop(params, "statement_cache_size"), "statement_cache_size") || 256,
        startup_options: startup_options(params),
        driver_options: driver_options
      )
    end

    # URI.parse reads `+` in the user info as a space (form encoding); in a URL
    # it is a literal plus, so the user info is split and percent-decoded here.
    private def self.userinfo(url : String) : {String?, String?}
      authority = url.partition("://")[2].split(/[\/?#]/, 2).first
      return {nil, nil} unless at = authority.rindex('@')
      user, separator, password = authority[0, at].partition(':')
      {URI.decode(user).presence, separator.empty? ? nil : URI.decode(password)}
    end

    private def self.query_parameters(query : String?) : Hash(String, String)
      (query || "").split('&', remove_empty: true).to_h do |pair|
        name, _, value = pair.partition('=')
        {URI.decode(name), URI.decode(value)}
      end
    end

    private def self.pop(params : Hash(String, String), name : String) : String?
      params.delete(name)
    end

    private def self.number(text : String?, name : String) : Int32?
      text.try { |value| value.to_i? || raise ArgumentError.new("#{name} must be a whole number, got #{value.inspect}") }
    end

    private def self.timeout(text : String?) : Time::Span?
      seconds = text.try { |value| value.to_f?.try { |number| number if number.finite? } || raise ArgumentError.new("connect_timeout must be a number of seconds, got #{value.inspect}") } || DEFAULT_CONNECT_WAIT
      seconds.positive? ? seconds.seconds : nil
    end

    private def self.startup_options(params : Hash(String, String)) : Hash(String, String)
      params.tap do |options|
        options.each_key do |key|
          raise ArgumentError.new("#{key} cannot be set through the URL query") if RESERVED_PARAMETERS.includes?(key)
          raise ArgumentError.new("the #{key} option is not supported by this driver") if UNSUPPORTED_LIBPQ.includes?(key) || key.starts_with?("ssl")
        end
      end
    end

    # Where the connection goes, for error messages.
    def address : String
      unix_socket? ? socket_path : "#{host}:#{port}"
    end

    def unix_socket? : Bool
      host.starts_with?('/')
    end

    def socket_path : String
      File.join(host, ".s.PGSQL.#{port}")
    end

    def password_for_authentication : String
      @password || raise AuthenticationError.new("the server requested a password but none was configured")
    end

    def startup_parameters : Hash(String, String)
      startup_options.merge({"user" => user, "database" => database, "client_encoding" => "UTF8", "application_name" => application_name})
    end

    def to_s(io : IO) : Nil
      io << "postgres://" << user << '@' << host << ':' << port << '/' << database
    end

    def inspect(io : IO) : Nil
      io << "#<CQL::Postgres::Config " << self << '>'
    end
  end
end
