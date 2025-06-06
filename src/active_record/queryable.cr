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

      # Active Record Query Builder - handles all query building logic
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
            @query.select(:id).limit(1).first(@model_class)
          end
          result != nil
        end

        # Chainable query methods
        def where(**fields) : QueryBuilder(T)
          QueryBuilder(T).new(@query.where(**fields), @cache_enabled)
        end

        def where(conditions : Hash(Symbol, DB::Any)) : QueryBuilder(T)
          QueryBuilder(T).new(@query.where(conditions), @cache_enabled)
        end

        # Support for block-based where clauses
        def where(& : -> _) : QueryBuilder(T)
          QueryBuilder(T).new(@query.where { yield }, @cache_enabled)
        end

        # Support for LIKE conditions
        def where_like(field : Symbol | String, pattern : String) : QueryBuilder(T)
          QueryBuilder(T).new(@query.where_like(field, pattern), @cache_enabled)
        end

        def order(**fields) : QueryBuilder(T)
          QueryBuilder(T).new(@query.order(**fields), @cache_enabled)
        end

        def limit(limit : Int32) : QueryBuilder(T)
          QueryBuilder(T).new(@query.limit(limit), @cache_enabled)
        end

        def offset(offset : Int32) : QueryBuilder(T)
          QueryBuilder(T).new(@query.offset(offset), @cache_enabled)
        end

        def select(*fields) : QueryBuilder(T)
          QueryBuilder(T).new(@query.select(*fields), @cache_enabled)
        end

        def group_by(*fields) : QueryBuilder(T)
          QueryBuilder(T).new(@query.group(*fields), @cache_enabled)
        end

        def join(table : Symbol, on) : QueryBuilder(T)
          on_hash = normalize_join_condition(on)
          QueryBuilder(T).new(@query.join(table, on_hash), @cache_enabled)
        end

        # Support for inner join with block syntax
        def inner(table : Symbol, &) : QueryBuilder(T)
          QueryBuilder(T).new(@query.inner(table) { yield }, @cache_enabled)
        end

        # Support for inner join with hash condition
        def inner(table : Symbol, on) : QueryBuilder(T)
          on_hash = normalize_join_condition(on)
          QueryBuilder(T).new(@query.inner(table, on_hash), @cache_enabled)
        end

        # Disable caching for this query chain
        def no_cache : QueryBuilder(T)
          QueryBuilder(T).new(@query, false)
        end

        # Helper method to normalize join conditions to Hash
        private def normalize_join_condition(on)
          case on
          when Hash
            on
          when NamedTuple
            on.to_h
          else
            # This should handle any other case that can be converted to Hash
            on.responds_to?(:to_h) ? on.to_h : on.as(Hash)
          end
        end

        # Aggregate functions - return computed values, not model instances
        def sum(column : Symbol)
          ErrorHandler.handle_query_errors do
            @query.sum(column).first(Float64)
          end
        end

        def avg(column : Symbol)
          ErrorHandler.handle_query_errors do
            @query.avg(column).first(Float64)
          end
        end

        def minimum(column : Symbol)
          ErrorHandler.handle_query_errors do
            @query.min(column).first(DB::Any)
          end
        end

        def maximum(column : Symbol)
          ErrorHandler.handle_query_errors do
            @query.max(column).first(DB::Any)
          end
        end

        # Aliases for minimum/maximum
        def min(column : Symbol)
          minimum(column)
        end

        def max(column : Symbol)
          maximum(column)
        end

        # Query modifiers that return new QueryBuilder instances
        def distinct : QueryBuilder(T)
          QueryBuilder(T).new(@query.distinct, @cache_enabled)
        end

        def having(&block) : QueryBuilder(T)
          QueryBuilder(T).new(@query.having(&block), @cache_enabled)
        end

        # Different join types
        def inner_join(table : Symbol, on) : QueryBuilder(T)
          on_hash = normalize_join_condition(on)
          QueryBuilder(T).new(@query.inner(table, on_hash), @cache_enabled)
        end

        def inner_join(table : Symbol, &) : QueryBuilder(T)
          QueryBuilder(T).new(@query.inner(table) { yield }, @cache_enabled)
        end

        def left_join(table : Symbol, on) : QueryBuilder(T)
          on_hash = normalize_join_condition(on)
          QueryBuilder(T).new(@query.left(table, on_hash), @cache_enabled)
        end

        def left_join(table : Symbol, &) : QueryBuilder(T)
          QueryBuilder(T).new(@query.left(table) { yield }, @cache_enabled)
        end

        def right_join(table : Symbol, on) : QueryBuilder(T)
          on_hash = normalize_join_condition(on)
          QueryBuilder(T).new(@query.right(table, on_hash), @cache_enabled)
        end

        def right_join(table : Symbol, &) : QueryBuilder(T)
          QueryBuilder(T).new(@query.right(table) { yield }, @cache_enabled)
        end

        # Collection check methods
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
          QueryBuilder(T).new(@query.where("1 = 0").limit(0), @cache_enabled)
        end

        # Batch processing
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
        # Return a new query builder for the current table
        def self.query : QueryBuilder({{@type.id}})
          QueryBuilder({{@type.id}}).from_model({{@type.id}})
        end

        # Fetch all records of type T
        def self.all : Array({{@type.id}})
          query.all
        end

        # Find a record by ID, return nil if not found
        def self.find(id : Pk) : {{@type.id}}?
          query.where(id: id).first
        end

        def self.find?(id : Pk) : {{@type.id}}?
          find(id)
        end

        # Find a record by ID, raise an error if not found
        def self.find!(id : Pk) : {{@type.id}}
          query.where(id: id).first!
        end

        # Find a record by specific fields
        def self.find_by(**fields) : {{@type.id}}?
          query.where(**fields).limit(1).first
        end

        def self.find_by(attributes : Hash(Symbol, DB::Any)) : {{@type.id}}?
          query.where(attributes).limit(1).first
        end

        def self.find_by!(attributes : Hash(Symbol, DB::Any)) : {{@type.id}}
          query.where(attributes).limit(1).first!
        end

        # Find a record by specific fields, raise an error if not found
        def self.find_by!(**fields) : {{@type.id}}
          query.where(**fields).limit(1).first!
        end

        # Find all records matching specific fields
        def self.find_all_by(**fields) : Array({{@type.id}})
          query.where(**fields).all
        end

        # Count all records in the table
        def self.count : Int64
          query.count
        end

        # Check if records exist matching specific fields
        def self.exists?(**fields) : Bool
          query.where(**fields).exists?
        end

        # Fetch the first record in the table
        def self.first : {{@type.id}}?
          query.order(id: :asc).limit(1).first
        end

        # Fetch the last record in the table
        def self.last : {{@type.id}}?
          query.order(id: :desc).limit(1).first
        end

        # Start a chainable query with a where clause
        def self.where(**fields) : QueryBuilder({{@type.id}})
          query.where(**fields)
        end

        # Start a chainable query with a LIKE clause
        def self.where_like(field : Symbol | String, pattern : String) : QueryBuilder({{@type.id}})
          query.where_like(field, pattern)
        end

        # Start a chainable query with an order clause
        def self.order(**fields) : QueryBuilder({{@type.id}})
          query.order(**fields)
        end

        # Start a chainable query with a limit
        def self.limit(limit : Int32) : QueryBuilder({{@type.id}})
          query.limit(limit)
        end

        # Start a chainable query with an offset
        def self.offset(offset : Int32) : QueryBuilder({{@type.id}})
          query.offset(offset)
        end

        # Start a chainable query with a select clause
        def self.select(*fields) : QueryBuilder({{@type.id}})
          query.select(*fields)
        end

        # Start a chainable query with a group by clause
        def self.group_by(*fields) : QueryBuilder({{@type.id}})
          query.group_by(*fields)
        end

        # Start a chainable query with a join clause
        def self.join(table : Symbol, on) : QueryBuilder({{@type.id}})
          query.join(table, on)
        end

        # Different join types
        def self.inner_join(table : Symbol, on) : QueryBuilder({{@type.id}})
          query.inner_join(table, on)
        end

        def self.left_join(table : Symbol, on) : QueryBuilder({{@type.id}})
          query.left_join(table, on)
        end

        def self.right_join(table : Symbol, on) : QueryBuilder({{@type.id}})
          query.right_join(table, on)
        end

        # Query modifiers
        def self.distinct : QueryBuilder({{@type.id}})
          query.distinct
        end

        def self.none : QueryBuilder({{@type.id}})
          query.none
        end

        # Collection check methods
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

        # Aggregate functions
        def self.sum(column : Symbol)
          query.sum(column)
        end

        def self.avg(column : Symbol)
          query.avg(column)
        end

        def self.minimum(column : Symbol)
          query.minimum(column)
        end

        def self.maximum(column : Symbol)
          query.maximum(column)
        end

        def self.min(column : Symbol)
          query.min(column)
        end

        def self.max(column : Symbol)
          query.max(column)
        end

        # Batch processing
        def self.find_each(batch_size : Int32 = 1000, &block : {{@type.id}} -> Nil) : Nil
          query.find_each(batch_size, &block)
        end

        def self.find_in_batches(batch_size : Int32 = 1000, &block : Array({{@type.id}}) -> Nil) : Nil
          query.find_in_batches(batch_size, &block)
        end

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
