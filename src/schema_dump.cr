require "db"
require "json"
require "./exceptions"
require "./atomic_file"
require "./cql"

module CQL
  # The `SchemaDump` class provides functionality to reverse-engineer a database schema
  # and generate a CQL schema definition file by inspecting existing database tables,
  # columns, indexes, and foreign keys.
  #
  # **Example** Dumping a SQLite database schema
  # ```
  # dumper = CQL::SchemaDump.new(CQL::Adapter::SQLite, "sqlite3://db/myapp.db")
  # dumper.dump_to_file("src/schemas/myapp_schema.cr", :MyApp, :myapp)
  # ```
  #
  # **Example** Dumping a PostgreSQL database schema
  # ```
  # dumper = CQL::SchemaDump.new(CQL::Adapter::Postgres, "postgresql://user:pass@localhost/mydb")
  # dumper.dump_to_file("src/schemas/production_schema.cr", :ProductionDB, :production_db)
  # ```
  class SchemaDump
    Log = CQL.config.logger

    class Error < CQL::Error; end

    DEFAULT_SCHEMA_DUMP_FILE_PATH = "./src/schemas/schema.cr"

    FOREIGN_KEY_RULES = {"cascade", "restrict", "set_null", "set_default", "no_action"}
    # Letters of any script, digits and underscores: what the databases accept unquoted and Crystal as a bare symbol.
    NAME_PATTERN = /\A[\p{L}_][\p{L}\p{N}_]*\z/
    # Hangul fillers are letters that render as nothing, so `a\u3164` would read as `a` in the schema file.
    INVISIBLE_LETTERS = {'\u115F', '\u1160', '\u3164', '\uFFA0'}
    # Unquoted, these build a different table without an error: SQLite reads `constraint TEXT` as a table
    # constraint, PostgreSQL reads `like VARCHAR` as a LIKE clause. Other keywords build or fail loudly. Both are
    # refused on every dialect, simpler than a per-dialect list.
    MISREAD_NAMES = {"constraint", "like"}

    # Query parameters the committed fallback URI keeps (compared case-insensitively): the connection, pool and
    # pragma settings CQL and its drivers read, none of them a secret. Any other parameter may hold one.
    FALLBACK_URI_PARAMS = Set{
      "sslmode", "sslrootcert", "sslca", "application_name", "connect_timeout", "host", "port", "encoding",
      "auth_methods", "statement_cache_size", "prepared_statements", "prepared_statements_cache", "pool_size",
      "pool_min_size", "max_pool_size", "initial_pool_size", "max_idle_pool_size", "checkout_timeout",
      "retry_attempts", "retry_delay", "query_timeout", "health_check_after", "max_queries", "max_idle_lifetime",
      "journal_mode", "synchronous", "foreign_keys", "busy_timeout", "cache_size", "wal_autocheckpoint",
      "min_protocol_version", "max_protocol_version", "binary_params",
    }

    getter adapter : Adapter
    getter uri : String
    private getter db : DB::Database | BoundReader

    # Introspection follows the schema's resource instead of reopening its URI.
    private class BoundReader
      def initialize(@schema : Schema)
      end

      def query_all(*args, **options)
        @schema.with_connection(&.query_all(*args, **options))
      end

      def query_each(*args, **options, &)
        @schema.with_connection { |connection| connection.query_each(*args, **options) { |rows| yield rows } }
      end

      def close : Nil
      end
    end

    def initialize(schema : Schema)
      @adapter = schema.adapter
      @uri = schema.uri? || ""
      @db = BoundReader.new(schema)
    end

    # Initialize the schema dumper
    # - **@param** adapter [Adapter] The database adapter to use
    # - **@param** uri [String] The database connection URI
    # - **@raise** [Error] If connection fails
    def initialize(@adapter : Adapter, @uri : String)
      @db = open_database_connection(@uri)
    end

    # Dump the database schema to a file
    # - **@param** file_path [String] Path where to save the schema file
    # - **@param** schema_name [Symbol] Name for the schema constant
    # - **@param** schema_symbol [Symbol] Symbol name for the schema
    # - **@param** env_var [String] The environment variable the file's `uri:` line reads
    def dump_to_file(file_path : String = DEFAULT_SCHEMA_DUMP_FILE_PATH, schema_name : Symbol = :AppSchema,
                     schema_symbol : Symbol = :app_schema, env_var : String = "DATABASE_URL")
      schema_content = generate_schema_content(schema_name, schema_symbol, env_var)

      AtomicFile.replace(file_path) { |file| file << schema_content }
      Log.info { "Schema dumped to #{file_path}" }
    end

    # Create a SchemaDump instance from an existing CQL::Schema
    # This is useful for migration integration where you already have a schema instance
    # - **@param** schema [CQL::Schema] The existing schema instance
    # - **@return** [SchemaDump] New SchemaDump instance
    def self.from_schema(schema : CQL::Schema)
      new(schema)
    end

    # Yields a dumper for *schema*'s database and closes its connections afterwards.
    # - **@return** the block's value
    def self.open(schema : CQL::Schema, &)
      dumper = from_schema(schema)
      begin
        yield dumper
      ensure
        dumper.close
      end
    end

    # Generate the schema content as a string
    # - **@param** schema_name [Symbol] Name for the schema constant
    # - **@param** schema_symbol [Symbol] Symbol name for the schema
    # - **@param** env_var [String] The environment variable the `uri:` line reads
    # - **@return** [String] The generated schema content
    def generate_schema_content(schema_name : Symbol, schema_symbol : Symbol, env_var : String = "DATABASE_URL") : String
      tables = inspect_tables
      tables.each { |table| check_names(table) }

      String.build do |str|
        str << "#{schema_name} = CQL::Schema.define(\n"
        str << "  :#{schema_symbol},\n"
        str << "  adapter: CQL::Adapter::#{@adapter},\n"
        str << "  uri: #{uri_expression(env_var)}) do\n"

        tables.each do |table|
          str << generate_table_definition(table)
        end

        str << "end\n"
      end
    end

    # The file gets committed, so it reads *env_var* and falls back to the URI without credentials, fragment or
    # unknown query parameters; a URI that does not parse gets no fallback, as its password cannot be told apart.
    private def uri_expression(env_var : String) : String
      if fallback = credential_free_uri(@uri)
        %(ENV.fetch(#{env_var.inspect}, #{fallback.inspect}))
      else
        %(ENV[#{env_var.inspect}])
      end
    end

    private def credential_free_uri(uri : String) : String?
      parsed = URI.parse(uri)
      parsed.password = nil
      parsed.fragment = nil
      parsed.query = parsed.query.try { |query| allowlisted_query(query) }
      parsed.to_s
    rescue URI::Error
      nil
    end

    # Keeps each kept pair as written: re-encoding would turn `%20` into `+`, which CQL's driver reads literally.
    # Splits on `;` too, as Crystal's query parsers do, so `a=1;password=x` is two pairs, not one kept one.
    private def allowlisted_query(query : String) : String?
      query.split(/[&;]/).select { |pair| fallback_param?(URI.decode(pair.partition('=').first)) }.join('&').presence
    end

    # ASCII-only folding: `downcase` would fold the Kelvin sign in `health_chec\u212A_after` to an allowlisted key.
    private def fallback_param?(key : String) : Bool
      FALLBACK_URI_PARAMS.includes?(key.downcase(Unicode::CaseOptions::ASCII))
    end

    # Inspect all tables in the database
    # - **@return** [Array(TableInfo)] Array of table information
    private def inspect_tables
      case @adapter
      when CQL::Adapter::SQLite
        inspect_sqlite_tables
      when CQL::Adapter::Postgres, CQL::Adapter::CockroachDB
        inspect_postgres_tables
      when CQL::Adapter::MySql
        inspect_mysql_tables
      else
        raise Error.new("Unsupported adapter: #{@adapter}")
      end
    end

    # SQLite table inspection. Each query finishes before the next starts, so one connection is enough.
    private def inspect_sqlite_tables
      table_names = @db.query_all("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'", as: String)
      table_names.map do |table_name|
        table_info = TableInfo.new(table_name)
        unique_columns = sqlite_unique_columns(table_name)

        # Get columns
        @db.query_each(%(SELECT name, type, "notnull", dflt_value, pk FROM pragma_table_info(?)), table_name) do |col_rs|
          column_name = col_rs.read(String)
          column_type = col_rs.read(String)
          not_null = col_rs.read(Int32) == 1
          default_value = col_rs.read(String?)
          is_primary = col_rs.read(Int32) == 1

          crystal_type = map_sql_type_to_crystal(column_type)
          column_info = ColumnInfo.new(
            name: column_name,
            type: crystal_type,
            nullable: !not_null,
            default: default_value,
            primary_key: is_primary,
            unique: unique_columns.includes?(column_name)
          )
          table_info.columns << column_info
        end

        # Get foreign keys
        @db.query_each(%(SELECT "table", "from", "to", on_update, on_delete FROM pragma_foreign_key_list(?)), table_name) do |fk_rs|
          referenced_table = fk_rs.read(String)
          local_column = fk_rs.read(String)
          referenced_column = fk_rs.read(String)
          on_update = fk_rs.read(String)
          on_delete = fk_rs.read(String)

          fk_info = ForeignKeyInfo.new(
            columns: [local_column],
            references_table: referenced_table,
            references_columns: [referenced_column],
            on_delete: on_delete.downcase.gsub(" ", "_"),
            on_update: on_update.downcase.gsub(" ", "_")
          )
          table_info.foreign_keys << fk_info
        end

        table_info
      end
    end

    # PostgreSQL table inspection. Each query finishes before the next starts, so one connection is enough.
    private def inspect_postgres_tables
      table_names = @db.query_all(<<-SQL, as: String)
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = current_schema()
        AND table_type = 'BASE TABLE'
        ORDER BY table_name
        SQL
      table_names.map do |table_name|
        table_info = TableInfo.new(table_name)
        primary_keys = @db.query_all(<<-SQL, table_name, as: String)
          SELECT kcu.column_name FROM information_schema.table_constraints tc
          JOIN information_schema.key_column_usage kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
          AND tc.table_name = kcu.table_name
          WHERE tc.table_schema = current_schema()
          AND tc.table_name = $1
          AND tc.constraint_type = 'PRIMARY KEY'
          SQL
        unique_columns = postgres_unique_columns(table_name)

        # Get columns
        @db.query_each(<<-SQL, table_name) do |col_rs|
          SELECT column_name, data_type, is_nullable, column_default, is_identity
          FROM information_schema.columns
          WHERE table_schema = current_schema() AND table_name = $1
          ORDER BY ordinal_position
          SQL
          column_name = col_rs.read(String)
          column_type = col_rs.read(String)
          nullable = col_rs.read(String) == "YES"
          default_value = col_rs.read(String?)
          identity = col_rs.read(String) == "YES"

          crystal_type = map_sql_type_to_crystal(column_type)
          column_info = ColumnInfo.new(
            name: column_name,
            type: crystal_type,
            nullable: nullable,
            default: default_value,
            primary_key: primary_keys.includes?(column_name),
            unique: unique_columns.includes?(column_name),
            sql_type: column_type == "text" ? SQLType::Text : (column_type == "timestamp with time zone" ? SQLType::Timestamptz : nil),
            auto_increment: identity || !!default_value.try(&.starts_with?("nextval("))
          )
          table_info.columns << column_info
        end

        # Get foreign keys
        @db.query_each(<<-SQL, table_name) do |fk_rs|
          SELECT
            kcu.column_name,
            ccu.table_name AS foreign_table_name,
            ccu.column_name AS foreign_column_name,
            rc.update_rule,
            rc.delete_rule
          FROM information_schema.table_constraints AS tc
          JOIN information_schema.key_column_usage AS kcu
            ON tc.constraint_name = kcu.constraint_name
            AND tc.table_schema = kcu.table_schema
          JOIN information_schema.constraint_column_usage AS ccu
            ON ccu.constraint_name = tc.constraint_name
            AND ccu.table_schema = tc.table_schema
          JOIN information_schema.referential_constraints AS rc
            ON tc.constraint_name = rc.constraint_name
            AND tc.table_schema = rc.constraint_schema
          WHERE tc.constraint_type = 'FOREIGN KEY'
          AND tc.table_schema = current_schema()
          AND tc.table_name = $1
          SQL
          local_column = fk_rs.read(String)
          referenced_table = fk_rs.read(String)
          referenced_column = fk_rs.read(String)
          on_update = fk_rs.read(String)
          on_delete = fk_rs.read(String)

          fk_info = ForeignKeyInfo.new(
            columns: [local_column],
            references_table: referenced_table,
            references_columns: [referenced_column],
            on_delete: on_delete.downcase.gsub(" ", "_"),
            on_update: on_update.downcase.gsub(" ", "_")
          )
          table_info.foreign_keys << fk_info
        end

        table_info
      end
    end

    # Columns of *table_name* that a one-column, non-partial unique index (or UNIQUE constraint) covers,
    # the primary key's excluded: the dump writes those `unique: true`.
    private def sqlite_unique_columns(table_name : String) : Array(String)
      @db.query_all(<<-SQL, table_name, as: String)
        SELECT info.name FROM pragma_index_list(?) AS list JOIN pragma_index_info(list.name) AS info
        WHERE list."unique" AND list.origin <> 'pk' AND NOT list.partial AND info.name IS NOT NULL
        AND (SELECT COUNT(*) FROM pragma_index_info(list.name)) = 1
        SQL
    end

    # :ditto:
    private def postgres_unique_columns(table_name : String) : Array(String)
      @db.query_all(<<-SQL, table_name, as: String)
        SELECT a.attname FROM pg_index i
        JOIN pg_class c ON c.oid = i.indrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = i.indkey[0]
        WHERE n.nspname = current_schema() AND c.relname = $1
        AND i.indisunique AND i.indisvalid AND NOT i.indisprimary AND i.indnatts = 1 AND i.indpred IS NULL
        SQL
    end

    # MySQL table inspection. Each query finishes before the next starts, so one connection is enough.
    private def inspect_mysql_tables
      table_names = @db.query_all("SHOW TABLES", as: String)
      table_names.map do |table_name|
        table_info = TableInfo.new(table_name)

        # Get columns
        @db.query_each("DESCRIBE #{@adapter.dialect.quote_identifier(table_name)}") do |col_rs|
          column_name = col_rs.read(String)
          column_type = col_rs.read(String)
          nullable = col_rs.read(String) == "YES"
          key = col_rs.read(String?)
          default_value = col_rs.read(String?)
          _extra = col_rs.read(String?)

          is_primary = key == "PRI"
          crystal_type = map_sql_type_to_crystal(column_type)

          column_info = ColumnInfo.new(
            name: column_name,
            type: crystal_type,
            nullable: nullable,
            default: default_value,
            primary_key: is_primary
          )
          table_info.columns << column_info
        end

        # Get foreign keys (MySQL 5.7+)
        @db.query_each(<<-SQL, table_name) do |fk_rs|
          SELECT
            COLUMN_NAME,
            REFERENCED_TABLE_NAME,
            REFERENCED_COLUMN_NAME,
            UPDATE_RULE,
            DELETE_RULE
          FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
          WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = ?
          AND REFERENCED_TABLE_NAME IS NOT NULL
          SQL
          local_column = fk_rs.read(String)
          referenced_table = fk_rs.read(String)
          referenced_column = fk_rs.read(String)
          on_update = fk_rs.read(String)
          on_delete = fk_rs.read(String)

          fk_info = ForeignKeyInfo.new(
            columns: [local_column],
            references_table: referenced_table,
            references_columns: [referenced_column],
            on_delete: on_delete.downcase.gsub(" ", "_"),
            on_update: on_update.downcase.gsub(" ", "_")
          )
          table_info.foreign_keys << fk_info
        end

        table_info
      end
    end

    # Map SQL type to Crystal type name
    private def map_sql_type_to_crystal(sql_type : String) : String
      # Normalize the SQL type (remove size specifications, etc.)
      normalized_type = sql_type.upcase.gsub(/\(\d+\)/, "").strip
      downcase_type = sql_type.downcase

      case @adapter
      when CQL::Adapter::SQLite
        case normalized_type
        when "INTEGER"          then "Int32"
        when "BIGINT"           then "Int64"
        when "INTEGER UNSIGNED" then "UInt32"
        when "BIGINT UNSIGNED"  then "UInt64"
        when "FLOAT"            then "Float32"
        when "DOUBLE"           then "Float64"
        when "TEXT", "VARCHAR"  then "String"
        when "BOOLEAN"          then "Bool"
        when "TIMESTAMP"        then "Time"
        when "DATE"             then "Date"
        when "INTERVAL"         then "Time::Span"
        when "BLOB"             then "Slice(UInt8)"
        when "JSON"             then "JSON::Any"
        else                         "String"
        end
      when CQL::Adapter::MySql
        case normalized_type
        when "INT"             then "Int32"
        when "BIGINT"          then "Int64"
        when "INT UNSIGNED"    then "UInt32"
        when "BIGINT UNSIGNED" then "UInt64"
        when "FLOAT"           then "Float32"
        when "DOUBLE"          then "Float64"
        when "VARCHAR", "TEXT" then "String"
        when "TINYINT"         then "Bool"
        when "DATETIME"        then "Time"
        when "DATE"            then "Date"
        when "TIME"            then "Time::Span"
        when "BLOB"            then "Slice(UInt8)"
        when "JSON"            then "JSON::Any"
        else                        "String"
        end
      when CQL::Adapter::Postgres, CQL::Adapter::CockroachDB
        case downcase_type
        when "integer"                                                              then "Int32"
        when "bigint"                                                               then "Int64"
        when "real"                                                                 then "Float32"
        when "double precision"                                                     then "Float64"
        when "character varying", "varchar", "text"                                 then "String"
        when "boolean"                                                              then "Bool"
        when "timestamp without time zone", "timestamp", "timestamp with time zone" then "Time"
        when "uuid"                                                                 then "UUID"
        when "date"                                                                 then "Date"
        when "interval"                                                             then "Time::Span"
        when "bytea"                                                                then "Slice(UInt8)"
        when "jsonb", "json"                                                        then "JSON::Any"
        else                                                                             "String"
        end
      else
        "String"
      end
    end

    # Map Crystal type to the correct CQL column method
    private def get_column_method(crystal_type : String) : String
      case crystal_type
      when "Int32"        then "integer"
      when "Int64"        then "bigint"
      when "UInt32"       then "integer" # No specific UInt32 method, use integer
      when "UInt64"       then "bigint"  # No specific UInt64 method, use bigint
      when "Float32"      then "float"
      when "Float64"      then "double"
      when "String"       then "text" # Use text for general strings
      when "Bool"         then "boolean"
      when "Time"         then "timestamp"
      when "Date"         then "date"
      when "Time::Span"   then "interval"
      when "Slice(UInt8)" then "blob"
      when "JSON::Any"    then "json"
      else                     "text" # Default fallback
      end
    end

    # Generate table definition code
    private def generate_table_definition(table : TableInfo) : String
      String.build do |str|
        str << "  table #{symbol(table.name)} do\n"

        primary_columns = table.columns.select(&.primary_key?)
        if primary_columns.size == 1
          pk = primary_columns.first
          str << "    primary #{symbol(pk.name)}, #{pk.type}"
          str << ", auto_increment: false" unless pk.auto_increment?
          str << ", sql_type: :#{pk.sql_type.to_s.downcase}" if pk.sql_type
          str << "\n"
        end

        has_created_at = table.columns.any? { |column| column.name == "created_at" }
        has_updated_at = table.columns.any? { |column| column.name == "updated_at" }
        timestamp_columns = table.columns.select { |column| {"created_at", "updated_at"}.includes?(column.name) }
        use_timestamps_macro = has_created_at && has_updated_at && timestamp_columns.all? { |column| column.type == "Time" && column.sql_type.nil? } && timestamp_columns.map(&.default).uniq!.size == 1

        table.columns.reject(&.primary_key?).each do |column|
          if use_timestamps_macro && (column.name == "created_at" || column.name == "updated_at")
            next
          end

          if column.type == "UUID"
            str << "    column #{symbol(column.name)}, UUID"
          else
            str << "    #{get_column_method(column.type)} #{symbol(column.name)}"
          end
          str << ", sql_type: :#{column.sql_type.to_s.downcase}" if column.sql_type
          str << ", null: true" if column.nullable?
          str << ", default: #{column.default.inspect}" if column.default
          str << ", unique: true" if column.unique?
          str << "\n"
        end

        str << "    timestamps\n" if use_timestamps_macro

        table.foreign_keys.each do |foreign_key|
          str << "    foreign_key [#{symbols(foreign_key.columns)}], "
          str << "references: #{symbol(foreign_key.references_table)}, "
          str << "references_columns: [#{symbols(foreign_key.references_columns)}]"
          str << rule_option("on_delete", foreign_key.on_delete)
          str << rule_option("on_update", foreign_key.on_update)
          str << "\n"
        end

        str << "  end\n\n"
      end
    end

    # CQL's DDL writes names unquoted, so a schema built from a dump holding any other name would run the SQL in it.
    private def check_names(table : TableInfo) : Nil
      check_name(table.name, "name", table.name)
      table.columns.each { |column| check_name(table.name, "column", column.name) }
      table.foreign_keys.each do |key|
        key.columns.each { |name| check_foreign_key_name(table.name, "foreign key column", name) }
        check_foreign_key_name(table.name, "referenced table", key.references_table)
        key.references_columns.each { |name| check_foreign_key_name(table.name, "referenced column", name) }
        {key.on_delete, key.on_update}.each { |rule| check_rule(table.name, rule) }
      end
    end

    private def check_name(table : String, kind : String, name : String) : Nil
      unless plain_name?(name)
        refuse_name(table, kind, name, "is not a plain identifier; CQL's DDL does not quote names, so building a " \
                                       "schema from it would run SQL in the name")
      end
      folded = @adapter.dialect.fold_unquoted_name(name)
      if MISREAD_NAMES.includes?(folded.downcase)
        refuse_name(table, kind, name, "is a keyword CQL's unquoted DDL reads as SQL, so the schema would build differently")
      end
      unless folded == name
        refuse_name(table, kind, name, "is folded to #{folded.dump} by the database in CQL's unquoted DDL, so it would " \
                                       "name another table or column")
      end
    end

    private def refuse_name(table : String, kind : String, name : String, reason : String) : NoReturn
      raise Error.new("Cannot dump table #{table.dump}: #{kind} #{name.dump} #{reason}. Rename it first")
    end

    # Valid UTF-8 in NFC (a decomposed name reads as its composed form), letters, digits and underscores, no filler.
    private def plain_name?(name : String) : Bool
      name.valid_encoding? && NAME_PATTERN.matches?(name) && name.unicode_normalized?(:nfc) &&
        name.each_char.none?(&.in?(INVISIBLE_LETTERS))
    end

    # The foreign key DDL validates its names with CQL::Identifier, which takes ASCII letters, digits and underscores only.
    private def check_foreign_key_name(table : String, kind : String, name : String) : Nil
      return if name.valid_encoding? && CQL::Identifier.valid?(name)
      raise Error.new("Cannot dump table #{table.dump}: #{kind} #{name.dump} is not an ASCII identifier, which " \
                      "CQL's foreign key DDL requires, so the dumped schema would not build. Rename it first")
    end

    private def check_rule(table : String, rule : String) : Nil
      return if FOREIGN_KEY_RULES.includes?(rule)
      raise Error.new("Cannot dump table #{table.inspect}: foreign key rule #{rule.inspect} is not one of #{FOREIGN_KEY_RULES.join(", ")}")
    end

    # A rule `check_names` accepted, left out for CQL's default no_action.
    private def rule_option(option : String, rule : String) : String
      rule == "no_action" ? "" : ", #{option}: :#{rule}"
    end

    # Only a `NAME_PATTERN` name gets here (`check_names`), which Crystal reads as a bare symbol.
    private def symbol(name : String) : String
      ":#{name}"
    end

    private def symbols(names : Array(String)) : String
      names.join(", ") { |name| symbol(name) }
    end

    # Close the database connection
    def close
      @db.close
    end

    # Helper method to open database connection with proper error handling
    private def open_database_connection(uri : String) : DB::Database
      DB.open(@adapter.driver_uri(uri))
    rescue ex : Exception
      raise Error.new("Failed to connect to database: #{ex.message}")
    end

    # Information about a database table
    private struct TableInfo
      property name : String
      property columns : Array(ColumnInfo) = [] of ColumnInfo
      property foreign_keys : Array(ForeignKeyInfo) = [] of ForeignKeyInfo

      def initialize(@name : String)
      end
    end

    # Information about a database column
    private struct ColumnInfo
      property name : String
      property type : String
      property? nullable : Bool
      property default : String?
      property? primary_key : Bool
      property? unique : Bool
      property sql_type : SQLType?
      property? auto_increment : Bool

      def initialize(@name : String, @type : String, @nullable : Bool = false, @default : String? = nil,
                     @primary_key : Bool = false, @unique : Bool = false, @sql_type : SQLType? = nil, @auto_increment : Bool = true)
      end
    end

    # Information about a foreign key
    private struct ForeignKeyInfo
      property columns : Array(String)
      property references_table : String
      property references_columns : Array(String)
      property on_delete : String
      property on_update : String

      def initialize(@columns : Array(String), @references_table : String, @references_columns : Array(String), @on_delete : String = "no_action", @on_update : String = "no_action")
      end
    end
  end
end
