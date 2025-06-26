module CQL
  # This module is part of the CQL namespace and is responsible for handling
  # database alterations. This class represents an AlterTable object.
  #
  # **Example** :
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
    Log = CQL.config.logger
    @actions : Array(Expression::AlterAction) = [] of Expression::AlterAction
    private getter schema : CQL::Schema
    private getter table : CQL::Table

    def initialize(@table : CQL::Table, @schema : CQL::Schema)
    end

    # Adds a new column to the table.
    #
    # - **@param** name [Symbol] the name of the column to be added
    # - **@param** type [Any] the data type of the column
    # - **@param** as_name [String, nil] an optional alias for the column
    # - **@param** null [Bool] whether the column allows null values (default: true)
    # - **@param** default [DB::Any, nil] the default value for the column (default: nil)
    # - **@param** unique [Bool] whether the column should have a unique constraint (default: false)
    # - **@param** size [Int32, nil] the size of the column (default: nil)
    # - **@param** index [Bool] whether the column should be indexed (default: false)
    #
    # **Example**  Adding a new column with default options
    # ```
    # add_column(:email, "string")
    # ```
    #
    # **Example**  Adding a new column with custom options
    # ```
    # add_column(:age, "integer", null: false, default: "18")
    # ```
    def add_column(
      name : Symbol,
      type : T.class,
      as as_name : String? = nil,
      null : Bool = true,
      default : DB::Any = nil,
      unique : Bool = false,
      size : Int32? = nil,
      index : Bool = false,
    ) forall T
      new_column = Column(T).new(name, as_name, null, default, unique, size)
      new_column.table = @table
      @table.columns[name] = new_column
      @actions << Expression::AddColumn.new(new_column)
    end

    # Drops a column from the table.
    #
    # - **@param** column [Symbol] the name of the column to be dropped
    #
    # **Example**  Dropping a column
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
    # - **@param** old_name [Symbol] the current name of the column
    # - **@param** new_name [Symbol] the new name for the column
    #
    # **Example**  Renaming a column
    #
    # ```
    #   rename_column(:email, :user_email)
    # ````
    def rename_column(old_name : Symbol, new_name : Symbol)
      column = @table.columns[old_name]
      column.table = @table
      @actions << Expression::RenameColumn.new(column.dup, new_name.to_s)
      column.name = new_name
      @table.columns.delete(old_name)
      @table.columns[new_name] = column
    end

    # Changes the type of a column in the table.
    #
    # - **@param** name [Symbol] the name of the column to be changed
    # - **@param** type [Any] the new data type for the column
    #
    # **Example**  Changing the type of a column
    # ```
    # change_column(:age, "string")
    # ```
    def change_column(name : Symbol, type : T.class) forall T
      new_column = Column(T).new(name)
      new_column.table = @table
      @actions << Expression::ChangeColumn.new(new_column, type)
      @table.columns[name] = new_column
    end

    # Renames the table.
    #
    # - **@param** new_name [Symbol] the new name for the table
    #
    # **Example**  Renaming the table
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
    # - **@param** name [Symbol, nil] the optional name of the foreign key constraint
    # - **@param** columns [Array(Symbol)] the columns in the current table
    # - **@param** table [Symbol] the referenced table
    # - **@param** references [Array(Symbol), Symbol, nil] the columns in the referenced table (defaults to PK)
    # - **@param** on_delete [Symbol] the action on delete (default: :no_action)
    # - **@param** on_update [Symbol] the action on update (default: :no_action)
    #
    # **Example**  Adding a foreign key
    # ```
    # foreign_key [:user_id], references: :users, references_columns: [:id], on_delete: :cascade
    # ```
    def foreign_key(
      columns local_columns : Array(Symbol),
      references references_table : Symbol,
      references_columns : Array(Symbol) | Symbol | Nil = nil,
      name : Symbol? = nil,            # Use Symbol? for name
      on_delete : Symbol = :no_action, # Use Symbol for actions
      on_update : Symbol = :no_action, # Use Symbol for actions
    )
      # Resolve referenced columns if nil (default to PK :id)
      ref_columns_array = case references_columns
                          when Array(Symbol) then references_columns
                          when Symbol        then [references_columns]
                          else                    [:id] # Default PK assumption
                          end

      # Ensure column counts match
      unless local_columns.size == ref_columns_array.size
        raise ArgumentError.new("Number of local columns must match number of referenced columns")
      end

      fk = ForeignKey.new(
        table: @table, # Pass the table instance
        columns: local_columns,
        references_table: references_table,
        references_columns: ref_columns_array,
        name: name.nil? ? nil : name.to_s, # Convert Symbol? name to String?
        on_delete: on_delete,
        on_update: on_update
      )
      @actions << Expression::AddForeignKey.new(fk)
    end

    # Overload for single column case
    def foreign_key(
      column local_column : Symbol,
      references references_table : Symbol,
      references_columns : Array(Symbol) | Symbol | Nil = nil,
      name : Symbol? = nil,
      on_delete : Symbol = :no_action,
      on_update : Symbol = :no_action,
    )
      foreign_key(
        [local_column],
        references: references_table,
        references_columns: references_columns,
        name: name,
        on_delete: on_delete,
        on_update: on_update
      )
    end

    # Drops a foreign key from the table.
    #
    # - **@param** name [Symbol] the name of the foreign key to be dropped
    #
    # **Example**  Dropping a foreign key
    # ```
    # drop_foreign_key(:fk_user_id)
    # ```
    def drop_foreign_key(name : Symbol)
      @actions << Expression::DropForeignKey.new(name.to_s, @table.table_name.to_s)
    end

    # Creates an index on the table.
    #
    # - **@param** name [Symbol] the name of the index
    # - **@param** columns [Array(Symbol)] the columns to be indexed
    # - **@param** unique [Bool] whether the index should be unique (default: false)
    #
    # **Example**  Creating an index
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
    # - **@param** name [Symbol] the name of the index to be dropped
    #
    # **Example**  Dropping an index
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
    # - **@param** visitor [Expression::Visitor] the visitor to generate SQL
    # - **@return** [String] the generated SQL
    #
    # **Example**  Generating SQL for alter table actions
    # ```
    # sql = to_sql(visitor)
    # ```
    def to_sql(visitor : Expression::Visitor)
      String.build do |string|
        @actions.each do |action|
          case action
          when Expression::CreateIndex, Expression::DropIndex, Expression::RenameTable
            string << action.accept(visitor)
          else
            string << Expression::AlterTable.new(@table, action).accept(visitor)
          end
          string << ";\n"
        end
      end
    end
  end
end
