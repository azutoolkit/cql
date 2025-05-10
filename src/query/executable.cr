# Handles query execution methods.
module Executable
  # Executes the query and returns all records.
  #
  # **Example** Executing the query and returning all records
  #
  # ```
  # query.all(User)
  # => [{"name" => "John", "age" => 30}]
  # ```
  def all(as as_kind)
    query, params = to_sql

    @schema.exec_query do |conn|
      as_kind.from_rs(conn.query(query, args: params))
    end
  end

  # Executes the query and returns all records, raising an error if nil.
  #
  # **Example** Executing the query and returning all records, raising an error if nil
  #
  # ```
  # query.all!(User)
  # => [{"name" => "John", "age" => 30}]
  # ```
  def all!(as as_kind)
    all(as_kind).not_nil!
  end

  # Executes the query and returns the first record.
  #
  # **Example** Executing the query and returning the first record
  #
  # ```
  # query.first(User)
  # => {"name" => "John", "age" => 30}
  # ```
  def first(as as_kind)
    query, params = to_sql
    @schema.exec_query do |conn|
      conn.query_one(query, args: params, as: as_kind)
    end
  end

  # Executes the query and returns the first record, raising an error if nil.
  #
  # **Example** Executing the query and returning the first record, raising an error if nil
  #
  # ```
  # query.first!(User)
  # => {"name" => "John", "age" => 30}
  # ```
  def first!(as as_kind)
    first(as_kind).not_nil!
  end

  # Executes the query and returns a scalar value.
  #
  # **Example** Executing the query and returning a scalar value
  #
  # ```
  # query.get(Int32)
  # => 100
  # ```
  def get(as as_kind)
    query, params = to_sql
    @schema.exec_query do |conn|
      conn.scalar(query, args: params, as: as_kind)
    end
  end

  # Iterates over each result and yields it to the provided block.
  #
  # **Example** Iterating over each result and yielding it to the provided block
  #
  # ```
  # query.each(User) do |user|
  #   puts user.name
  # end
  # ```
  def each(as as_kind, &)
    query, params = to_sql
    @schema.exec_query do |conn|
      conn.query_each(query, args: params) do |result|
        yield as_kind.from_rs(result)
      end
    end
  end
end
