module Expression
  class MysqlDialect < Dialect
    def rename_column(table_name : String, old_name : String, new_name : String, column_type : String?) : String
      "CHANGE #{old_name} #{new_name} #{column_type.not_nil!}"
    end

    def modify_column(table_name : String, column_name : String, column_type : String) : String
      "MODIFY COLUMN #{column_name} #{column_type}"
    end

    def drop_index(index_name : String, table_name : String) : String
      "DROP INDEX #{index_name} ON #{table_name}"
    end

    def remove_constraint(table_name : String, constraint_name : String) : String
      "DROP FOREIGN KEY #{constraint_name}"
    end
  end
end
