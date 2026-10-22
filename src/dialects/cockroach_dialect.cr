require "./postgres_dialect"

module Expression
  # CockroachDB speaks the PostgreSQL wire protocol and SQL, so everything is
  # inherited; only what differs is overridden.
  class CockroachDialect < PostgresDialect
    def display_name : String
      "CockroachDB"
    end

    # pg_dump does not work against CockroachDB.
    def structure_dump(uri : URI) : String
      raise CQL::DialectError.new("CockroachDB", "pg_dump-style structure dumps", "Run `SHOW CREATE ALL TABLES` instead.")
    end
  end
end
