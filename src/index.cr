module Cql
  # An index on a table
  # This class represents an index on a table
  # It provides methods for setting the columns and unique constraint
  # It also provides methods for generating the index name
  #
  # **Example** Creating a new index
  #
  # ```
  # schema.build do
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

    def initialize(@table : Table, @columns : Array(Symbol), @unique : Bool = false, @name : String? = nil)
    end

    def index_name
      @name || "idx_#{columns.map { |c| c.to_s[0..3] }.join("_")}"
    end
  end
end
