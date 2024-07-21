module Sql
  class AlterTable
    private getter table : Sql::Table
    @actions : Array(Expression::AlterAction) = [] of Expression::AlterAction
    private getter schema : Sql::Schema

    def initialize(@table : Sql::Table, @schema : Sql::Schema)
    end

    def add_column(
      name : Symbol,
      type : ColumnType,
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

    def drop_column(column : Symbol)
      col = @table.columns[column]
      @table.columns.delete(column)
      @actions << Expression::DropColumn.new(col.name.to_s)
    rescue exception
      @table.columns[column] = col.not_nil!
      Log.error { "Column #{column} does not exist in table #{@table}" }
    end

    def rename_column(old_name : Symbol, new_name : Symbol)
      column = @table.columns[old_name]
      @actions << Expression::RenameColumn.new(column.dup, new_name.to_s)
      column.name = new_name
      @table.columns.delete(old_name)
      @table.columns[new_name] = column
    end

    def change_column(name : Symbol, type : ColumnType)
      column = @table.columns[name]
      @actions << Expression::ChangeColumn.new(column, type)
      column.type = type
    end

    def rename_table(new_name : Symbol)
      @actions << Expression::RenameTable.new(table.dup, new_name.to_s)
      schema.tables.delete(table.table_name)
      table.table_name = new_name
      schema.tables[new_name] = table
    end

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

    def drop_foreign_key(name : Symbol)
      @actions << Expression::DropForeignKey.new(name.to_s, @table.table_name.to_s)
    end

    def create_index(name : Symbol, columns : Array(Symbol), unique : Bool = false)
      index = @table.add_index(columns, unique)
      index.name = name.to_s
      @actions << Expression::CreateIndex.new(index)
    end

    def drop_index(name : Symbol)
      index = Index.new(@table, [] of Symbol, false, name.to_s)
      @actions << Expression::DropIndex.new(index)
    rescue exception
      Log.error { "Index #{name} does not exist in table #{@table}" }
    end

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
