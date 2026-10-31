require "./base_column"
require "db"
require "./table"

module CQL
  # A typed column in a table: its name, type, default value and constraints,
  # and the expression used to reference it in queries.
  #
  # **Example** Declaring columns
  #
  # ```
  # schema.table :members do
  #   primary :id, Int64
  #   column :name, String, null: false, default: "John"
  #   column :age, Int32, null: true
  # end
  # ```
  class Column(Type) < BaseColumn
    property sql_type : SQLType? = nil
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
    # The declared length of a String column (`VARCHAR(size)`); SQLite and other types ignore it.
    getter size : Int32? = nil
    # :nodoc:
    property? index : Index? = nil
    # :nodoc:
    property? version_number : Bool = false

    # Create a new column instance; the type is the class's type argument (`Column(String)`).
    # Tables add columns with `Table#column` instead.
    # - **@param** : name (Symbol) - The name of the column
    # - **@param** : as_name (String, nil) - An optional alias for the column
    # - **@param** : null (Bool) - Whether the column allows null values (default: false)
    # - **@param** : default (DB::Any) - The default value for the column (default: nil)
    # - **@param** : unique (Bool) - Whether the column should have a unique constraint (default: false)
    # - **@param** : size (Int32, nil) - The size of the column (default: nil)
    # - **@param** : index (Index, nil) - The index for the column (default: nil)
    # - **@param** : version_number (Bool) - Whether this column is used for optimistic locking (default: false)
    #
    # **Example**
    #
    # ```
    # column = CQL::Column(String).new(:name)
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
      @sql_type : SQLType? = nil,
    )
    end

    # Expressions for this column
    # - **@return** [Expression::BaseColumn] the column expression builder
    #
    # **Example**
    #
    # ```
    # column = schema.users.name
    # column.expression.eq("John")
    # ```
    def expression : Expression::BaseColumn
      Expression::TypedColumn(Type).new(self, @as_name)
    end

    def copy_declaration_to(table : Table) : BaseColumn
      copy = dup
      copy.reset_declaration_owner(table)
      copy
    end

    protected def reset_declaration_owner(@table : Table) : Nil
      @index = nil
      value = @default
      @default = value.dup if value.is_a?(Bytes)
    end

    def copy_to(table : Table) : BaseColumn
      Column(Type).new(@name, nil, @null, sql_type: @sql_type).tap(&.table=(table))
    end

    # Builds the expression qualified by a *table* alias (e.g. `c.name` for
    # `FROM customers AS c`). The column's own `as:` name is a select-list
    # alias, never a table qualifier, so it is not used here.
    def expression(table_alias : String?) : Expression::BaseColumn
      Expression::TypedColumn(Type).new(self, table_alias)
    end

    def strict_type
      Type
    end

    def type
      adapter = @table.not_nil!.schema.adapter
      if explicit = @sql_type
        case explicit
        in .text?
          raise ArgumentError.new("sql_type: :text requires String without size") unless Type == String && @size.nil?
          return "TEXT"
        in .timestamptz?
          raise ArgumentError.new("sql_type: :timestamptz requires Time") unless Type == Time
          raise CQL::Error.new("TIMESTAMPTZ requires PostgreSQL or CockroachDB") unless adapter.postgres_compatible?
          return "TIMESTAMPTZ"
        end
      end
      adapter.dialect.sized_type(adapter.sql_type(Type), @size)
    end
  end

  # A date-only column (`Table#date`). `CQL::Date` is `Time`, so the type alone cannot tell it from
  # a timestamp; this column declares itself `DATE` on every adapter. `AlterTable#add_column` and
  # `change_column` take a Crystal type, so `Date` there declares a timestamp.
  class DateColumn(Type) < Column(Type)
    def copy_to(table : Table) : BaseColumn
      DateColumn(Type).new(@name, nil, @null, sql_type: @sql_type).tap(&.table=(table))
    end

    def type
      "DATE"
    end
  end
end
