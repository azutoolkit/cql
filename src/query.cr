module Sql
  class Query
    getter columns : Array(Column) = [] of Column
    getter tables : Array(Table) = [] of Table
    getter where : Expression::Where? = nil
    getter group_by : Expression::GroupBy? = nil
    getter having : Expression::Having? = nil
    getter order_by : Expression::OrderBy? = nil
    getter joins : Array(Expression::Join) = [] of Expression::Join
    getter limit : Int32? = nil
    getter offset : Int32? = nil

    def select
      self
    end

    def from(*tables : Table)
      @tables = tables.to_a
      self
    end

    def select(*columns : Column)
      @columns = columns.to_a
      self
    end

    def where(fields : NamedTuple(Symbol, DB::Any))
      fields.each do |field, value|
        @conditions << ComparisonCondition.new(field.to_s, "=", value)
      end
      self
    end

    def where(&) : ColumnConditionBuilder
      builder = with WhereBuilder.new(@tables) yield
      @conditions << builder.condition
      self
    end

    def order_by(column : Column, direction : OrderDirection = "ASC")
      @order_by << Order.new(column, direction)
      self
    end

    def limit(value : Int32)
      @limit = value
      self
    end

    def offset(value : Int32)
      @offset = value
      self
    end

    def build
      Expression::Query.new(
        @columns,
        @tables,
        @where,
        @group_by,
        @having,
        @order_by,
        @joins,
        @limit.not_nil!,
        @offset.not_nil!)
    end
  end
end
