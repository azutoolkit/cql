# Handles building the final SQL query.
module Buildable
  # Converts the query into an SQL string and its corresponding parameters.
  #
  # **Example** Converting the query to an SQL string
  #
  # ```
  # query.to_sql
  # => ["SELECT * FROM users", []]
  # ```
  def to_sql(gen = @schema.gen)
    gen.reset
    build.accept(gen)
    {gen.query, gen.params}
  end

  # Builds the final query expression object.
  #
  # **Example** Building the final query expression object
  #
  # ```
  # query.build
  # => #<Expression::Query:0x00007f8000000000>
  # ```
  def build
    select_cols, aggr_exprs = build_select # Returns Expression::Column with String aliases

    Expression::Query.new(
      select_cols,
      build_from,     # Returns Expression::From with Expression::Table(String alias)
      @where,         # Uses aliased expressions internally (String alias)
      build_group_by, # Returns Expression::GroupBy with Expression::Column(String alias)
      @having,        # Uses aliased expressions internally (String alias)
      build_order_by, # Returns Expression::OrderBy with Expression::Column(String alias)
      @joins,         # Join expressions contain String aliases
      build_limit,
      distinct?,
      aggr_exprs # Aggregate expressions contain String aliases
    )
  end
end
