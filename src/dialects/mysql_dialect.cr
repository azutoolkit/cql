module Expression
  # MySQL specific dialect implementation.
  class MySqlDialect < BaseDialect
    # MySQL uses ? for all placeholders regardless of position
    def placeholder_format(param_index : Int32) : String
      "?"
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
      String.build do |string|
        string << column.name
        string << " "
        string << col_type
        string << " PRIMARY KEY"
        string << " AUTO_INCREMENT" if column.auto_increment?
      end
    end

    def rename_column(table_name : String, old_name : String, new_name : String, column_type : String?) : String
      "CHANGE #{old_name} #{new_name} #{column_type.not_nil!}"
    end

    def modify_column(table_name : String, column_name : String, column_type : String) : String
      "MODIFY COLUMN #{column_name} #{column_type}"
    end

    def drop_index(index_name : String, table_name : String) : String
      "DROP INDEX #{index_name} ON #{table_name}"
    end

    def drop_foreign_key(table_name : String, constraint_name : String) : String
      "DROP FOREIGN KEY #{constraint_name}"
    end

    def rename_table(old_name : String, new_name : String) : String
      "RENAME TABLE #{old_name} TO #{new_name}"
    end

    # Table operations
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
            # MySQL uses TRUE and FALSE for boolean values
            string << (default_value ? "TRUE" : "FALSE")
          when Time
            # Format time values as MySQL datetime strings
            string << "'" << default_value.to_s("'%Y-%m-%d %H:%M:%S'") << "'"
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
      String.build do |string|
        string << "ADD COLUMN "
        string << column_name
        string << " " << column_type
        string << " PRIMARY KEY" if primary_key
        string << " NOT NULL" unless nullable
        string << " UNIQUE" if unique
      end
    end

    def drop_column(column_name : String) : String
      "DROP COLUMN #{column_name}"
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
      String.build do |string|
        string << "ADD CONSTRAINT "
        string << constraint_name
        string << " FOREIGN KEY ("
        string << columns.join(", ")
        string << ") REFERENCES "
        string << references_table
        string << " ("
        string << references_columns.join(", ")
        string << ") ON DELETE " << on_delete
        string << " ON UPDATE " << on_update
      end
    end

    def define_foreign_key(fk : CQL::ForeignKey) : String
      constraint_name = fk.name || "fk_#{fk.table.table_name}_#{fk.columns.join("_")}"
      String.build do |string|
        string << "CONSTRAINT #{constraint_name}"
        string << " FOREIGN KEY (" << fk.columns.map(&.to_s).join(", ") << ")"
        string << " REFERENCES " << fk.references_table.to_s
        string << " (" << fk.references_columns.map(&.to_s).join(", ") << ")"
        string << " ON DELETE " << fk.on_delete.to_s.upcase.gsub("_", " ")
        string << " ON UPDATE " << fk.on_update.to_s.upcase.gsub("_", " ")
      end
    end

    # Defines a unique constraint.
    def define_unique_constraint(constraint : CQL::UniqueConstraint) : String
      parts = [] of String
      parts << "CONSTRAINT #{constraint.name}" if constraint.name
      parts << "UNIQUE (#{constraint.columns.join(", ")})"
      parts.join(" ")
    end

    # Defines a check constraint.
    # MySQL does not support CHECK constraints in a way that's compatible with other DBs before 8.0.16.
    # While newer versions do, raising an error ensures compatibility or forces explicit handling.
    def define_check_constraint(constraint : CQL::CheckConstraint) : String
      raise CQL::MySqlUnsupportedFeatureError.new("CHECK constraints (Note: Supported in MySQL >= 8.0.16, but CQL avoids for broader compatibility)")
    end

    # Query components
    def format_limit_offset(limit : DB::Any, offset : DB::Any?) : String
      String.build do |string|
        string << " LIMIT #{limit}"
        string << " OFFSET #{offset}" if offset
      end
    end

    def format_returning(columns : Array(String)) : String
      # MySQL doesn't support RETURNING clause in versions before 8.0.21
      # For compatibility, we return an empty string
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
      # MySQL doesn't support RETURNING clause in versions before 8.0.21
      ""
    end

    def format_delete_returning(columns : Array(String)) : String
      # MySQL doesn't support RETURNING clause in versions before 8.0.21
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
