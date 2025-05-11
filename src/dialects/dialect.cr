require "../constraint"

module Expression
  # Handles general dialect-specific functionalities like placeholders and structure dumps.
  module GeneralDialect
    # Formats a placeholder for prepared statements based on the dialect's syntax
    # and the parameter index
    abstract def placeholder_format(param_index : Int32) : String

    # Dumps only the DB structure (no data) to a string
    # that can be executed by the database client
    abstract def structure_dump(uri : URI) : String

    # Generates the SQL fragment for defining an auto-incrementing primary key.
    abstract def auto_increment_primary_key(column : CQL::BaseColumn, col_type : String) : String

    # Returns the SQL function name for the current timestamp used in default values.
    abstract def current_timestamp : String
  end

  # Handles Data Definition Language (DDL) operations like creating/altering tables and columns.
  module DdlDialect
    # Generates SQL to rename a column.
    abstract def rename_column(table_name : String, old_name : String, new_name : String, column_type : String?) : String

    # Generates SQL to modify a column's type.
    abstract def modify_column(table_name : String, column_name : String, column_type : String) : String

    # Generates SQL to drop an index.
    abstract def drop_index(index_name : String, table_name : String) : String

    # Generates SQL to drop a foreign key constraint.
    abstract def drop_foreign_key(table_name : String, constraint_name : String) : String

    # Generates SQL to rename a table.
    abstract def rename_table(old_name : String, new_name : String) : String

    # Generates SQL to truncate a table.
    abstract def truncate_table(table_name : String) : String

    # Generates the prefix for a CREATE TABLE statement.
    abstract def create_table_prefix(table_name : String) : String

    # Generates SQL to drop a table.
    abstract def drop_table(table_name : String) : String

    # Generates SQL to alter a table with a specific action.
    abstract def alter_table(table_name : String, action : String) : String

    # Generates SQL fragment for defining a column within a CREATE TABLE or ALTER TABLE statement.
    abstract def define_column(
      column_name : String,
      column_type : String,
      default_value : DB::Any?,
      nullable : Bool,
      unique : Bool,
      timestamp_column : Bool,
    ) : String

    # Generates SQL to add a column to a table.
    abstract def add_column(
      column_name : String,
      column_type : String,
      primary_key : Bool,
      nullable : Bool,
      unique : Bool,
    ) : String

    # Generates SQL to drop a column from a table.
    abstract def drop_column(column_name : String) : String

    # Generates SQL to create an index.
    abstract def create_index(
      index_name : String,
      table_name : String,
      columns : Array(String),
      unique : Bool,
    ) : String

    # Generates SQL to add a foreign key constraint.
    abstract def add_foreign_key(
      constraint_name : String,
      table_name : String,
      columns : Array(String),
      references_table : String,
      references_columns : Array(String),
      on_delete : String,
      on_update : String,
    ) : String

    # Generates the SQL fragment for defining a foreign key constraint within a CREATE TABLE statement.
    abstract def define_foreign_key(fk : CQL::ForeignKey) : String

    # Defines a unique constraint.
    abstract def define_unique_constraint(constraint : CQL::UniqueConstraint) : String

    # Defines a check constraint.
    abstract def define_check_constraint(constraint : CQL::CheckConstraint) : String
  end

  # Handles Data Manipulation Language (DML) formatting specifics.
  module DmlDialect
    # Formats the VALUES clause for an INSERT statement.
    abstract def format_insert_values(values : Array(Array(DB::Any)), placeholders : Array(String)) : String

    # Formats the RETURNING clause for general statements (often INSERT).
    abstract def format_returning(columns : Array(String)) : String

    # Formats the RETURNING clause specifically for UPDATE statements.
    abstract def format_update_returning(columns : Array(String)) : String

    # Formats the RETURNING clause specifically for DELETE statements.
    abstract def format_delete_returning(columns : Array(String)) : String
  end

  # Handles query-specific formatting, including conditions, operators, and functions.
  module QueryDialect
    # Formats the LIMIT and OFFSET clauses.
    abstract def format_limit_offset(limit : DB::Any, offset : DB::Any?) : String

    # Formats the LIKE operator.
    abstract def format_like(column : String, placeholder : String) : String

    # Formats the NOT LIKE operator.
    abstract def format_not_like(column : String, placeholder : String) : String

    # Formats the IS NULL condition.
    abstract def format_is_null(column : String) : String

    # Formats the IS NOT NULL condition.
    abstract def format_is_not_null(column : String) : String

    # Formats the COUNT aggregate function.
    abstract def format_count(column : String) : String

    # Formats the MAX aggregate function.
    abstract def format_max(column : String) : String

    # Formats the MIN aggregate function.
    abstract def format_min(column : String) : String

    # Formats the AVG aggregate function.
    abstract def format_avg(column : String) : String

    # Formats the SUM aggregate function.
    abstract def format_sum(column : String) : String
  end

  # Base abstract class for all dialects, combining role-based modules.
  abstract class BaseDialect
    include GeneralDialect
    include DdlDialect
    include DmlDialect
    include QueryDialect
  end
end
