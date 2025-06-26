require "./base_column"
require "db"
require "./table"

module CQL
  # A column in a table
  # This class represents a column in a table
  # It provides methods for setting the column type, default value, and constraints
  # It also provides methods for building expressions
  #
  # **Example** Creating a new column
  #
  # ```
  # schema.define do
  #   table :users do
  #     column :name, String, null: false, default: "John"
  #     column :age, Int32, null: false
  #   end
  # end
  # ```
  class Column(Type) < BaseColumn
    @as_name : String? = nil
    # :nodoc:
    property name : Symbol

    # :nodoc:
    getter? null : Bool = false
    # :nodoc:
    getter default : DB::Any = nil
    # :nodoc:
    getter? unique : Bool = false
    # :nodoc:
    property table : Table? = nil
    # :nodoc:
    property length : Int32? = nil
    # :nodoc:
    property? index : Index? = nil
    # :nodoc:
    property? version_number : Bool = false

    # Create a new column instance
    # - **@param** : name (Symbol) - The name of the column
    # - **@param** : type (Any) - The data type of the column
    # - **@param** : as_name (String, nil) - An optional alias for the column
    # - **@param** : null (Bool) - Whether the column allows null values (default: false)
    # - **@param** : default (DB::Any) - The default value for the column (default: nil)
    # - **@param** : unique (Bool) - Whether the column should have a unique constraint (default: false)
    # - **@param** : size (Int32, nil) - The size of the column (default: nil)
    # - **@param** : index (Index, nil) - The index for the column (default: nil)
    # - **@param** : version_number (Bool) - Whether this column is used for optimistic locking (default: false)
    # - **@return** : Nil
    # - **@raise** : CQL::Error if the column type is not valid
    #
    # **Example**
    #
    # ```
    # column = CQL::Column.new(:name, String)
    # ```
    def initialize(
      @name : Symbol,
      @as_name : String? = nil,
      @null : Bool = false,
      @default : DB::Any = nil,
      @unique : Bool = false,
      @size : Int32? = nil,
      @index : Index? = nil,
      @version_number : Bool = false,
    )
    end

    # Expressions for this column
    # - **@return** [Expression::BaseColumn] the column expression builder
    #
    # **Example**
    #
    # ```
    # column = CQL::Column.new(:name, String)
    # column.expression.eq("John")
    # ```
    def expression : Expression::BaseColumn
      Expression::TypedColumn(Type).new(self, @as_name)
    end

    def strict_type
      Type
    end

    def type
      @table.not_nil!.schema.adapter.sql_type(Type)
    end
  end
end
