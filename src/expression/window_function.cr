require "./select_expression"

module Expression
  enum WindowFunctionKind
    RowNumber
    Rank
    DenseRank
    PercentRank
    CumeDist
    Ntile
    Lag
    Lead
    FirstValue
    LastValue
    Count
    Sum
    Avg
    Min
    Max

    def label : String
      to_s.underscore
    end

    def to_sql : String
      label.upcase
    end

    def ranking? : Bool
      row_number? || rank? || dense_rank? || percent_rank? || cume_dist? || ntile?
    end

    # Functions that read a column (COUNT may omit it and count rows).
    def takes_column? : Bool
      !ranking?
    end

    def requires_column? : Bool
      takes_column? && !count?
    end
  end

  enum FrameUnit
    Rows
    Range
  end

  # `ROWS|RANGE BETWEEN from AND to`. A bound is an offset (negative =
  # preceding, 0 = current row, positive = following) or `:unbounded_preceding`
  # / `:unbounded_following`.
  struct Frame
    alias Bound = Int32 | Symbol

    getter unit : FrameUnit
    getter from : Bound
    getter to : Bound

    def initialize(@unit : FrameUnit, @from : Bound, @to : Bound)
      {from, to}.each { |bound| validate_bound!(bound) }
      raise ArgumentError.new("A frame cannot start at :unbounded_following") if from == :unbounded_following
      raise ArgumentError.new("A frame cannot end at :unbounded_preceding") if to == :unbounded_preceding
      raise ArgumentError.new("A frame start must not come after its end") if (start = from).is_a?(Int32) && (finish = to).is_a?(Int32) && start > finish
    end

    # Whether either bound is a row/value offset (as opposed to current row or unbounded).
    def offset? : Bool
      {from, to}.any? { |bound| bound.is_a?(Int32) && !bound.zero? }
    end

    private def validate_bound!(bound : Bound) : Nil
      case bound
      in Int32  then raise ArgumentError.new("A frame offset is out of range") if bound == Int32::MIN
      in Symbol then raise ArgumentError.new("Invalid frame bound #{bound.inspect}: use :unbounded_preceding, :unbounded_following or an offset") unless {:unbounded_preceding, :unbounded_following}.includes?(bound)
      end
    end
  end

  # `FUNCTION(...) OVER (PARTITION BY ... ORDER BY ... frame)`.
  class WindowFunction < SelectExpression
    getter kind : WindowFunctionKind
    getter column : BaseColumn?
    # LAG/LEAD offset or NTILE bucket count.
    getter argument : Int32?
    getter partition_by : Array(BaseColumn)
    getter order_by : OrderBy?
    getter frame : Frame?

    def initialize(@kind : WindowFunctionKind, as_name : Symbol, @column : BaseColumn? = nil, @argument : Int32? = nil,
                   @partition_by : Array(BaseColumn) = [] of BaseColumn, @order_by : OrderBy? = nil, @frame : Frame? = nil)
      super(as_name)
      validate!
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end

    private def validate! : Nil
      label = kind.label
      raise ArgumentError.new("#{label} needs a column") if kind.requires_column? && column.nil?
      raise ArgumentError.new("#{label} takes no column") if !kind.takes_column? && column
      raise ArgumentError.new("ntile needs buckets") if kind.ntile? && argument.nil?
      raise ArgumentError.new("buckets must be positive") if kind.ntile? && argument.try(&.<=(0))
      raise ArgumentError.new("#{label} takes no argument") if argument && !(kind.ntile? || kind.lag? || kind.lead?)
      raise ArgumentError.new("offset must not be negative") if (kind.lag? || kind.lead?) && argument.try(&.<(0))
      raise ArgumentError.new("RANGE with an offset needs order_by") if (frame = @frame) && frame.unit.range? && frame.offset? && order_by.nil?
    end
  end
end
