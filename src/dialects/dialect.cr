module Expression
  abstract class Dialect
    # Dumps only the DB structure (no data) to a string
    # that can be executed by the database client
    abstract def structure_dump(uri : URI) : String

    abstract def auto_increment_primary_key(column : Cql::BaseColumn, col_type : String) : String

    abstract def rename_column(table_name : String, old_name : String, new_name : String, column_type : String?) : String

    abstract def modify_column(table_name : String, column_name : String, column_type : String) : String

    abstract def drop_index(index_name : String, table_name : String) : String

    abstract def drop_foreign_key(table_name : String, constraint_name : String) : String

    abstract def rename_table(old_name : String, new_name : String) : String
  end
end
