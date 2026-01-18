require "./dialect"

module Expression
  # PostgreSQL specific dialect implementation - optimized for performance
  class PostgresDialect < BaseDialect
    # Cache for frequently used PostgreSQL-specific strings
    @@cached_strings = {
      "postgres_placeholder_prefix" => "$",
      "postgres_drop_index_prefix"  => "DROP INDEX IF EXISTS ",
      "postgres_alter_table_prefix" => "ALTER TABLE ",
    }

    # PostgreSQL uses $1, $2, etc. for placeholders
    def placeholder_format(param_index : Int32) : String
      cached_sql("postgres_placeholder_#{param_index}") do
        "#{@@cached_strings["postgres_placeholder_prefix"]}#{param_index}"
      end
    end

    def structure_dump(uri : URI) : String
      args = [
        "--no-data",
        "--no-comments",
        "--schema-only",
        "--username=#{uri.user}",
        "--dbname=#{uri.path[1..-1]}",
      ]
      Process.new("pg_dump", args: args, output: Process::Redirect::Pipe).output.to_s
    end

    def auto_increment_primary_key(column : CQL::BaseColumn, col_type : String) : String
      build_sql(64) do |str|
        str << column.name << " " << col_type
        if column.auto_increment?
          str << " GENERATED ALWAYS AS IDENTITY PRIMARY KEY"
        else
          str << " GENERATED AS IDENTITY PRIMARY KEY"
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

    def format_returning(columns : Array(String)) : String
      return "" if columns.empty?
      " RETURNING #{columns.join(", ")}"
    end

    def format_insert_values(values : Array(Array(DB::Any)), placeholders : Array(String)) : String
      return "" if values.empty?

      build_sql(values.size * 32) do |str|
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

    # PostgreSQL supports RETURNING for both UPDATE and DELETE
    def format_update_returning(columns : Array(String)) : String
      format_returning(columns)
    end

    def format_delete_returning(columns : Array(String)) : String
      format_returning(columns)
    end

    # Override timestamp formatting for PostgreSQL-specific format
    protected def format_time(value : Time) : String
      "''#{value.to_s("%Y-%m-%d %H:%M:%S.%L")}''"
    end

    # Returns the SQL function for the current timestamp (evaluated by database)
    def current_timestamp : String
      "CURRENT_TIMESTAMP"
    end
  end
end
