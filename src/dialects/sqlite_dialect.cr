require "./dialect"

module Expression
  # SQLite specific dialect implementation - optimized for performance
  class SqliteDialect < BaseDialect
    # Cache for frequently used SQLite-specific strings
    @@cached_strings = {
      "sqlite_placeholder"          => "?",
      "sqlite_integer_pk_autoincr"  => "INTEGER PRIMARY KEY AUTOINCREMENT",
      "sqlite_primary_key"          => " PRIMARY KEY",
      "sqlite_drop_index_prefix"    => "DROP INDEX IF EXISTS ",
      "sqlite_delete_from_prefix"   => "DELETE FROM ",
      "sqlite_rename_column_prefix" => "RENAME COLUMN ",
      "sqlite_add_column_prefix"    => "ADD COLUMN ",
    }

    # SQLite uses ? for all placeholders regardless of position
    def placeholder_format(param_index : Int32) : String
      @@cached_strings["sqlite_placeholder"]
    end

    def structure_dump(uri : URI) : String
      ""
    end

    def auto_increment_primary_key(column : CQL::BaseColumn, col_type : String) : String
      # SQLite AUTOINCREMENT requires the type to be INTEGER.
      if pk_col = column.as?(CQL::PrimaryKey)
        if pk_col.auto_increment?
          "#{column.name} #{@@cached_strings["sqlite_integer_pk_autoincr"]}"
        else
          # Not auto-incrementing, use the determined type (e.g., BIGINT)
          "#{column.name} #{col_type}#{@@cached_strings["sqlite_primary_key"]}"
        end
      else
        # Fallback if not a PrimaryKey somehow (shouldn't happen via generator)
        "#{column.name} #{col_type}#{@@cached_strings["sqlite_primary_key"]}"
      end
    end

    # SQLite-specific implementations that differ from base
    def rename_column(table_name : String, old_name : String, new_name : String, column_type : String?) : String
      "#{@@cached_strings["sqlite_rename_column_prefix"]}#{old_name} TO #{new_name}"
    end

    def modify_column(table_name : String, column_name : String, column_type : String) : String
      workaround = <<-MSG
      Here's how you can change the data type of a column in SQLite:

        1. Create a new table with the desired schema.
        2. Copy data from the old table to the new table.
        3. Drop the old table.
        4. Rename the new table to the original table name.
      MSG

      raise CQL::SQLiteUnsupportedFeatureError.new("ALTER COLUMN syntax", workaround)
    end

    def drop_index(index_name : String, table_name : String) : String
      "#{@@cached_strings["sqlite_drop_index_prefix"]}#{index_name}"
    end

    def drop_foreign_key(table_name : String, constraint_name : String) : String
      workaround = <<-MSG
      Here is an example workflow:

        1. Create a new table without the foreign key.
        2. Copy data from the old table to the new table.
        3. Drop the old table.
        4. Rename the new table to the old table name.
      MSG

      raise CQL::SQLiteUnsupportedFeatureError.new("dropping foreign keys", workaround)
    end

    def rename_table(old_name : String, new_name : String) : String
      "ALTER TABLE #{old_name} RENAME TO #{new_name}"
    end

    # Table operations using cached strings
    def truncate_table(table_name : String) : String
      # SQLite doesn't have TRUNCATE, so we use DELETE FROM
      "#{@@cached_strings["sqlite_delete_from_prefix"]}#{table_name}"
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
      # SQLite doesn't support adding a PRIMARY KEY constraint to an existing table
      if primary_key
        raise CQL::SQLiteUnsupportedFeatureError.new("adding a PRIMARY KEY constraint to an existing table")
      end

      build_sql(64) do |str|
        str << "#{@@cached_strings["sqlite_add_column_prefix"]}#{column_name} #{column_type}"
        str << " NOT NULL" unless nullable
        str << " UNIQUE" if unique
      end
    end

    def drop_column(column_name : String) : String
      # SQLite prior to version 3.35.0 doesn't support DROP COLUMN directly
      # For compatibility, we return the standard syntax but include a warning
      # The workaround would be:
      #   1. Create a new table without the column.
      #   2. Copy data from the old table to the new table.
      #   3. Drop the old table.
      #   4. Rename the new table to the original table name.

      # We'll return the standard syntax for newer SQLite versions
      # but include a warning in the comment
      "DROP COLUMN #{column_name} /* Warning: Only works on SQLite 3.35.0+ */"
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
      # SQLite doesn't support adding foreign keys to existing tables
      workaround = <<-MSG
      Here is an example workflow:

        1. Create the new table with the foreign key.
        2. Copy data from the old table to the new table.
        3. Drop the old table.
        4. Rename the new table to the old table name.
      MSG
      raise CQL::SQLiteUnsupportedFeatureError.new("adding foreign keys to an existing table", workaround)
    end

    def define_foreign_key(fk : CQL::ForeignKey) : String
      on_delete = fk.on_delete.to_s.upcase.gsub("_", " ")
      on_update = fk.on_update.to_s.upcase.gsub("_", " ")

      build_sql(256) do |str|
        str << "CONSTRAINT #{fk.name} " if fk.name
        str << "FOREIGN KEY (" << fk.columns.join(", ") << ")"
        str << " REFERENCES " << fk.references_table
        str << " (" << fk.references_columns.join(", ") << ")"
        str << " ON DELETE " << on_delete
        str << " ON UPDATE " << on_update
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
      # SQLite doesn't support RETURNING clause before version 3.35.0
      if !columns.empty?
        # Only raise if columns are actually requested
        workaround = "Use a separate SELECT query after your operation to retrieve the data."
        raise CQL::SQLiteUnsupportedFeatureError.new("RETURNING clause (before SQLite 3.35.0)", workaround)
      end
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
      # SQLite doesn't support RETURNING clause before version 3.35.0
      if !columns.empty?
        # Only raise if columns are actually requested
        workaround = "Use a separate SELECT query after your UPDATE to retrieve the data."
        raise CQL::SQLiteUnsupportedFeatureError.new("UPDATE with RETURNING clause (before SQLite 3.35.0)", workaround)
      end
      ""
    end

    def format_delete_returning(columns : Array(String)) : String
      # SQLite doesn't support RETURNING clause before version 3.35.0
      if !columns.empty?
        # Only raise if columns are actually requested
        workaround = "Use a separate SELECT query before your DELETE to retrieve the data that will be deleted."
        raise CQL::SQLiteUnsupportedFeatureError.new("DELETE with RETURNING clause (before SQLite 3.35.0)", workaround)
      end
      ""
    end

    # Override boolean formatting for SQLite-specific format
    protected def format_boolean(value : Bool) : String
      # SQLite uses 1 and 0 for boolean values
      value ? "1" : "0"
    end

    # Override time formatting for SQLite-specific format
    protected def format_time(value : Time) : String
      # Format time values as ISO8601 strings with SQLite-style escaping
      "''#{value.to_s("%Y-%m-%d %H:%M:%S.%L")}''"
    end

    # Returns the SQL function name for the current timestamp
    def current_timestamp : String
      Time.local.to_s("%Y-%m-%d %H:%M:%S.%L")
    end

    # SQLite uses last_insert_rowid() to get the last inserted ID
    def last_insert_id_query : String?
      "SELECT last_insert_rowid()"
    end
  end
end
