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
    # In declaration order, each built against the table as it was named then, so a later
    # `rename_table` in the same block does not rename the statements before it.
    @statements = [] of Expression::AlterTable | Expression::AlterAction
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
      alter Expression::AddColumn.new(new_column.dup)
      add_column_index(new_column, unique) if index
      @table.columns_changed!
    end

    # Like `create_index`, the index is created but not recorded in the table's declared indexes.
    private def add_column_index(column : BaseColumn, unique : Bool) : Nil
      column_index = Index.new(as_declared, [column.name], unique)
      column.index = column_index
      @statements << Expression::CreateIndex.new(column_index)
    end

    # Drops a column from the table. The column need not be declared in the schema: the database
    # reports a column it does not have.
    #
    # - **@param** column [Symbol] the name of the column to be dropped
    #
    # **Example**  Dropping a column
    # ```
    # drop_column(:age)
    # ```
    def drop_column(column : Symbol)
      @table.columns.delete(column)
      alter Expression::DropColumn.new(column.to_s)
      @table.columns_changed!
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
      alter Expression::RenameColumn.new(column.dup, new_name.to_s)
      column.name = new_name
      @table.columns.delete(old_name)
      @table.columns[new_name] = column
      @table.columns_changed!
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
      alter Expression::ChangeColumn.new(new_column.dup, type)
      @table.columns[name] = new_column
      @table.columns_changed!
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
      @statements << Expression::RenameTable.new(as_declared, new_name.to_s)
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
      references_columns : (Array(Symbol) | Symbol)? = nil,
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
        table: as_declared,
        columns: local_columns,
        references_table: references_table,
        references_columns: ref_columns_array,
        name: name.nil? ? nil : name.to_s, # Convert Symbol? name to String?
        on_delete: on_delete,
        on_update: on_update
      )
      alter Expression::AddForeignKey.new(fk)
    end

    # Overload for single column case
    def foreign_key(
      column local_column : Symbol,
      references references_table : Symbol,
      references_columns : (Array(Symbol) | Symbol)? = nil,
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
      alter Expression::DropForeignKey.new(name.to_s, @table.table_name.to_s)
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
      @statements << Expression::CreateIndex.new(Index.new(as_declared, columns, unique, name.to_s))
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
      index = Index.new(as_declared, [] of Symbol, false, name.to_s)
      @statements << Expression::DropIndex.new(index)
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
        @statements.each { |statement| string << statement.accept(visitor) << ";\n" }
      end
    end

    # Queues *action* as an `ALTER TABLE` statement on the table under its current name.
    private def alter(action : Expression::AlterAction) : Nil
      @statements << Expression::AlterTable.new(as_declared, action)
    end

    # The table under its current name: `rename_table` renames `table`, not this copy. Only the name is
    # isolated; the copy shares its columns, indexes and foreign keys with `table`.
    private def as_declared : CQL::Table
      table.dup
    end
  end
end
