module Expression
  abstract class Dialect
    def rename_column(table_name : String, old_name : String, new_name : String, column_type : String?) : String
      raise "Not implemented"
    end

    def modify_column(table_name : String, column_name : String, column_type : String) : String
      raise "Not implemented"
    end

    def drop_index(index_name : String, table_name : String) : String
      raise "Not implemented"
    end

    def remove_constraint(table_name : String, constraint_name : String) : String
      raise "Not implemented"
    end
  end
end
