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
  # schema.build do
  #  table :users do
  #   column :name, String, null: false, default: "John"
  #   column :age, Int32, null: false
  # end
  # ```
  class Column(T) < BaseColumn
    @as_name : String? = nil

    property name : Symbol
    property type : Any
    getter? null : Bool = false
    getter default : DB::Any = nil
    getter? unique : Bool = false
    property table : Table? = nil
    property length : Int32? = nil
    property? index : Index? = nil

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
