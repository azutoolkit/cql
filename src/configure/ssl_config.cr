module CQL::Configure
  # SSL/TLS configuration
  class SSLConfig
    property mode : String = "prefer"
    property cert_path : String? = nil
    property key_path : String? = nil
    property ca_path : String? = nil

    def apply_to_params(params : HTTP::Params, adapter : Adapter) : Nil
      case adapter
      when Adapter::Postgres, Adapter::CockroachDB, Adapter::MySql
        params.add("sslmode", mode)
        ca_key = adapter.postgres_compatible? ? "sslrootcert" : "sslca"
        {"sslcert" => cert_path, "sslkey" => key_path, ca_key => ca_path}.each do |key, path|
          params.add(key, path) if path
        end
      end
    end

    def validate! : Nil
      valid_ssl_modes = %w[disable allow prefer require verify-ca verify-full]
      unless valid_ssl_modes.includes?(mode)
        raise ArgumentError.new("ssl_mode must be one of: #{valid_ssl_modes.join(", ")}")
      end
    end
  end
end
