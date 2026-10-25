module CQL
  # An index on a table
  # This class represents an index on a table
  # It provides methods for setting the columns and unique constraint
  # It also provides methods for generating the index name
  #
  # **Example** Creating a new index
  #
  # ```
  # schema.define do
  #   table :users do
  #     column :name, String
  #     column :email, String
  #     index [:name, :email], unique: true
  #   end
  # end
  # ```
  class Index
    MAX_NAME_LENGTH = 63

    getter columns : Array(Symbol)
    getter? unique : Bool
    getter table : Table
    property name : String? = nil

    # Create a new index instance on a table
    # - **@param** : table (Table) - The table to create the index on
    # - **@param** : columns (Array(Symbol)) - The columns to index
    # - **@param** : unique (Bool) - Whether the index should be unique (default: false)
    # - **@param** : name (String, nil) - The name of the index (default: nil)
    # - **@return** : Nil
    # - **@raise** : CQL::Error if the table does not exist
    # - **@raise** : CQL::Error if the column does not exist
    #
    # **Example**
    #
    # ```
    # index = CQL::Index.new(table, [:name, :email], unique: true)
    # ```
    def initialize(@table : Table, @columns : Array(Symbol), @unique : Bool = false, @name : String? = nil)
    end

    # The index name: the explicit name, or `idx_<table>_<columns>`.
    # Index names are schema-wide in SQLite and PostgreSQL, so the default includes the table.
    #
    # **Example**
    #
    # ```
    # CQL::Index.new(users, [:name, :email]).index_name # => "idx_users_name_email"
    # ```
    def index_name : String
      @name || "idx_#{table.table_name}_#{columns.join("_")}"
    end
  end
end
