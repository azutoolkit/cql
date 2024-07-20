module Expression
  class SqliteDialect < Dialect
    def rename_column(table_name : String, old_name : String, new_name : String, column_type : String?) : String
      "RENAME COLUMN #{old_name} TO #{new_name}"
    end

    def modify_column(table_name : String, column_name : String, column_type : String) : String
      message = <<-MSG
      SQLite does not support the ALTER COLUMN syntax directly. Instead,
      you need to follow a series of steps to achieve the same result.

      Here’s how you can change the data type of a column in SQLite:

        1. Create a new table with the desired schema.
        2. Copy data from the old table to the new table.
        3. Drop the old table.
        4. Rename the new table to the original table name.
      MSG

      raise DB::Error.new message
    end

    def drop_index(index_name : String, table_name : String) : String
      "DROP INDEX IF EXISTS #{index_name}"
    end

    def remove_constraint(table_name : String, constraint_name : String) : String
      "DROP CONSTRAINT #{constraint_name}"
    end

    def rename_table(old_name : String, new_name : String) : String
      "ALTER TABLE #{old_name} RENAME TO #{new_name}"
    end
  end
end
