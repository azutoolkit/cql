module CQL
  # Turns `Query#window` arguments (column names as symbols) into a
  # `WindowFunction` node, resolving columns against the query's tables.
  struct WindowBuilder
    def initialize(@query : Query)
    end

    def build(function : Symbol, column : Symbol?, name : Symbol, offset : Int32?, buckets : Int32?,
              partition_by, order_by, rows, range) : Expression::WindowFunction
      CQL::Identifier.validate!(name.to_s, "alias")
      kind = Expression::WindowFunctionKind.parse?(function.to_s) || raise ArgumentError.new("Unknown window function #{function.inspect}")

      Expression::WindowFunction.new(
        kind, name,
        column: column.try { |column_name| expression(column_name) },
        argument: argument(kind, offset, buckets),
        partition_by: partitions(partition_by),
        order_by: ordering(order_by),
        frame: frame(rows, range))
    end

    private def argument(kind, offset, buckets) : Int32?
      raise ArgumentError.new("buckets only applies to ntile") if buckets && !kind.ntile?
      raise ArgumentError.new("offset only applies to lag and lead") if offset && !(kind.lag? || kind.lead?)
      buckets || offset
    end

    private def expression(name : Symbol) : Expression::BaseColumn
      @query.column_expression(name)
    end

    private def partitions(spec) : Array(Expression::BaseColumn)
      columns = [] of Expression::BaseColumn
      names(spec).each { |name| columns << expression(name) }
      columns
    end

    private def names(spec) : Array(Symbol)
      case spec
      when Nil    then [] of Symbol
      when Symbol then [spec]
      else             spec.to_a
      end
    end

    private def ordering(spec) : Expression::OrderBy?
      orders = {} of Expression::BaseColumn => Expression::OrderDirection
      case spec
      when Nil, Symbol, Array
        names(spec).each { |name| orders[expression(name)] = Expression::OrderDirection::ASC }
      else
        spec.each { |name, direction| orders[expression(name)] = Expression::OrderDirection.parse(direction.to_s) }
      end
      Expression::OrderBy.new(orders) unless orders.empty?
    end

    private def frame(rows, range) : Expression::Frame?
      raise ArgumentError.new("Use either rows or range for a frame, not both") if rows && range
      bounds = rows || range
      return unless bounds
      Expression::Frame.new(rows ? Expression::FrameUnit::Rows : Expression::FrameUnit::Range, bounds[0], bounds[1])
    end
  end
end
