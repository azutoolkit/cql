# Handles query modifiers like ORDER BY, GROUP BY, LIMIT, OFFSET.
module Modifiable
  # Specifies the columns to order by (ASC implicitly).
  #
  # **Example** Specifying the columns to order by
  #
  # ```
  # query.order(:name, :age)
  # ```
  def order(*fields : Symbol | String)
    fields.each do |k|
      column = find_column(k) # Handles String like "alias.column" or Symbol
      @order_by[column] = Expression::OrderDirection::ASC
    end
    self
  end

  # Specifies the columns to order by with direction.
  #
  # **Example** Specifying the columns to order by with direction
  #
  # ```
  # query.order(name: :asc, age: :desc)
  # ```
  def order(**fields)
    fields.each do |k, v|
      column = find_column(k) # Handles String like "alias.column" or Symbol
      direction = v.is_a?(Symbol) ? Expression::OrderDirection.parse(v.to_s) : Expression::OrderDirection::ASC
      @order_by[column] = direction
    end
    self
  end

  # Specifies the columns to group by.
  #
  # **Example** Specifying the columns to group by
  #
  # ```
  # query.group(:name, :age)
  # ```
  def group(*columns : Symbol | String)
    # find_column handles String/Symbol
    @group_by = columns.map { |column| find_column(column) }.to_a
    self
  end

  # Sets the limit for the number of records to return.
  #
  # **Example** Setting the limit for the number of records to return
  #
  # ```
  # query.limit(10)
  # ```
  def limit(value : Int32)
    @limit = value
    self
  end

  # Sets the offset for the query.
  #
  # **Example** Setting the offset for the query
  #
  # ```
  # query.offset(10)
  # ```
  def offset(value : Int32)
    @offset = value
    self
  end
end
