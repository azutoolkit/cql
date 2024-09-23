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

    # Generate the index name
    # - **@return** : String
    # - **@raise** : Nil
    #
    # **Example**
    #
    # ```
    # index_name = index.index_name
    # ```
    def index_name
      @name || "idx_#{columns.map { |c| c.to_s[0..3] }.join("_")}"
    end
  end
end
