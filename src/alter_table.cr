module Cql
  # This module is part of the Cql namespace and is responsible for handling
  # database alterations. This class represents an AlterTable object.
  #
  # **Example**:
  #
  # ```
  # alter_table = AlterTable.new
  # alter_table.add_column(:email, "string")
  # alter_table.drop_column(:age)
  # alter_table.rename_column(:email, :user_email)
  # alter_table.change_column(:age, "string")
  #
  # => #<AlterTable:0x00007f8e7a4e1e80>
  # ```
  class AlterTable
    @actions : Array(Expression::AlterAction) = [] of Expression::AlterAction
    private getter schema : Cql::Schema

    def initialize(@table : Cql::Table, @schema : Cql::Schema)
    end

    # Adds a new column to the table.
    #
    # - **@param**name [Symbol] the name of the column to be added
    # - **@param**type [Any] the data type of the column
    # - **@param**as_name [String, nil] an optional alias for the column
    # - **@param**null [Bool] whether the column allows null values (default: true)
    # - **@param**default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param**unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param**size [Int32, nil] the size of the column (default: nil)
    # - **@param**index [Bool] whether the column should be indexed (default: false)
    #
    # **Example** Adding a new column with default options
    # ```
    # add_column(:email, "string")
    # ```
    #
    # **Example** Adding a new column with custom options
    # ```
    # add_column(:age, "integer", null: false, default: "18")
    # ```
    def add_column(
      name : Symbol,
      type : Any,
      as as_name : String? = nil,
      null : Bool = true,
      default : DB::Any = nil,
      unique : Bool = false,
      size : Int32? = nil,
      index : Bool = false
    )
      @table.column(name, type, as_name, null, default, unique, size)
      col = @table.columns[name]
      @actions << Expression::AddColumn.new(col)
    end

    # Drops a column from the table.
    #
    # - **@param**column [Symbol] the name of the column to be dropped
    #
    # **Example** Dropping a column
    # ```
    # drop_column(:age)
    # ```
    def drop_column(column : Symbol)
      col = @table.columns[column]
      @table.columns.delete(column)
      @actions << Expression::DropColumn.new(col.name.to_s)
    rescue exception
      @table.columns[column] = col.not_nil!
      Log.error { "Column #{column} does not exist in table #{@table}" }
    end

    # Renames a column in the table.
    #
    # - **@param**old_name [Symbol] the current name of the column
    # - **@param**new_name [Symbol] the new name for the column
    #
    # **Example** Renaming a column
    # ```
    #   rename_column(:email, :user_email)
    # ````
    def rename_column(old_name : Symbol, new_name : Symbol)
      column = @table.columns[old_name]
      @actions << Expression::RenameColumn.new(column.dup, new_name.to_s)
      column.name = new_name
      @table.columns.delete(old_name)
      @table.columns[new_name] = column
    end

    # Changes the type of a column in the table.
    #
    # - **@param**name [Symbol] the name of the column to be changed
    # - **@param**type [Any] the new data type for the column
    #
    # **Example** Changing the type of a column
    # ```
    # change_column(:age, "string")
    # ```
    def change_column(name : Symbol, type : Any)
      column = @table.columns[name]
      @actions << Expression::ChangeColumn.new(column, type)
      column.type = type
    end

    # Renames the table.
    #
    # - **@param**new_name [Symbol] the new name for the table
    #
    # **Example** Renaming the table
    # ```
    # rename_table(:new_table_name)
    # ```
    def rename_table(new_name : Symbol)
      @actions << Expression::RenameTable.new(table.dup, new_name.to_s)
      schema.tables.delete(table.table_name)
      table.table_name = new_name
      schema.tables[new_name] = table
    end

    # Adds a foreign key to the table.
    #
    # - **@param**name [Symbol] the name of the foreign key
    # - **@param**columns [Array(Symbol)] the columns in the current table
    # - **@param**table [Symbol] the referenced table
    # - **@param**references [Array(Symbol)] the columns in the referenced table
    # - **@param**on_delete [String] the action on delete (default: "NO ACTION")
    # - **@param**on_update [String] the action on update (default: "NO ACTION")
    #
    # **Example** Adding a foreign key
    # ```
    # foreign_key(:fk_user_id, [:user_id], :users, [:id], on_delete: "CASCADE")
    # ```
    def foreign_key(
      name : Symbol,
      columns : Array(Symbol),
      table : Symbol,
      references : Array(Symbol),
      on_delete : String = "NO ACTION",
      on_update : String = "NO ACTION"
    )
      fk = ForeignKey.new(name, columns, table, references, on_delete, on_update)
      @actions << Expression::AddForeignKey.new(fk)
    end

    # Drops a foreign key from the table.
    #
    # - **@param**name [Symbol] the name of the foreign key to be dropped
    #
    # **Example** Dropping a foreign key
    # ```
    # drop_foreign_key(:fk_user_id)
    # ```
    def drop_foreign_key(name : Symbol)
      @actions << Expression::DropForeignKey.new(name.to_s, @table.table_name.to_s)
    end

    # Creates an index on the table.
    #
    # - **@param**name [Symbol] the name of the index
    # - **@param**columns [Array(Symbol)] the columns to be indexed
    # - **@param**unique [Bool] whether the index should be unique (default: false)
    #
    # **Example** Creating an index
    # ```
    # create_index(:index_users_on_email, [:email], unique: true)
    # ```
    def create_index(name : Symbol, columns : Array(Symbol), unique : Bool = false)
      index = @table.add_index(columns, unique)
      index.name = name.to_s
      @actions << Expression::CreateIndex.new(index)
    end

    # Drops an index from the table.
    #
    # - **@param**name [Symbol] the name of the index to be dropped
    #
    # **Example** Dropping an index
    # ```
    # drop_index(:index_users_on_email)
    # ```
    def drop_index(name : Symbol)
      index = Index.new(@table, [] of Symbol, false, name.to_s)
      @actions << Expression::DropIndex.new(index)
    rescue exception
      Log.error { "Index #{name} does not exist in table #{@table}" }
    end

    # Converts the alter table actions to SQL.
    #
    # - **@param**visitor [Expression::Visitor] the visitor to generate SQL
    # - **@return**[String] the generated SQL
    #
    # **Example** Generating SQL for alter table actions
    # ```
    # sql = to_sql(visitor)
    # ```
    def to_sql(visitor : Expression::Visitor)
      String::Builder.build do |sb|
        @actions.each do |action|
          case action
          when Expression::CreateIndex, Expression::DropIndex, Expression::RenameTable
            sb << action.accept(visitor)
          else
            sb << Expression::AlterTable.new(@table, action).accept(visitor)
          end
          sb << ";\n"
        end
      end
    end
  end
end
