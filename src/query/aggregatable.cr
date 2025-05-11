# Handles aggregate functions.
module Aggregatable
  # Adds a COUNT aggregate function to the query.
  #
  # **Example** Counting all rows
  #
  # ```
  # query.count
  # => 100
  # ```
  def count(column : Symbol = :*)
    @aggr_columns << if column == :*
      first_table_alias = @query_tables.first_key? # Use String key
      raise "Cannot COUNT(*) without a FROM clause" unless first_table_alias
      table_info = @query_tables[first_table_alias]
      # Use positional arguments for BaseColumn.new
      star_col = Column(Int64).new(:*, Int64) # Placeholder Type
      # Pass String alias
      Expression::Count.new(Expression::Column.new(star_col, alias_name: table_info[:alias]))
    else
      build_aggr_expression(:count, column)
    end
    self
  end

  # Adds a MAX aggregate function to the query.
  #
  # **Example** Finding the maximum value
  #
  # ```
  # query.max(:age)
  # => 100
  # ```
  def max(column : Symbol)
    @aggr_columns << build_aggr_expression(:max, column)
    self
  end

  # Adds a MIN aggregate function to the query.
  #
  # **Example** Finding the minimum value
  #
  # ```
  # query.min(:age)
  # => 100
  # ```
  def min(column : Symbol)
    @aggr_columns << build_aggr_expression(:min, column)
    self
  end

  # Adds a SUM aggregate function to the query.
  #
  # **Example** Summing all values
  #
  # ```
  # query.sum(:age)
  # => 100
  # ```
  def sum(column : Symbol)
    @aggr_columns << build_aggr_expression(:sum, column)
    self
  end

  # Adds an AVG aggregate function to the query.
  #
  # **Example** Calculating the average value
  #
  # ```
  # query.avg(:age)
  # => 100
  # ```
  def avg(column : Symbol)
    @aggr_columns << build_aggr_expression(:avg, column)
    self
  end
end
