module Sql
  class Query
    getter columns : Array(Column) = [] of Column
    getter tables : Hash(Symbol, Table) = {} of Symbol => Table
    getter where : Expression::Where? = nil
    getter group_by : Array(Column) = [] of Column
    getter having : Expression::Having? = nil
    getter order_by : Hash(Expression::Column, Expression::OrderDirection) = {} of Expression::Column => Expression::OrderDirection
    getter joins : Array(Expression::Join) = [] of Expression::Join
    getter limit : Int32? = nil
    getter offset : Int32? = nil
    getter? distinct : Bool = false

    def initialize(schema : Schema)
      @schema = schema
    end

    def select(**fields)
      fields.each do |k, v|
        v.map { |f| @columns << @schema.tables[k].columns[f] }
      end

      self
    end

    def select(*columns : Symbol)
      @columns = columns.map { |column| find_column(column) }.to_a
      self
    end

    def from(*tbls : Symbol)
      tbls.each { |tbl| @tables[tbl] = find_table(tbl) }
      self
    end

    def where(**fields)
      condition = nil
      fields.to_h.each_with_index do |(k, v), index|
        expr = get_expression(k, v)
        condition = index == 0 ? expr : Expression::And.new(condition.not_nil!, expr)
      end

      @where = Expression::Where.new(condition.not_nil!)

      self
    end

    def where(&)
      builder = with Expression::WhereBuilder.new(@columns) yield
      @where = Expression::Where.new(builder.condition)
      self
    end

    def inner(table : Symbol, on : Hash(Sql::Column, Sql::Column | DB::Any))
      table = @schema.tables[table]
      join(Expression::JoinType::INNER, table, on)
      self
    end

    def left(table : Symbol, on : Hash(Sql::Column, Sql::Column | DB::Any))
      table = @schema.tables[table]
      join(Expression::JoinType::LEFT, table, on)
      self
    end

    def right(table : Symbol, on : Hash(Sql::Column, Sql::Column | DB::Any))
      table = @schema.tables[table]
      join(Expression::JoinType::RIGHT, table, on)
      self
    each_with_index

    def inner(table : Symbol, &)
      table = Expression::Table.new(@schema.tables[table])
      builder = with Expression::JoinBuilder.new(@schema.tables) yield
      @joins << Expression::Join.new(Expression::JoinType::INNER, table, builder.condition)
      self
    end

    def left(table : Symbol, &)
      table = Expression::Table.new(@schema.tables[table])
      builder = with Expression::JoinBuilder.new(@schema.tables) yield
      @joins << Expression::Join.new(Expression::JoinType::LEFT, table, builder.condition)
      self
    end

    def right(table : Symbol, &)
      table = Expression::Table.new(@schema.tables[table])
      builder = with Expression::JoinBuilder.new(@schema.tables) yield
      @joins << Expression::Join.new(Expression::JoinType::RIGHT, table, builder.condition)
      self
    end

    private def join(type : Expression::JoinType, table : Table, on : Hash(Sql::Column, Sql::Column | DB::Any))
      condition = on.map do |left, right|
        right_col = right.is_a?(Sql::Column) ? Expression::Column.new(right) : right
        Expression::CompareCondition.new(Expression::Column.new(left), "=", right_col)
      end.reduce { |acc, cond| Expression::And.new(acc, cond) }

      @joins << Expression::Join.new(type, Expression::Table.new(table), condition)
      self
    end

    def order(*fields)
      fields.each do |k|
        column = Expression::Column.new(find_column(k))
        @order_by[column] = Expression::OrderDirection::ASC
      end

      self
    end

    def order(**fields)
      fields.each do |k, v|
        column = Expression::Column.new(find_column(k))
        @order_by[column] = Expression::OrderDirection.parse(v.to_s)
      end

      self
    end

    def group(*columns)
      @group_by = columns.map { |column| find_column(column) }.to_a
      self
    end

    def having(&)
      builder = with Expression::HavingBuilder.new(@group_by) yield
      @having = Expression::Having.new(builder.condition)
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

    def distinct
      @distinct = true
      self
    end

    def build
      Expression::Query.new(
        build_select,
        Expression::From.new(@tables.values),
        @where,
        build_group_by,
        @having,
        build_order_by,
        @joins,
        build_limit,
        distinct?)
    end

    private def get_expression(field, value)
      column = find_column(field)
      Expression::Compare.new(Expression::Column.new(column), "=", value)
    end

    private def build_group_by
      Expression::GroupBy.new(@group_by.map { |column| Expression::Column.new(column) })
    end

    private def build_order_by
      Expression::OrderBy.new(order_by)
    end

    private def build_limit
      Expression::Limit.new(@limit, @offset) if @limit
    ensure
      @limit = nil
      @offset = nil
    end

    private def build_select
      if @columns.empty?
        @tables.each do |tbl_name, table|
          @columns.concat(table.columns.values)
        end
      end

      @columns.map do |column|
        Expression::Column.new(column)
      end
    ensure
      @columns.clear
    end

    private def find_table(name : Symbol) : Sql::Table
      table = @schema.tables[name]
      raise "Table #{name} not found" unless table
      table
    end

    private def find_column(name : Symbol) : Sql::Column?
      @tables.each do |_tbl_name, table|
        column = table.columns[name]
        return column if column
      end

      raise "Column #{name} not found in any of #{@tables} tables"
    end

    private def validate_fields!(**fields)
      fields.map do |name, value|
        column = find_column(name)
        raise "Column #{name} not found" unless column
        raise "Column #{name} is not nullable" if !column.null? && value.nil?
        raise "Column #{name} is not of type #{value.class}" unless column.type.new(value)
        column
      end
    end

    macro method_missing(call)
      def {{call.id}}
        @schema.tables[:{{call.id}}]
      end
    end
  end
end
