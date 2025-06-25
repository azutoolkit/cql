require "./dialect"

module Expression
  # SQLite specific dialect implementation.
  class SqliteDialect < BaseDialect
    # SQLite uses ? for all placeholders regardless of position
    def placeholder_format(param_index : Int32) : String
      "?"
    end

    def structure_dump(uri : URI) : String
      ""
    end

    def auto_increment_primary_key(column : CQL::BaseColumn, col_type : String) : String
      # SQLite AUTOINCREMENT requires the type to be INTEGER.
      # We must check the column's auto_increment? flag.
      if pk_col = column.as?(CQL::PrimaryKey)
        if pk_col.auto_increment?
          "#{column.name} INTEGER PRIMARY KEY AUTOINCREMENT"
        else
          # Not auto-incrementing, use the determined type (e.g., BIGINT)
          "#{column.name} #{col_type} PRIMARY KEY"
        end
      else
        # Fallback if not a PrimaryKey somehow (shouldn't happen via generator)
        "#{column.name} #{col_type} PRIMARY KEY"
      end
    end

    def rename_column(table_name : String, old_name : String, new_name : String, column_type : String?) : String
      "RENAME COLUMN #{old_name} TO #{new_name}"
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
      "DROP INDEX IF EXISTS #{index_name}"
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

    # Table operations
    def truncate_table(table_name : String) : String
      # SQLite doesn't have TRUNCATE, so we use DELETE FROM
      "DELETE FROM #{table_name}"
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

    # Column operations
    def define_column(
      column_name : String,
      column_type : String,
      default_value : DB::Any?,
      nullable : Bool,
      unique : Bool,
      timestamp_column : Bool,
    ) : String
      String.build do |string|
        string << column_name
        string << " " << column_type
        if default_value != nil
          string << " DEFAULT "
          case default_value
          when String
            # Quote string values
            string << "'" << default_value.to_s.gsub("'", "''") << "'"
          when Bool
            # SQLite uses 1 and 0 for boolean values
            string << (default_value ? "1" : "0")
          when Time
            # Format time values as ISO8601 strings with SQLite-style escaping
            string << "''" << default_value.to_s("%Y-%m-%d %H:%M:%S.%L") << "''"
          when Nil
            string << "NULL"
          else
            # Numbers and other types can be used as-is
            string << default_value.to_s
          end
        end
        string << " NOT NULL" unless nullable
        string << " UNIQUE" if unique
      end
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

      String.build do |string|
        string << "ADD COLUMN "
        string << column_name
        string << " " << column_type
        string << " NOT NULL" unless nullable
        string << " UNIQUE" if unique
      end
    end

    def drop_column(column_name : String) : String
      # SQLite prior to version 3.35.0 doesn't support DROP COLUMN directly
      # For compatibility, we should raise an error and suggest the workaround
      <<-MSG
      You need to follow these steps:

        1. Create a new table without the column.
        2. Copy data from the old table to the new table.
        3. Drop the old table.
        4. Rename the new table to the original table name.
      MSG

      # We'll return the standard syntax for newer SQLite versions
      # but include a warning in the comment
      "DROP COLUMN #{column_name} /* Warning: Only works on SQLite 3.35.0+ */"
    end

    # Index operations
    def create_index(
      index_name : String,
      table_name : String,
      columns : Array(String),
      unique : Bool,
    ) : String
      String.build do |string|
        string << "CREATE "
        string << "UNIQUE " if unique
        string << "INDEX "
        string << index_name
        string << " ON "
        string << table_name
        string << " ("
        string << columns.join(", ")
        string << ")"
      end
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
      parts = [] of String
      parts << "CONSTRAINT #{fk.name}" if fk.name
      parts << "FOREIGN KEY (#{fk.columns.join(", ")})"
      parts << "REFERENCES #{fk.references_table} (#{fk.references_columns.join(", ")})"
      parts << "ON DELETE #{fk.on_delete.to_s.upcase.gsub("_", " ")}"
      parts << "ON UPDATE #{fk.on_update.to_s.upcase.gsub("_", " ")}"
      parts.join(" ")
    end

    # Defines a unique constraint.
    def define_unique_constraint(constraint : CQL::UniqueConstraint) : String
      parts = [] of String
      parts << "CONSTRAINT #{constraint.name}" if constraint.name
      parts << "UNIQUE (#{constraint.columns.join(", ")})"
      parts.join(" ")
    end

    # Defines a check constraint.
    def define_check_constraint(constraint : CQL::CheckConstraint) : String
      parts = [] of String
      parts << "CONSTRAINT #{constraint.name}" if constraint.name
      parts << "CHECK (#{constraint.condition})"
      parts.join(" ")
    end

    # Query components
    def format_limit_offset(limit : DB::Any, offset : DB::Any?) : String
      String.build do |string|
        string << " LIMIT #{limit}"
        string << " OFFSET #{offset}" if offset
      end
    end

    def format_returning(columns : Array(String)) : String
      # SQLite doesn't support RETURNING clause before version 3.35.0
      # For compatibility with newer versions, we'll check if columns are provided
      if !columns.empty?
        # Only raise if columns are actually requested
        workaround = "Use a separate SELECT query after your operation to retrieve the data."
        raise CQL::SQLiteUnsupportedFeatureError.new("RETURNING clause (before SQLite 3.35.0)", workaround)
      end
      ""
    end

    def format_insert_values(values : Array(Array(DB::Any)), placeholders : Array(String)) : String
      String.build do |string|
        string << " VALUES "
        values.each_with_index do |row, i|
          string << "("
          row.size.times do |j|
            string << placeholders[j]
            string << ", " if j < row.size - 1
          end
          string << ")"
          string << ", " if i < values.size - 1
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

    # Conditions and operators
    def format_like(column : String, placeholder : String) : String
      "#{column} LIKE #{placeholder}"
    end

    def format_not_like(column : String, placeholder : String) : String
      "#{column} NOT LIKE #{placeholder}"
    end

    def format_is_null(column : String) : String
      "#{column} IS NULL"
    end

    def format_is_not_null(column : String) : String
      "#{column} IS NOT NULL"
    end

    # Aggregate functions
    def format_count(column : String) : String
      "COUNT(#{column})"
    end

    def format_max(column : String) : String
      "MAX(#{column})"
    end

    def format_min(column : String) : String
      "MIN(#{column})"
    end

    def format_avg(column : String) : String
      "AVG(#{column})"
    end

    def format_sum(column : String) : String
      "SUM(#{column})"
    end

    # Returns the SQL function name for the current timestamp used in default values.
    def current_timestamp : String
      Time.local.to_s("%Y-%m-%d %H:%M:%S.%L")
    end
  end
end
