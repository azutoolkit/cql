module Expression
  abstract class Dialect
    abstract def rename_column(table_name : String, old_name : String, new_name : String, column_type : String?) : String

    abstract def modify_column(table_name : String, column_name : String, column_type : String) : String

    abstract def drop_index(index_name : String, table_name : String) : String

    abstract def remove_constraint(table_name : String, constraint_name : String) : String

    abstract def rename_table(old_name : String, new_name : String) : String
  end
end
