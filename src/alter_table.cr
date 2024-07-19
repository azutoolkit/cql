module Sql
  class AlterTable
    @table : Table
    @actions : Array(Expression::AlterAction) = [] of Expression::AlterAction

    def initialize(@table : Table)
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

    def to_sql(visitor : Expression::Visitor)
      String::Builder.build do |sb|
        @actions.each do |action|
          alter_table = Expression::AlterTable.new(@table, action)
          sb << alter_table.accept(visitor)
          sb << ";\n"
        end
      end
    end
  end
end
