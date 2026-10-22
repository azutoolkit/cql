module CQL::Postgres
  module Database
    class Error < Exception
    end

    # Raised at boot or first use when the database cannot be reached.
    class ConnectionError < Error
    end
  end
end
