module Cql
  # Error class
  # This class represents an error in the Cql library
  # It provides a message describing the error
  #
  # **Example** Raising an error
  #
  # ```
  # raise Cql::Error.new("Something went wrong")
  # ```
  class Error < Exception
    def initialize(@message : String)
    end
  end

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
  class Column(T) < BaseColumn
    @as_name : String? = nil
    # :nodoc:
    property name : Symbol
    # :nodoc:
    property type : Any
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

    # Create a new column instance
    # - **@param** : name (Symbol) - The name of the column
    # - **@param** : type (Any) - The data type of the column
    # - **@param** : as_name (String, nil) - An optional alias for the column
    # - **@param** : null (Bool) - Whether the column allows null values (default: false)
    # - **@param** : default (DB::Any) - The default value for the column (default: nil)
    # - **@param** : unique (Bool) - Whether the column should have a unique constraint (default: false)
    # - **@param** : size (Int32, nil) - The size of the column (default: nil)
    # - **@param** : index (Index, nil) - The index for the column (default: nil)
    # - **@return** : Nil
    # - **@raise** : Cql::Error if the column type is not valid
    #
    # **Example**
    #
    # ```
    # column = Cql::Column.new(:name, String)
    # ```
    def initialize(
      @name : Symbol,
      @type : T.class,
      @as_name : String? = nil,
      @null : Bool = false,
      @default : DB::Any = nil,
      @unique : Bool = false,
      @size : Int32? = nil,
      @index : Index? = nil
    )
    end

    # Expressions for this column
    # - **@return** [Expression::ColumnBuilder] the column expression builder
    #
    # **Example**
    #
    # ```
    # column = Cql::Column.new(:name, String)
    # column.expression.eq("John")
    # ```
    def expression
      Expression::ColumnBuilder.new(Expression::Column.new(self))
    end

    # Validate the value
    # - **@param** value [DB::Any] The value to validate
    #
    # **Example**
    #
    # ```
    # column = Cql::Column.new(:name, String)
    # column.validate!("John")
    # ```
    def validate!(value)
      return if value.class == type
      raise Error.new "Expected column `#{name}` to be #{type}, but got #{value.class}"
    end
  end
end
