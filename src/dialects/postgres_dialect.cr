module Expression
  class PostgresDialect < Dialect
    def structure_dump(uri : URI) : String
      Process.new(
        "pg_dump",
        "--no-data",
        "--no-comments",
        "--schema-only",
        "--username=#{uri.user}",
        "--dbname=#{uri.path[1..-1]}").output || ""
    end

    def auto_increment_primary_key(column : CQL::BaseColumn, col_type : String) : String
      String::Builder.build do |sb|
        sb << column.name
        sb << " "
        sb << col_type
        sb << " GENERATED"
        sb << " ALWAYS" if column.auto_increment?
        sb << " AS IDENTITY PRIMARY KEY"
      end
    end

    def rename_column(table_name : String, old_name : String, new_name : String, column_type : String?) : String
      "RENAME COLUMN #{old_name} TO #{new_name}"
    end

    def modify_column(table_name : String, column_name : String, column_type : String) : String
      "ALTER COLUMN #{column_name} TYPE #{column_type}"
    end

    def drop_index(index_name : String, table_name : String) : String
      "DROP INDEX IF EXISTS #{index_name}"
    end

    def drop_foreign_key(table_name : String, constraint_name : String) : String
      "DROP CONSTRAINT #{constraint_name}"
    end

    def rename_table(old_name : String, new_name : String) : String
      "ALTER TABLE #{old_name} RENAME TO #{new_name}"
    end
  end
end
