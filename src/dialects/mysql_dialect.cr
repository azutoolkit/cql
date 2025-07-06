require "./dialect"

module Expression
  # MySQL specific dialect implementation - optimized for performance
  class MySqlDialect < BaseDialect
    # Cache for frequently used MySQL-specific strings
    @@cached_strings = {
      "mysql_placeholder"       => "?",
      "mysql_auto_increment"    => " AUTO_INCREMENT",
      "mysql_drop_index_prefix" => "DROP INDEX ",
      "mysql_on_suffix"         => " ON ",
      "mysql_change_prefix"     => "CHANGE ",
      "mysql_modify_prefix"     => "MODIFY COLUMN ",
    }

    # MySQL uses ? for all placeholders regardless of position
    def placeholder_format(param_index : Int32) : String
      @@cached_strings["mysql_placeholder"]
    end

    def structure_dump(uri : URI) : String
      args = [
        "--no-data",
        "--skip-comments",
        "--compact",
        "--user=#{uri.user}",
        "--password=#{uri.password}",
        uri.path[1..-1],
      ]
      Process.new("mysqldump", args: args, output: Process::Redirect::Pipe).output.to_s
    end

    def auto_increment_primary_key(column : CQL::BaseColumn, col_type : String) : String
      build_sql(64) do |str|
        str << column.name << " " << col_type << " PRIMARY KEY"
        str << @@cached_strings["mysql_auto_increment"] if column.auto_increment?
      end
    end

    # MySQL-specific implementations that differ from base
    def rename_column(table_name : String, old_name : String, new_name : String, column_type : String?) : String
      "#{@@cached_strings["mysql_change_prefix"]}#{old_name} #{new_name} #{column_type.not_nil!}"
    end

    def modify_column(table_name : String, column_name : String, column_type : String) : String
      "#{@@cached_strings["mysql_modify_prefix"]}#{column_name} #{column_type}"
    end

    def drop_index(index_name : String, table_name : String) : String
      "#{@@cached_strings["mysql_drop_index_prefix"]}#{index_name}#{@@cached_strings["mysql_on_suffix"]}#{table_name}"
    end

    def drop_foreign_key(table_name : String, constraint_name : String) : String
      "DROP FOREIGN KEY #{constraint_name}"
    end

    def rename_table(old_name : String, new_name : String) : String
      "RENAME TABLE #{old_name} TO #{new_name}"
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
      "ALTER TABLE #{table_name} #{action}"
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
      build_column_definition(column_name, column_type, default_value, nullable, unique)
    end

    def add_column(
      column_name : String,
      column_type : String,
      primary_key : Bool,
      nullable : Bool,
      unique : Bool,
    ) : String
      build_sql(64) do |str|
        str << "ADD COLUMN " << column_name << " " << column_type
        str << " PRIMARY KEY" if primary_key
        str << " NOT NULL" unless nullable
        str << " UNIQUE" if unique
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
      constraint_name = fk.name || "fk_#{fk.table.table_name}_#{fk.columns.join("_")}"
      on_delete = fk.on_delete.to_s.upcase.gsub("_", " ")
      on_update = fk.on_update.to_s.upcase.gsub("_", " ")

      build_sql(256) do |str|
        str << "CONSTRAINT #{constraint_name}"
        str << " FOREIGN KEY (" << fk.columns.map(&.to_s).join(", ") << ")"
        str << " REFERENCES " << fk.references_table.to_s
        str << " (" << fk.references_columns.map(&.to_s).join(", ") << ")"
        str << " ON DELETE " << on_delete
        str << " ON UPDATE " << on_update
      end
    end

    # MySQL-specific constraint handling
    def define_check_constraint(constraint : CQL::CheckConstraint) : String
      raise CQL::MySqlUnsupportedFeatureError.new("CHECK constraints (Note: Supported in MySQL >= 8.0.16, but CQL avoids for broader compatibility)")
    end

    # Query components - optimized implementations
    def format_limit_offset(limit : DB::Any, offset : DB::Any?) : String
      if offset
        " LIMIT #{limit} OFFSET #{offset}"
      else
        " LIMIT #{limit}"
      end
    end

    # MySQL doesn't support RETURNING clause in versions before 8.0.21
    def format_returning(columns : Array(String)) : String
      ""
    end

    def format_insert_values(values : Array(Array(DB::Any)), placeholders : Array(String)) : String
      return "" if values.empty?

      build_sql(values.size * 16) do |str|
        str << " VALUES "
        values.each_with_index do |row, i|
          str << "("
          row.size.times do |j|
            str << placeholders[j]
            str << ", " if j < row.size - 1
          end
          str << ")"
          str << ", " if i < values.size - 1
        end
      end
    end

    def format_update_returning(columns : Array(String)) : String
      ""
    end

    def format_delete_returning(columns : Array(String)) : String
      ""
    end

    # Override time formatting for MySQL-specific format
    protected def format_time(value : Time) : String
      "''#{value.to_s("%Y-%m-%d %H:%M:%S")}''"
    end

    # Returns the SQL function name for the current timestamp
    def current_timestamp : String
      Time.local.to_s("%Y-%m-%d %H:%M:%S.%L")
    end

    # MySQL uses LAST_INSERT_ID() to get the last inserted ID
    def last_insert_id_query : String?
      "SELECT LAST_INSERT_ID()"
    end
  end
end
