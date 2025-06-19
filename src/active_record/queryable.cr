require "../query"

module CQL
  module ActiveRecord
    # The Queryable module provides methods for querying Active Record models
    # with a chainable query interface. This allows for more readable and maintainable
    # query construction.
    #
    # ## Features
    #
    # - Chainable queries (where, order, limit, etc)
    # - Terminal operations (all, first, count, etc)
    # - Query caching for improved performance
    # - Consistent error handling
    # - Syntactic sugar for common queries
    #
    # ## Example
    #
    # ```
    # # Basic queries
    # User.all                                # => [User1, User2, ...]
    # User.find(1)                            # => User or nil
    # User.find!(1)                           # => User or raise
    # User.find_by(email: "test@example.com") # => User or nil
    #
    # # Chainable queries
    # User.where(active: true)
    #   .where(role: "admin")
    #   .order(created_at: :desc)
    #   .limit(10)
    #   .offset(20)
    #   .all # => [User1, User2, ...]
    #
    # # Aggregations
    # User.where(active: true).count # => 42
    #
    # # Joins
    # User.join(:posts, {id: :user_id})
    #   .where("posts.published": true)
    #   .all
    # ```
    module Queryable
      # Query cache for storing compiled queries
      class QueryCache
        @@cache = {} of String => CQL::Query

        def self.get(key : String) : CQL::Query?
          @@cache[key]?
        end

        def self.set(key : String, query : CQL::Query) : CQL::Query
          @@cache[key] = query
        end

        def self.clear
          @@cache.clear
        end

        def self.size
          @@cache.size
        end

        # Generate cache key from query components
        def self.generate_key(model_class : Class, method : String, params : Hash(Symbol, DB::Any)? = nil) : String
          params_str = params ? params.map { |k, v| "#{k}:#{v}" }.join(",") : ""
          "#{model_class}:#{method}:#{params_str}"
        end
      end

      # Centralized error handling module
      module ErrorHandler
        extend self

        def handle_query_errors(& : -> T) : T? forall T
          yield
        rescue DB::NoResultsError
          nil
        rescue e : CQL::Schema::ConnectionError
          if e.message.to_s.includes?("no results")
            nil
          else
            raise e
          end
        end

        def handle_query_errors!(& : -> T) : T forall T
          yield
        rescue e : CQL::Schema::ConnectionError
          if e.message.to_s.includes?("no results")
            raise DB::NoResultsError.new("Record not found")
          else
            raise e
          end
        end
      end

      # Active Record Query Builder - delegates to CQL::Query while adding model-specific functionality
      class QueryBuilder(T)
        getter model_class : T.class = T
        getter query : CQL::Query
        getter cache_enabled : Bool = true

        def initialize(@query : CQL::Query, @cache_enabled : Bool = true)
        end

        # Create a new query builder from model
        def self.from_model(model_class : T.class) : QueryBuilder(T)
          query = CQL::Query.new(model_class.schema).from(model_class.table)
          new(query)
        end

        # === Terminal Operations - Execute queries and return results ===

        # Execute query and return all records
        def all : Array(T)
          cache_key = generate_cache_key("all")
          if @cache_enabled && (cached_query = QueryCache.get(cache_key))
            cached_query.all(@model_class)
          else
            result_query = @cache_enabled ? QueryCache.set(cache_key, @query) : @query
            result_query.all(@model_class)
          end
        end

        # Execute query and return first record
        def first : T?
          ErrorHandler.handle_query_errors do
            execute_single_record_query("first", &.first(@model_class))
          end
        end

        # Execute query and return first record, raise if not found
        def first! : T
          ErrorHandler.handle_query_errors! do
            execute_single_record_query("first!", &.first!(@model_class))
          end
        end

        # Count records
        def count : Int64
          cache_key = generate_cache_key("count")
          if @cache_enabled && (cached_query = QueryCache.get(cache_key))
            cached_query.count(:id).first!(Int64)
          else
            count_query = @query.count(:id)
            @cache_enabled ? QueryCache.set(cache_key, count_query) : count_query
            count_query.first!(Int64)
          end
        end

        # Check if records exist
        def exists? : Bool
          result = ErrorHandler.handle_query_errors do
            @query.count(:id).limit(1).first(Int64)
          end
          (result || 0) > 0
        end

        # === Chainable Query Methods - Create new QueryBuilder with updated query ===

        # Helper method to create a new QueryBuilder with the same query (for chaining)
        private def chain_query : QueryBuilder(T)
          QueryBuilder(T).new(@query, @cache_enabled)
        end

        # Methods that can work with or without blocks
        def where(*args, **kwargs)
          cloned_query = @query.dup
          cloned_query.where(*args, **kwargs)
          QueryBuilder(T).new(cloned_query, @cache_enabled)
        end

        def where(*args, **kwargs, &block)
          cloned_query = @query.dup
          cloned_query.where(*args, **kwargs, &block)
          QueryBuilder(T).new(cloned_query, @cache_enabled)
        end

        def having(*args, **kwargs)
          cloned_query = @query.dup
          cloned_query.having(*args, **kwargs)
          QueryBuilder(T).new(cloned_query, @cache_enabled)
        end

        def having(*args, **kwargs, &block)
          cloned_query = @query.dup
          cloned_query.having(*args, **kwargs, &block)
          QueryBuilder(T).new(cloned_query, @cache_enabled)
        end

        # Methods that don't typically use blocks
        {% for method in %w[where_like order limit offset select distinct] %}
          def {{method.id}}(*args, **kwargs)
            cloned_query = @query.dup
            cloned_query.{{method.id}}(*args, **kwargs)
            QueryBuilder(T).new(cloned_query, @cache_enabled)
          end
        {% end %}

        # Special case for group_by (maps to group method in CQL::Query)
        def group_by(*args, **kwargs)
          cloned_query = @query.dup
          cloned_query.group(*args, **kwargs)
          QueryBuilder(T).new(cloned_query, @cache_enabled)
        end

        # === Join Methods - Create new QueryBuilder with updated query ===

        # Basic join methods that exist in CQL::Query
        {% for join_method in %w[join inner left right] %}
          def {{join_method.id}}(*args, **kwargs)
            cloned_query = @query.dup
            cloned_query.{{join_method.id}}(*args, **kwargs)
            QueryBuilder(T).new(cloned_query, @cache_enabled)
          end

          def {{join_method.id}}(*args, **kwargs, &block)
            cloned_query = @query.dup
            cloned_query.{{join_method.id}}(*args, **kwargs, &block)
            QueryBuilder(T).new(cloned_query, @cache_enabled)
          end
        {% end %}

        # Alias methods for more explicit naming
        def inner_join(*args, **kwargs, &block : Expression::FilterBuilder -> _)
          cloned_query = @query.dup
          cloned_query.inner(*args, **kwargs, &block)
          QueryBuilder(T).new(cloned_query, @cache_enabled)
        end

        def left_join(*args, **kwargs, &block : Expression::FilterBuilder -> _)
          cloned_query = @query.dup
          cloned_query.left(*args, **kwargs, &block)
          QueryBuilder(T).new(cloned_query, @cache_enabled)
        end

        def right_join(*args, **kwargs, &block : Expression::FilterBuilder -> _)
          cloned_query = @query.dup
          cloned_query.right(*args, **kwargs, &block)
          QueryBuilder(T).new(cloned_query, @cache_enabled)
        end

        # === Aggregate Functions - Create query with aggregates ===

        # Basic aggregate methods that exist in CQL::Query
        {% for agg_method in %w[sum avg min max] %}
          def {{agg_method.id}}(column : Symbol)
            ErrorHandler.handle_query_errors do
              cloned_query = @query.dup
              cloned_query.{{agg_method.id}}(column).first(DB::Any)
            end
          end
        {% end %}

        # Alias methods for more explicit naming
        def minimum(column : Symbol)
          min(column)
        end

        def maximum(column : Symbol)
          max(column)
        end

        # Get average value of column
        def average(column : Symbol)
          avg(column)
        end

        # === Column Extraction Methods ===

        # Extract specific column values as an array
        def pluck(column : Symbol) : Array(DB::Any)
          ErrorHandler.handle_query_errors do
            cloned_query = @query.dup
            cloned_query.select(column).all(DB::Any)
          end
        end

        # Extract multiple column values as array of tuples
        def pluck(*columns : Symbol) : Array(Array(DB::Any))
          ErrorHandler.handle_query_errors do
            cloned_query = @query.dup
            cloned_query.select(*columns).all(Array(DB::Any))
          end
        end

        # Pick single value from first record
        def pick(column : Symbol) : DB::Any?
          ErrorHandler.handle_query_errors do
            cloned_query = @query.dup
            cloned_query.select(column).limit(1).first(DB::Any)
          end
        end

        # Get array of primary keys
        def ids : Array(Pk)
          ErrorHandler.handle_query_errors do
            cloned_query = @query.dup
            cloned_query.select(:id).all(Pk)
          end
        end

        # Get distinct values for a column
        def distinct(column : Symbol) : Array(DB::Any)
          ErrorHandler.handle_query_errors do
            cloned_query = @query.dup
            cloned_query.select(column).distinct.all(DB::Any)
          end
        end

        # === Query Modification Methods ===

        # Replace existing order clause
        def reorder(*args, **kwargs) : QueryBuilder(T)
          cloned_query = @query.dup
          # Clear existing order and set new one
          cloned_query.order(*args, **kwargs)
          QueryBuilder(T).new(cloned_query, @cache_enabled)
        end

        # Reverse existing order
        def reverse_order : QueryBuilder(T)
          cloned_query = @query.dup
          # This would need to be implemented in CQL::Query to reverse the order
          # For now, we'll create a new query without order and let the user set it
          QueryBuilder(T).new(cloned_query, @cache_enabled)
        end

        # Remove specific query conditions
        def unscope(*conditions : Symbol) : QueryBuilder(T)
          cloned_query = @query.dup
          # This would need to be implemented in CQL::Query to remove specific conditions
          # For now, we'll return the current query
          QueryBuilder(T).new(cloned_query, @cache_enabled)
        end

        # === Collection Check Methods ===

        def empty? : Bool
          count == 0
        end

        def any? : Bool
          exists?
        end

        def many? : Bool
          count > 1
        end

        def size : Int64
          count
        end

        # None - returns empty relation
        def none : QueryBuilder(T)
          # Create a query that will never return results by using an impossible condition
          QueryBuilder(T).new(@query.limit(0), @cache_enabled)
        end

        # Disable caching for this query chain
        def no_cache : QueryBuilder(T)
          QueryBuilder(T).new(@query, false)
        end

        # === Batch Processing ===

        def find_each(batch_size : Int32 = 1000, &block : T -> Nil) : Nil
          offset_value = 0
          loop do
            batch = limit(batch_size).offset(offset_value).all
            break if batch.empty?

            batch.each { |record| yield record }
            offset_value += batch_size
            break if batch.size < batch_size
          end
        end

        def find_in_batches(batch_size : Int32 = 1000, &block : Array(T) -> Nil) : Nil
          offset_value = 0
          loop do
            batch = limit(batch_size).offset(offset_value).all
            break if batch.empty?

            yield batch
            offset_value += batch_size
            break if batch.size < batch_size
          end
        end

        # === SQL Generation ===

        def to_sql
          @query.to_sql
        end

        # === Private Helper Methods ===

        private def execute_single_record_query(method : String, &block : CQL::Query -> T)
          cache_key = generate_cache_key(method)
          if @cache_enabled && (cached_query = QueryCache.get(cache_key))
            yield cached_query
          else
            result_query = @cache_enabled ? QueryCache.set(cache_key, @query) : @query
            yield result_query
          end
        end

        private def generate_cache_key(method : String) : String
          # Generate a simple cache key based on SQL
          sql_result = @query.to_sql
          sql = sql_result[0].as(String)
          params = sql_result[1].as(Array(DB::Any))
          params_str = params.map(&.to_s).join(",")
          "#{@model_class}:#{method}:#{sql}:#{params_str}"
        end
      end

      macro included
        # Return a raw CQL::Query for the current table
        def self.query : CQL::Query
          CQL::Query.new({{@type.id}}.schema).from({{@type.id}}.table)
        end

        # Return a new query builder for the current table (internal method)
        def self.query_builder : QueryBuilder({{@type.id}})
          QueryBuilder({{@type.id}}).from_model({{@type.id}})
        end

        # === Terminal Operations ===

        # Fetch all records of type T
        def self.all : Array({{@type.id}})
          query_builder.all
        end

        # Find a record by ID, return nil if not found
        def self.find(id : Pk) : {{@type.id}}?
          query_builder.where(id: id).first
        end

        def self.find?(id : Pk) : {{@type.id}}?
          find(id)
        end

        # Find a record by ID, raise an error if not found
        def self.find!(id : Pk) : {{@type.id}}
          query_builder.where(id: id).first!
        end

        # Find a record by specific fields
        def self.find_by(**fields) : {{@type.id}}?
          query_builder.where(**fields).limit(1).first
        end

        def self.find_by(attributes : Hash(Symbol, DB::Any)) : {{@type.id}}?
          query_builder.where(attributes).limit(1).first
        end

        def self.find_by!(attributes : Hash(Symbol, DB::Any)) : {{@type.id}}
          query_builder.where(attributes).limit(1).first!
        end

        # Find a record by specific fields, raise an error if not found
        def self.find_by!(**fields) : {{@type.id}}
          query_builder.where(**fields).limit(1).first!
        end

        # Find all records matching specific fields
        def self.find_all_by(**fields) : Array({{@type.id}})
          query_builder.where(**fields).all
        end

        # Count all records in the table
        def self.count : Int64
          query_builder.count
        end

        # Check if records exist matching specific fields
        def self.exists?(**fields) : Bool
          query_builder.where(**fields).exists?
        end

        # Fetch the first record in the table
        def self.first : {{@type.id}}?
          query_builder.order(id: :asc).limit(1).first
        end

        # Fetch the last record in the table
        def self.last : {{@type.id}}?
          query_builder.order(id: :desc).limit(1).first
        end

        # === Chainable Query Starters ===

        # Methods that can work with or without blocks
        {% for method in %w[where having] %}
          def self.{{method.id}}(*args, **kwargs) : QueryBuilder({{@type.id}})
            query_builder.{{method.id}}(*args, **kwargs)
          end

          def self.{{method.id}}(*args, **kwargs, &block) : QueryBuilder({{@type.id}})
            query_builder.{{method.id}}(*args, **kwargs, &block)
          end
        {% end %}

        # Join methods that can work with or without blocks
        {% for method in %w[join inner left right inner_join left_join right_join] %}
          def self.{{method.id}}(*args, **kwargs) : QueryBuilder({{@type.id}})
            query_builder.{{method.id}}(*args, **kwargs)
          end

          def self.{{method.id}}(*args, **kwargs, &block : Expression::FilterBuilder -> _) : QueryBuilder({{@type.id}})
            query_builder.{{method.id}}(*args, **kwargs, &block)
          end
        {% end %}

        # Methods that don't typically use blocks
        {% for method in %w[where_like order limit offset select group_by distinct none] %}
          def self.{{method.id}}(*args, **kwargs) : QueryBuilder({{@type.id}})
            query_builder.{{method.id}}(*args, **kwargs)
          end
        {% end %}

        # === Collection Check Methods ===

        def self.empty? : Bool
          count == 0
        end

        def self.any? : Bool
          exists?
        end

        def self.many? : Bool
          count > 1
        end

        def self.size : Int64
          count
        end

        # === Aggregate Functions ===

        {% for agg_method in %w[sum avg minimum maximum min max average] %}
          def self.{{agg_method.id}}(column : Symbol)
            query_builder.{{agg_method.id}}(column)
          end
        {% end %}

        # === Column Extraction Methods ===

        # Extract specific column values as an array
        def self.pluck(column : Symbol) : Array(DB::Any)
          query_builder.pluck(column)
        end

        # Extract multiple column values as array of tuples
        def self.pluck(*columns : Symbol) : Array(Array(DB::Any))
          query_builder.pluck(*columns)
        end

        # Pick single value from first record
        def self.pick(column : Symbol) : DB::Any?
          query_builder.pick(column)
        end

        # Get array of primary keys
        def self.ids : Array(Pk)
          query_builder.ids
        end

        # Get distinct values for a column
        def self.distinct(column : Symbol) : Array(DB::Any)
          query_builder.distinct(column)
        end

        # === Query Modification Methods ===

        # Replace existing order clause
        def self.reorder(*args, **kwargs) : QueryBuilder({{@type.id}})
          query_builder.reorder(*args, **kwargs)
        end

        # Reverse existing order
        def self.reverse_order : QueryBuilder({{@type.id}})
          query_builder.reverse_order
        end

        # Remove specific query conditions
        def self.unscope(*conditions : Symbol) : QueryBuilder({{@type.id}})
          query_builder.unscope(*conditions)
        end

        # === Batch Processing ===

        def self.find_each(batch_size : Int32 = 1000, &block : {{@type.id}} -> Nil) : Nil
          query_builder.find_each(batch_size, &block)
        end

        def self.find_in_batches(batch_size : Int32 = 1000, &block : Array({{@type.id}}) -> Nil) : Nil
          query_builder.find_in_batches(batch_size, &block)
        end

        # === Cache Management ===

        # Get query cache statistics
        def self.cache_stats : NamedTuple(size: Int32)
          {size: QueryCache.size}
        end

        # Clear query cache
        def self.clear_cache
          QueryCache.clear
        end
      end

      macro create_scope_method(name_ident, scope_proc_code)
        def {{name_ident.id}}(*args) : QueryBuilder({{@type.id}})
          # Execute the scope logic
          scope_result = ({{scope_proc_code}}).call(*args)

          # Handle different return types from scope
          case scope_result
          when CQL::Query
            QueryBuilder({{@type.id}}).new(scope_result.merge(@query), @cache_enabled)
          when QueryBuilder({{@type.id}})
            QueryBuilder({{@type.id}}).new(scope_result.query.merge(@query), @cache_enabled)
          else
            raise "Scope '{{name_ident.id}}' must return a CQL::Query or QueryBuilder({{@type.id}})"
          end
        end
      end
    end
  end
end
