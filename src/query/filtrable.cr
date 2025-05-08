# Handles WHERE and HAVING clauses.
module Filterable
  # Adds a WHERE condition using a Hash.
  #
  # **Example** Adding a WHERE condition using a Hash
  #
  # ```
  # query.where(name: "John", age: 30)
  # => #<CQL::Query:0x00007f8000000000>
  # ```
  def where(hash : Hash(String | Symbol, DB::Any))
    # Convert Symbol keys to String
    string_keyed_hash = hash.transform_keys(&.to_s)
    new_condition = build_condition_from_hash(string_keyed_hash)
    merge_where_condition(new_condition)
    self
  end

  # Adds a WHERE condition using a block.
  #
  # **Example** Adding a WHERE condition using a block
  #
  # ```
  # query.where { name == "John" && age > 30 }
  # => #<CQL::Query:0x00007f8000000000>
  # ```
  def where(&)
    # Pass the String-keyed query_tables hash to FilterBuilder
    builder = Expression::FilterBuilder.new(@query_tables)
    # Capture the ConditionBuilder returned by the block
    condition_builder = with builder yield
    # Get the actual condition from the builder
    new_condition = condition_builder.as(Expression::ConditionBuilder).condition
    merge_where_condition(new_condition)
    self
  end

  # Adds a WHERE condition using keyword arguments.
  #
  # **Example** Adding a WHERE condition using keyword arguments
  #
  # ```
  # query.where(name: "John", age: 30)
  # => #<CQL::Query:0x00007f8000000000>
  # ```
  def where(**fields)
    new_condition = build_condition_from_hash(fields.to_h)
    merge_where_condition(new_condition)
    self
  end

  # Adds a HAVING condition using a block.
  #
  # **Example** Adding a HAVING condition using a block
  #
  # ```
  # query.having { name == "John" && age > 30 }
  # => #<CQL::Query:0x00007f8000000000>
  # ```
  def having(&)
    # Pass String-keyed query_tables to HavingBuilder
    builder = Expression::HavingBuilder.new(@query_tables)
    having_builder = with builder yield
    @having = Expression::Having.new(having_builder.condition)
    self
  end
end
