require "./dialect"

module Expression
  # PostgreSQL specific dialect implementation - optimized for performance
  class PostgresDialect < BaseDialect
    # A-Z only in a multibyte (UTF-8) database; a single-byte encoding also folds other letters, not handled here.
    def fold_unquoted_name(name : String) : String
      name.downcase(Unicode::CaseOptions::ASCII)
    end

    # Cache for frequently used PostgreSQL-specific strings
    @@cached_strings = {
      "postgres_drop_index_prefix"  => "DROP INDEX IF EXISTS ",
      "postgres_alter_table_prefix" => "ALTER TABLE ",
    }

    PLACEHOLDERS = Array.new(1025) { |index| "$#{index}" }

    # PostgreSQL uses $1, $2, etc. for placeholders
    def placeholder_format(param_index : Int32) : String
      (PLACEHOLDERS[param_index]? if param_index >= 0) || "$#{param_index}"
    end

    def structure_dump(uri : URI) : String
      args = [
        "--no-comments",
        "--schema-only",
        "--username=#{uri.user}",
        "--dbname=#{uri.path[1..-1]}",
      ] + server_options(uri)
      run_dump("pg_dump", args, env: dump_env(uri))
    end

    # The password and the `sslmode` query parameter of *uri*, as pg_dump reads them from its
    # environment. Other query parameters are ignored.
    private def dump_env(uri : URI) : Hash(String, String)
      env = {} of String => String
      uri.password.try { |password| env["PGPASSWORD"] = password }
      uri.query_params["sslmode"]?.try { |mode| env["PGSSLMODE"] = mode }
      env
    end

    def auto_increment_primary_key(column : CQL::BaseColumn, col_type : String) : String
      build_sql(64) do |str|
        str << column.name << " " << col_type
        if column.auto_increment?
          str << " GENERATED ALWAYS AS IDENTITY PRIMARY KEY"
        else
          str << " PRIMARY KEY"
        end
      end
    end

    # PostgreSQL-specific implementations that differ from base
    def rename_column(table_name : String, old_name : String, new_name : String, column_type : String?) : String
      "RENAME COLUMN #{old_name} TO #{new_name}"
    end

    def modify_column(table_name : String, column_name : String, column_type : String) : String
      "ALTER COLUMN #{column_name} TYPE #{column_type}"
    end

    def drop_index(index_name : String, table_name : String) : String
      "#{@@cached_strings["postgres_drop_index_prefix"]}#{index_name}"
    end

    def drop_foreign_key(table_name : String, constraint_name : String) : String
      "DROP CONSTRAINT #{constraint_name}"
    end

    def rename_table(old_name : String, new_name : String) : String
      "#{@@cached_strings["postgres_alter_table_prefix"]}#{old_name} RENAME TO #{new_name}"
    end

    # Table operations using cached strings
    def truncate_table(table_name : String) : String
      "TRUNCATE TABLE #{table_name}"
    end

    def create_table_prefix(table_name : String) : String
      "CREATE TABLE IF NOT EXISTS #{table_name}"
    end

    def drop_table(table_name : String) : String
      "DROP TABLE IF EXISTS #{table_name}"
    end

    def alter_table(table_name : String, action : String) : String
      "#{@@cached_strings["postgres_alter_table_prefix"]}#{table_name} #{action}"
    end

    # Column operations - using optimized helper methods
    def define_column(
      column_name : String,
      column_type : String,
      default_value : DB::Any?,
      nullable : Bool,
      unique : Bool,
      timestamp_column : Bool,
    ) : String
      # For timestamp columns, use the database function directly (without quoting)
      if timestamp_column && default_value.is_a?(String) && default_value == "CURRENT_TIMESTAMP"
        build_sql(128) do |str|
          str << column_name << " " << column_type
          str << " DEFAULT " << default_value
          str << " NOT NULL" unless nullable
          str << " UNIQUE" if unique
        end
      else
        build_column_definition(column_name, column_type, default_value, nullable, unique)
      end
    end

    def drop_column(column_name : String) : String
      "DROP COLUMN #{column_name}"
    end

    # Index operations - using optimized helper
    def create_index(
      index_name : String,
      table_name : String,
      columns : Array(String),
      unique : Bool,
    ) : String
      build_create_index(index_name, table_name, columns, unique)
    end

    # Foreign key operations
    def add_foreign_key(
      constraint_name : String,
      table_name : String,
      columns : Array(String),
      references_table : String,
      references_columns : Array(String),
      on_delete : String,
      on_update : String,
    ) : String
      build_sql(256) do |str|
        str << "ADD CONSTRAINT " << constraint_name
        str << " FOREIGN KEY (" << columns.join(", ") << ")"
        str << " REFERENCES " << references_table
        str << " (" << references_columns.join(", ") << ")"
        str << " ON DELETE " << on_delete
        str << " ON UPDATE " << on_update
      end
    end

    def define_foreign_key(fk : CQL::ForeignKey) : String
      constraint_name = fk.name
      on_delete = fk.on_delete.to_s.upcase.gsub("_", " ")
      on_update = fk.on_update.to_s.upcase.gsub("_", " ")

      build_sql(256) do |str|
        str << "CONSTRAINT #{constraint_name} " if constraint_name
        str << "FOREIGN KEY (" << fk.columns.join(", ") << ")"
        str << " REFERENCES " << fk.references_table
        str << " (" << fk.references_columns.join(", ") << ")"
        str << " ON DELETE " << on_delete unless fk.on_delete == :no_action
        str << " ON UPDATE " << on_update unless fk.on_update == :no_action
      end
    end

    # Query components - optimized implementations
    def format_limit_offset(limit : DB::Any, offset : DB::Any?) : String
      if offset
        " LIMIT #{limit} OFFSET #{offset}"
      else
        " LIMIT #{limit}"
      end
    end

    def display_name : String
      "PostgreSQL"
    end

    def format_ilike(column : String, placeholder : String) : String
      "#{column} ILIKE #{placeholder}"
    end

    # PostgreSQL takes the path as a text[] literal: `{a,b,0}`.
    def json_path_param(path : Expression::JsonPath) : String
      "{#{path.segments.join(",")}}"
    end

    def format_json_text(column : String, path_placeholder : String) : String
      "#{column} #>> #{path_placeholder}::text[]"
    end

    def format_json_contains(column : String, placeholder : String) : String
      "#{column} @> #{placeholder}::jsonb"
    end

    def format_geo_within(column : String, longitude : String, latitude : String, meters : String) : String
      point = "ST_SetSRID(ST_MakePoint(#{longitude}::float8, #{latitude}::float8), 4326)::geography"
      "ST_DWithin(#{column}::geography, #{point}, #{meters}::float8)"
    end

    def format_not_ilike(column : String, placeholder : String) : String
      "#{column} NOT ILIKE #{placeholder}"
    end

    def format_distinct_on(columns : Array(String)) : String
      "DISTINCT ON (#{columns.join(", ")}) "
    end

    # PostgreSQL returns one text column per plan line.
    def format_plan_row(columns : Array(String)) : String
      columns.first
    end

    def supports_returning? : Bool
      true
    end

    def supports_transactional_ddl? : Bool
      true
    end

    # `pg_advisory_xact_lock` on the bound key: held until the transaction ends.
    def migration_lock_sql : String?
      "SELECT pg_advisory_xact_lock(#{placeholder_format(1)})"
    end

    # `SHOW transaction_isolation` reads the level in lower case ("read committed") and takes no snapshot.
    def transaction_isolation_sql : String?
      "SHOW transaction_isolation"
    end

    # REPEATABLE READ and SERIALIZABLE take their snapshot at the lock statement, before it waits.
    def migration_lock_isolation_safe?(level : String) : Bool
      level.in?("read committed", "read uncommitted")
    end

    # The server's `lock_timeout` as text, such as "0" or "1min".
    def lock_timeout_sql : String?
      "SELECT current_setting('lock_timeout')"
    end

    # `true`: SET LOCAL, so the bound ends with the transaction.
    def set_lock_timeout_sql : String?
      "SELECT set_config('lock_timeout', #{placeholder_format(1)}, true)"
    end

    # SQLSTATE 55P03 (lock_not_available), from CQL's own driver or, when the app loads it, the `pg` shard.
    def lock_timed_out?(error : Exception) : Bool
      {% if @top_level.has_constant?(:PQ) %}
        return error.field_message(:code) == "55P03" if error.is_a?(PQ::PQError)
      {% end %}
      error.is_a?(CQL::Postgres::ServerError) && error.sqlstate == "55P03"
    end

    def format_returning(columns : Array(String)) : String
      return "" if columns.empty?
      " RETURNING #{columns.join(", ")}"
    end

    # PostgreSQL supports RETURNING for both UPDATE and DELETE
    def format_update_returning(columns : Array(String)) : String
      format_returning(columns)
    end

    def format_delete_returning(columns : Array(String)) : String
      format_returning(columns)
    end

    # A value holding a backslash becomes an `E'...'` literal with backslashes doubled, which reads the same
    # whether `standard_conforming_strings` is on or off; a plain literal would treat `\` as an escape when off.
    protected def quote_string_literal(value : String) : String
      return super unless value.includes?('\\')

      "E'#{value.gsub({'\\' => "\\\\", '\'' => "''"})}'"
    end

    # Returns the SQL function for the current timestamp (evaluated by database)
    def current_timestamp : String
      "CURRENT_TIMESTAMP"
    end
  end
end
