module CQL
  # Configuration for schema synchronization
  struct MigratorConfig
    property schema_file_path : String
    property schema_name : Symbol
    property schema_symbol : Symbol
    property migration_table_name : Symbol
    property? auto_sync : Bool = true
    # How long `Migrator.new` and a run wait for another migrator's PostgreSQL migration lock before raising; nil
    # leaves the wait to the server's own `lock_timeout` (none by default). Only that wait: migrations keep theirs.
    property lock_timeout : Time::Span?
    # The environment variable the schema file's `uri:` line reads.
    property schema_url_env : String

    def initialize(
      @schema_file_path : String = "src/schemas/app_schema.cr",
      @schema_name : Symbol = :AppSchema,
      @schema_symbol : Symbol = :app_schema,
      @migration_table_name : Symbol = :cql_schema_migrations,
      @auto_sync : Bool? = true,
      @lock_timeout : Time::Span? = 60.seconds,
      @schema_url_env : String = "DATABASE_URL",
    )
    end
  end
end
