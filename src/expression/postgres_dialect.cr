module Expression
  class PostgresDialect < Dialect
    def rename_column(table_name : String, old_name : String, new_name : String, column_type : String?) : String
      "ALTER TABLE #{table_name} RENAME COLUMN #{old_name} TO #{new_name}"
    end

    def modify_column(table_name : String, column_name : String, column_type : String) : String
      "ALTER TABLE #{table_name} ALTER COLUMN #{column_name} TYPE #{column_type}"
    end

    def drop_index(index_name : String, table_name : String) : String
      "DROP INDEX #{index_name}"
    end

    def remove_constraint(table_name : String, constraint_name : String) : String
      "ALTER TABLE #{table_name} DROP CONSTRAINT #{constraint_name}"
    end
  end
end
