# Handles all types of JOIN clauses.
module Joinable
  # --- Explicit Joins ---

  # Adds an INNER JOIN with an explicit ON condition (Hash).
  #
  # **Example** Adding an INNER JOIN with an explicit ON condition
  #
  # ```
  # query.inner(users, on: {users.id: posts.user_id})
  # ```
  def inner(table_or_alias : Symbol | Hash(Symbol, Symbol), on : Hash(CQL::BaseColumn, CQL::BaseColumn | DB::Any))
    join_explicitly(table_or_alias, on, Expression::JoinType::INNER)
  end

  # Adds an INNER JOIN with an explicit ON condition (Block).
  #
  # **Example** Adding an INNER JOIN with an explicit ON condition using a block
  #
  # ```
  # query.inner(users) do |builder|
  #   builder.on(users.id == posts.user_id)
  # end
  def inner(table_or_alias : Symbol | Hash(Symbol, Symbol), &)
    join_explicitly(table_or_alias, Expression::JoinType::INNER) do |builder|
      yield builder
    end
  end

  # Adds a LEFT JOIN with an explicit ON condition (Hash).
  #
  # **Example** Adding a LEFT JOIN with an explicit ON condition
  #
  # ```
  # query.left(users, on: {users.id: posts.user_id})
  # ```
  def left(table_or_alias : Symbol | Hash(Symbol, Symbol), on : Hash(CQL::BaseColumn, CQL::BaseColumn | DB::Any))
    join_explicitly(table_or_alias, on, Expression::JoinType::LEFT)
  end

  # Adds a LEFT JOIN with an explicit ON condition (Block).
  #
  # **Example** Adding a LEFT JOIN with an explicit ON condition using a block
  #
  # ```
  # query.left(users) do |builder|
  #   builder.on(users.id == posts.user_id)
  # end
  def left(table_or_alias : Symbol | Hash(Symbol, Symbol), &)
    join_explicitly(table_or_alias, Expression::JoinType::LEFT) do |builder|
      yield builder
    end
  end

  # Adds a RIGHT JOIN with an explicit ON condition (Hash).
  #
  # **Example** Adding a RIGHT JOIN with an explicit ON condition
  #
  # ```
  # query.right(users, on: {users.id: posts.user_id})
  # ```
  def right(table_or_alias : Symbol | Hash(Symbol, Symbol), on : Hash(CQL::BaseColumn, CQL::BaseColumn | DB::Any))
    join_explicitly(table_or_alias, on, Expression::JoinType::RIGHT)
  end

  # Adds a RIGHT JOIN with an explicit ON condition (Block).
  #
  # **Example** Adding a RIGHT JOIN with an explicit ON condition using a block
  #
  # ```
  # query.right(users) do |builder|
  #   builder.on(users.id == posts.user_id)
  # end
  def right(table_or_alias : Symbol | Hash(Symbol, Symbol), &)
    join_explicitly(table_or_alias, Expression::JoinType::RIGHT) do |builder|
      yield builder
    end
  end

  # --- Inferred Joins (INNER) ---

  # Adds inferred INNER JOINs using keyword arguments for aliases.
  #
  # **Example** Adding inferred INNER JOINs using keyword arguments for aliases
  #
  # ```
  # query.joins(users: :posts)
  # ```
  def joins(**tables_to_join)
    tables_array = tables_to_join.map { |key, value| {key, value} }
    join_inferred(tables_array, Expression::JoinType::INNER)
  end

  # Adds inferred INNER JOINs using splat arguments for table names.
  #
  # **Example** Adding inferred INNER JOINs using splat arguments for table names
  #
  # ```
  # query.joins(:users, :posts)
  # ```
  def joins(*tables_to_join : Symbol)
    tables_array = tables_to_join.map { |name| {name, name} }
    join_inferred(tables_array, Expression::JoinType::INNER)
  end

  # --- Inferred Joins (LEFT) ---

  # Adds inferred LEFT JOINs using keyword arguments for aliases.
  #
  # **Example** Adding inferred LEFT JOINs using keyword arguments for aliases
  #
  # ```
  # query.joins(users: :posts)
  # ```
  def left_joins(**tables_to_join)
    tables_array = tables_to_join.map { |key, value| {key, value} }
    join_inferred(tables_array, Expression::JoinType::LEFT)
  end

  # Adds inferred LEFT JOINs using splat arguments for table names.
  #
  # **Example** Adding inferred LEFT JOINs using splat arguments for table names
  #
  # ```
  # query.joins(:users, :posts)
  # ```
  def left_joins(*tables_to_join : Symbol)
    tables_array = tables_to_join.map { |name| {name, name} }
    join_inferred(tables_array, Expression::JoinType::LEFT)
  end

  # --- Inferred Joins (RIGHT) ---

  # Adds inferred RIGHT JOINs using keyword arguments for aliases.
  #
  # **Example** Adding inferred RIGHT JOINs using keyword arguments for aliases
  #
  # ```
  # query.joins(users: :posts)
  # ```
  def right_joins(**tables_to_join)
    tables_array = tables_to_join.map { |key, value| {key, value} }
    join_inferred(tables_array, Expression::JoinType::RIGHT)
  end

  # Adds inferred RIGHT JOINs using splat arguments for table names.
  #
  # **Example** Adding inferred RIGHT JOINs using splat arguments for table names
  #
  # ```
  # query.joins(:users, :posts)
  # ```
  def right_joins(*tables_to_join : Symbol)
    tables_array = tables_to_join.map { |name| {name, name} }
    join_inferred(tables_array, Expression::JoinType::RIGHT)
  end
end
