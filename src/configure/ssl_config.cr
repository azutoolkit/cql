module CQL::Configure
  # SSL/TLS configuration
  class SSLConfig
    property mode : String = "prefer"
    property cert_path : String? = nil
    property key_path : String? = nil
    property ca_path : String? = nil

    def apply_to_params(params : HTTP::Params, adapter : Adapter) : Nil
      case adapter
      when Adapter::Postgres, Adapter::MySql
        params.add("sslmode", mode)
        params.add("sslcert", cert_path) if cert_path
        params.add("sslkey", key_path) if key_path
        params.add("sslca", ca_path) if ca_path
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
