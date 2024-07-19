module Sql
  class AlterTable
    @table : Sql::Table
    @actions : Array(Expression::AlterAction) = [] of Expression::AlterAction

    def initialize(@table : Sql::Table)
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
      existing_column = @table.columns[old_name]
      col = existing_column.dup
      existing_column.name = new_name
      @actions << Expression::RenameColumn.new(col, new_name.to_s)
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
          if action.is_a?(Expression::CreateIndex) || action.is_a?(Expression::DropIndex)
            sb << action.accept(visitor)
          else
            sb << Expression::AlterTable.new(@table, action).accept(visitor)
          end
          sb << "; "
        end
      end
    end
  end
end
