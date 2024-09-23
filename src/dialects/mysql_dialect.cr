module Expression
  class MySQLDialect < Dialect
    def structure_dump(uri : URI) : String
      Process.new(
        "mysqldump",
        "--no-data",
        "--skip-comments",
        "--compact", "--user=#{uri.user}",
        "--password=#{uri.password}", uri.path[1..-1]).output || ""
    end

    def auto_increment_primary_key(column : CQL::BaseColumn, col_type : String) : String
      String::Builder.build do |sb|
        sb << column.name
        sb << " "
        sb << col_type
        sb << " PRIMARY KEY"
        sb << " AUTO_INCREMENT" if column.auto_increment?
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
  end
end
