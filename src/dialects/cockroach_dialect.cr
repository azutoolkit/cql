require "./postgres_dialect"

module Expression
  # CockroachDB speaks the PostgreSQL wire protocol and SQL, so everything is
  # inherited; only what differs is overridden.
  class CockroachDialect < PostgresDialect
    def display_name : String
      "CockroachDB"
    end

    # Every letter is lowercased, and the Turkish dotted and dotless capital and small i fold to `i`.
    def fold_unquoted_name(name : String) : String
      name.gsub({'İ' => 'i', 'ı' => 'i'}).downcase.unicode_normalize(:nfc)
    end

    # Schema changes in an explicit transaction are not atomic (recent versions also commit the
    # transaction first, through `autocommit_before_ddl`).
    def supports_transactional_ddl? : Bool
      false
    end

    # No advisory locks: concurrent migrators are not serialised.
    def migration_lock_sql : String?
      nil
    end

    def migration_try_session_lock_sql : String?
      nil
    end

    # pg_dump does not work against CockroachDB.
    def structure_dump(uri : URI) : String
      raise CQL::DialectError.new("CockroachDB", "pg_dump-style structure dumps", "Run `SHOW CREATE ALL TABLES` instead.")
    end
  end
end
