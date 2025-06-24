require "db"
require "json"
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
    Log = ::Log.for(self)

    class Error < Exception; end

    getter adapter : Adapter
    getter uri : String
    private getter db : DB::Database

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
    def dump_to_file(file_path : String, schema_name : Symbol, schema_symbol : Symbol = :schema)
      schema_content = generate_schema_content(schema_name, schema_symbol)

      Dir.mkdir_p(File.dirname(file_path))
      File.write(file_path, schema_content)
      Log.info { "Schema dumped to #{file_path}" }
    end

    # Generate the schema content as a string
    # - **@param** schema_name [Symbol] Name for the schema constant
    # - **@param** schema_symbol [Symbol] Symbol name for the schema
    # - **@return** [String] The generated schema content
    def generate_schema_content(schema_name : Symbol, schema_symbol : Symbol) : String
      tables = inspect_tables

      content = String.build do |str|
        str << "#{schema_name} = CQL::Schema.define(\n"
        str << "  :#{schema_symbol},\n"
        str << "  adapter: CQL::Adapter::#{@adapter},\n"
        str << "  uri: \"#{@uri}\") do\n"

        tables.each do |table|
          str << generate_table_definition(table)
        end

        str << "end\n"
      end

      content
    end

    # Inspect all tables in the database
    # - **@return** [Array(TableInfo)] Array of table information
    private def inspect_tables
      case @adapter
      when CQL::Adapter::SQLite
        inspect_sqlite_tables
      when CQL::Adapter::Postgres
        inspect_postgres_tables
      when CQL::Adapter::MySql
        inspect_mysql_tables
      else
        raise Error.new("Unsupported adapter: #{@adapter}")
      end
    end

    # SQLite table inspection
    private def inspect_sqlite_tables
      tables = [] of TableInfo

      @db.query_each("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'") do |record_set|
        table_name = record_set.read(String)
        table_info = TableInfo.new(table_name)

        # Get columns
        @db.query_each("PRAGMA table_info(#{table_name})") do |col_rs|
          col_rs.read(Int32) # cid
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
            primary_key: is_primary
          )
          table_info.columns << column_info
        end

        # Get foreign keys
        @db.query_each("PRAGMA foreign_key_list(#{table_name})") do |fk_rs|
          fk_rs.read(Int32) # id
          fk_rs.read(Int32) # seq
          referenced_table = fk_rs.read(String)
          local_column = fk_rs.read(String)
          referenced_column = fk_rs.read(String)
          on_update = fk_rs.read(String)
          on_delete = fk_rs.read(String)
          _match = fk_rs.read(String)

          fk_info = ForeignKeyInfo.new(
            columns: [local_column],
            references_table: referenced_table,
            references_columns: [referenced_column],
            on_delete: on_delete.downcase,
            on_update: on_update.downcase
          )
          table_info.foreign_keys << fk_info
        end

        tables << table_info
      end

      tables
    end

    # PostgreSQL table inspection
    private def inspect_postgres_tables
      tables = [] of TableInfo

      # Get all tables
      @db.query_each(<<-SQL) do |record_set|
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_type = 'BASE TABLE'
        ORDER BY table_name
        SQL
        table_name = record_set.read(String)
        table_info = TableInfo.new(table_name)

        # Get columns
        @db.query_each(<<-SQL, table_name) do |col_rs|
          SELECT column_name, data_type, is_nullable, column_default
          FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = $1
          ORDER BY ordinal_position
          SQL
          column_name = col_rs.read(String)
          column_type = col_rs.read(String)
          nullable = col_rs.read(String) == "YES"
          default_value = col_rs.read(String?)

          # Check if it's a primary key
          is_primary = false
          @db.query_each(<<-SQL, table_name, column_name) do |_|
            SELECT 1 FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
            ON tc.constraint_name = kcu.constraint_name
            WHERE tc.table_schema = 'public'
            AND tc.table_name = $1
            AND kcu.column_name = $2
            AND tc.constraint_type = 'PRIMARY KEY'
            SQL
            is_primary = true
          end

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
          AND tc.table_schema = 'public'
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

        tables << table_info
      end

      tables
    end

    # MySQL table inspection
    private def inspect_mysql_tables
      tables = [] of TableInfo

      @db.query_each("SHOW TABLES") do |record_set|
        table_name = record_set.read(String)
        table_info = TableInfo.new(table_name)

        # Get columns
        @db.query_each("DESCRIBE #{table_name}") do |col_rs|
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

        tables << table_info
      end

      tables
    end

    # Map SQL type to Crystal type name
    private def map_sql_type_to_crystal(sql_type : String) : String
      # Normalize the SQL type (remove size specifications, etc.)
      normalized_type = sql_type.upcase.gsub(/\(\d+\)/, "").strip
      downcase_type = sql_type.downcase

      case @adapter
      when CQL::Adapter::SQLite
        case normalized_type
        when "INTEGER"           then "Int32"
        when "BIGINT"            then "Int64"
        when "INTEGER UNSIGNED"  then "UInt32"
        when "BIGINT UNSIGNED"   then "UInt64"
        when "FLOAT"             then "Float32"
        when "DOUBLE"            then "Float64"
        when "TEXT", "VARCHAR"   then "String"
        when "BOOLEAN"           then "Bool"
        when "TIMESTAMP", "DATE" then "Time"
        when "INTERVAL"          then "Time::Span"
        when "BLOB"              then "Slice(UInt8)"
        when "JSON"              then "JSON::Any"
        else                          "String"
        end
      when CQL::Adapter::MySql
        case normalized_type
        when "INT"              then "Int32"
        when "BIGINT"           then "Int64"
        when "INT UNSIGNED"     then "UInt32"
        when "BIGINT UNSIGNED"  then "UInt64"
        when "FLOAT"            then "Float32"
        when "DOUBLE"           then "Float64"
        when "VARCHAR", "TEXT"  then "String"
        when "TINYINT"          then "Bool"
        when "DATETIME", "DATE" then "Time"
        when "TIME"             then "Time::Span"
        when "BLOB"             then "Slice(UInt8)"
        when "JSON"             then "JSON::Any"
        else                         "String"
        end
      when CQL::Adapter::Postgres
        case downcase_type
        when "integer"                                          then "Int32"
        when "bigint"                                           then "Int64"
        when "real"                                             then "Float32"
        when "double precision"                                 then "Float64"
        when "character varying", "varchar", "text"             then "String"
        when "boolean"                                          then "Bool"
        when "timestamp without time zone", "timestamp", "date" then "Time"
        when "interval"                                         then "Time::Span"
        when "bytea"                                            then "Slice(UInt8)"
        when "jsonb", "json"                                    then "JSON::Any"
        else                                                         "String"
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
      when "Time::Span"   then "interval"
      when "Slice(UInt8)" then "blob"
      when "JSON::Any"    then "json"
      else                     "text" # Default fallback
      end
    end

    # Generate table definition code
    private def generate_table_definition(table : TableInfo) : String
      content = String.build do |str|
        str << "  table :#{table.name} do\n"

        # Primary key
        primary_columns = table.columns.select(&.primary_key?)
        if primary_columns.size == 1
          pk = primary_columns.first
          str << "    primary :#{pk.name}, #{pk.type}\n"
        end

        # Check if we should use timestamps macro
        has_created_at = table.columns.any? { |column| column.name == "created_at" }
        has_updated_at = table.columns.any? { |column| column.name == "updated_at" }
        use_timestamps_macro = has_created_at && has_updated_at

        # Regular columns (excluding timestamp columns if using timestamps macro)
        table.columns.reject(&.primary_key?).each do |column|
          # Skip timestamp columns if we're using the timestamps macro
          if use_timestamps_macro && (column.name == "created_at" || column.name == "updated_at")
            next
          end

          str << "    #{get_column_method(column.type)} :#{column.name}"
          str << ", null: true" if column.nullable?
          str << ", default: #{column.default.inspect}" if column.default
          str << "\n"
        end

        # Add timestamps macro if both created_at and updated_at exist
        if use_timestamps_macro
          str << "    timestamps\n"
        end

        # Foreign keys
        table.foreign_keys.each do |foreign_key|
          str << "    foreign_key [:#{foreign_key.columns.join(", :")}], "
          str << "references: :#{foreign_key.references_table}, "
          str << "references_columns: [:#{foreign_key.references_columns.join(", :")}]"
          str << ", on_delete: :#{foreign_key.on_delete}" if foreign_key.on_delete != "no_action"
          str << ", on_update: :#{foreign_key.on_update}" if foreign_key.on_update != "no_action"
          str << "\n"
        end

        str << "  end\n\n"
      end

      content
    end

    # Close the database connection
    def close
      @db.close
    end

    # Helper method to open database connection with proper error handling
    private def open_database_connection(uri : String) : DB::Database
      DB.open(uri)
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

      def initialize(@name : String, @type : String, @nullable : Bool = false, @default : String? = nil, @primary_key : Bool = false)
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
