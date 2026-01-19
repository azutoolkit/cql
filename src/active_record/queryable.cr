require "../query"
require "json"
require "digest/md5"
require "./query_builder"

module CQL
  module ActiveRecord
    # The Queryable module provides Active Record-style chainable query methods
    # that integrate with the CQL::Query system. It implements the Active Record
    # query interface while maintaining type safety and performance.
    #
    # ## Features
    #
    # - Type-safe query building with compile-time checks
    # - Chainable query methods that return QueryBuilder instances
    # - Integration with existing CQL::Query functionality
    # - Support for eager loading and relationship queries
    # - Query caching and optimization
    # - Lazy evaluation for better performance
    #
    # ## Examples
    #
    # ```
    # class User < CQL::ActiveRecord::Model
    #   db_context AcmeDB, :users
    #
    #   # Basic queries
    #   User.where(active: true)
    #   User.select(:name, :email).where(age: 18..65)
    #   User.order(:created_at).limit(10)
    #
    #   # Complex queries with joins
    #   User.joins(:posts).where(posts: {published: true})
    #   User.left_joins(:profile).select(users: [:name], profile: [:bio])
    #
    #   # Aggregations
    #   User.count
    #   User.where(active: true).count
    #   User.group(:role).count
    #
    #   # Method chaining
    #   User.where(active: true)
    #       .order(:created_at)
    #       .limit(20)
    #       .offset(10)
    #       .all
    # ```
    module Queryable
      macro included
        # Create a new query builder for this model
        # - **@return** [QueryBuilder(T)] A new query builder instance
        #
        # **Example**
        # ```
        # User.query.where(active: true)
        # ```
        def self.query
          QueryBuilder({{@type.id}}).from_model({{@type.id}})
        end

        # Create a QueryBuilder and execute select on it
        # - **@param** columns [Symbol*] The columns to select
        # - **@return** [QueryBuilder(T)] The query builder instance
        def self.select(*columns : Symbol | String)
          query.select(*columns)
        end

        # Create a QueryBuilder and execute select with hash syntax
        # - **@param** fields [Hash] The fields to select using hash syntax
        # - **@return** [QueryBuilder(T)] The query builder instance
        def self.select(**fields)
          query.select(**fields)
        end

        # Create a QueryBuilder and execute where on it
        # - **@param** conditions [Hash] The conditions to filter by
        # - **@return** [QueryBuilder(T)] The query builder instance
        def self.where(conditions : Hash(String | Symbol, DB::Any | Array(DB::Any)))
          query.where(conditions)
        end

        # Create a QueryBuilder and execute where with hash syntax
        # - **@param** fields [Hash] The conditions using hash syntax
        # - **@return** [QueryBuilder(T)] The query builder instance
        def self.where(**fields)
          query.where(**fields)
        end

        # Create a QueryBuilder and execute where with block
        # - **@yield** [FilterBuilder] The block to build conditions
        # - **@return** [QueryBuilder(T)] The query builder instance
        def self.where(&block : -> Expression::ConditionBuilder)
          query.where(&block)
        end

        def self.where_like(field : Symbol | String, pattern : String)
          query.where_like(field, pattern)
        end

        # Create a QueryBuilder and execute order on it
        # - **@param** fields [Symbol*] The fields to order by
        # - **@return** [QueryBuilder(T)] The query builder instance
        def self.order(*fields : Symbol | String)
          query.order(*fields)
        end

        # Create a QueryBuilder and execute order with hash syntax
        # - **@param** fields [Hash] The fields and directions to order by
        # - **@return** [QueryBuilder(T)] The query builder instance
        def self.order(**fields)
          query.order(**fields)
        end

        # Create a QueryBuilder and execute limit on it
        # - **@param** value [Int32] The limit value
        # - **@return** [QueryBuilder(T)] The query builder instance
        def self.limit(value : Int32)
          query.limit(value)
        end

        # Create a QueryBuilder and execute offset on it
        # - **@param** value [Int32] The offset value
        # - **@return** [QueryBuilder(T)] The query builder instance
        def self.offset(value : Int32)
          query.offset(value)
        end

        # Create a QueryBuilder and execute group on it
        # - **@param** columns [Symbol*] The columns to group by
        # - **@return** [QueryBuilder(T)] The query builder instance
        def self.group(*columns : Symbol | String)
          query.group(*columns)
        end

        # Create a QueryBuilder and execute group_by on it (alias for group)
        # - **@param** columns [Symbol*] The columns to group by
        # - **@return** [QueryBuilder(T)] The query builder instance
        def self.group_by(*columns : Symbol | String)
          query.group(*columns)
        end

        # Create a QueryBuilder and execute having on it
        # - **@yield** [HavingBuilder] The block to build having conditions
        # - **@return** [QueryBuilder(T)] The query builder instance
        def self.having(&block)
          query.having(&block)
        end

        # Create a QueryBuilder and execute distinct on it
        # - **@return** [QueryBuilder(T)] The query builder instance
        def self.distinct
          query.distinct
        end

        # Create a QueryBuilder with associations to preload (eager load).
        # Preloading fetches associated records in batch queries to avoid N+1 queries.
        # - **@param** associations [Symbol*] The association names to preload
        # - **@return** [QueryBuilder(T)] The query builder instance with preload configured
        #
        # **Example**
        # ```
        # User.preload(:posts).all           # Preload single association
        # User.preload(:posts, :comments).all # Preload multiple associations
        # User.where(active: true).preload(:posts).all # Chain with where
        # ```
        def self.preload(*associations : Symbol)
          query.preload(*associations)
        end

        # Execute automatic inner join
        # - **@param** table_or_alias [Symbol | Hash] The table or alias mapping
        # - **@return** [QueryBuilder(T)] The query builder instance
        def self.join(table_or_alias : Symbol)
          query.join(table_or_alias)
        end

        # Execute automatic left join
        # - **@param** table_or_alias [Symbol | Hash] The table or alias mapping
        # - **@return** [QueryBuilder(T)] The query builder instance
        def self.left(table_or_alias : Symbol)
          query.left(table_or_alias)
        end

        # Execute automatic right join
        # - **@param** table_or_alias [Symbol | Hash] The table or alias mapping
        # - **@return** [QueryBuilder(T)] The query builder instance
        def self.right(table_or_alias : Symbol)
          query.right(table_or_alias)
        end

        # Execute inner join with block conditions
        # - **@param** table_or_alias [Symbol | Hash] The table or alias mapping
        # - **@yield** [FilterBuilder] The block to build join conditions
        # - **@return** [QueryBuilder(T)] The query builder instance
        def self.join(table_or_alias : Symbol, &block : Expression::FilterBuilder -> Expression::ConditionBuilder)
          query.join(table_or_alias, &block)
        end

        # Execute left join with block conditions
        # - **@param** table_or_alias [Symbol | Hash] The table or alias mapping
        # - **@yield** [FilterBuilder] The block to build join conditions
        # - **@return** [QueryBuilder(T)] The query builder instance
        def self.left(table_or_alias : Symbol, &block : Expression::FilterBuilder -> Expression::ConditionBuilder)
          query.left(table_or_alias, &block)
        end

        # Execute right join with block conditions
        # - **@param** table_or_alias [Symbol | Hash] The table or alias mapping
        # - **@yield** [FilterBuilder] The block to build join conditions
        # - **@return** [QueryBuilder(T)] The query builder instance
        def self.right(table_or_alias : Symbol, &block : Expression::FilterBuilder -> Expression::ConditionBuilder)
          query.right(table_or_alias, &block)
        end

        # Execute automatic inner join using named arguments for table aliasing
        # - **@param** tables_with_aliases [NamedTuple] Table name => alias
        # - **@return** [QueryBuilder(T)] The query builder instance
        def self.join(**tables_with_aliases)
          query.join(**tables_with_aliases)
        end

        # Execute automatic left join using named arguments for table aliasing
        # - **@param** tables_with_aliases [NamedTuple] Table name => alias
        # - **@return** [QueryBuilder(T)] The query builder instance
        def self.left(**tables_with_aliases)
          query.left(**tables_with_aliases)
        end

        # Execute automatic right join using named arguments for table aliasing
        # - **@param** tables_with_aliases [NamedTuple] Table name => alias
        # - **@return** [QueryBuilder(T)] The query builder instance
        def self.right(**tables_with_aliases)
          query.right(**tables_with_aliases)
        end

        # Execute count aggregate
        # - **@param** column [Symbol] The column to count (defaults to *)
        # - **@return** [Int64] The count result
        def self.count(column : Symbol = :*)
          result = query.count(column)
          result = result.get(Int64 | Int32 | Nil) if result.responds_to?(:get)
          result || 0
        end

        # Execute sum aggregate
        # - **@param** column [Symbol] The column to sum
        # - **@return** [Float64 | Int64] The sum result
        def self.sum(column : Symbol)
          result = query.sum(column)
          result = result.get(Int64 | Float64 | Int32 | Nil) if result.responds_to?(:get)
          result || 0
        end

        # Execute avg aggregate
        # - **@param** column [Symbol] The column to average
        # - **@return** [Float64] The average result
        def self.avg(column : Symbol)
          result = query.avg(column)
          result = result.get(Float64 | Int64 | Int32 | Nil) if result.responds_to?(:get)
          result || 0.0
        end

        # Execute min aggregate
        # - **@param** column [Symbol] The column to find minimum
        # - **@return** [DB::Any] The minimum result
        def self.min(column : Symbol)
          result = query.min(column)
          result = result.get(Int64 | Float64 | Int32 | Nil) if result.responds_to?(:get)
          result || 0
        end

        # Execute max aggregate
        # - **@param** column [Symbol] The column to find maximum
        # - **@return** [DB::Any] The maximum result
        def self.max(column : Symbol)
          result = query.max(column)
          result = result.get(Int64 | Float64 | Int32 | Nil) if result.responds_to?(:get)
          result || 0
        end

        # Find all records matching the current query
        # - **@return** [Array(T)] Array of model instances
        def self.all
          query.all
        end

        # Find first record matching the current query
        # - **@return** [T?] First model instance or nil
        def self.first
          query.first
        end

        # Find first record matching the current query, raises if not found
        # - **@return** [T] First model instance
        def self.first!
          query.first!
        end

        # Find last record matching the current query
        # - **@return** [T?] Last model instance or nil
        def self.last
          query.last
        end

        # Find last record matching the current query, raises if not found
        # - **@return** [T] Last model instance
        def self.last!
          query.last!
        end

        # Iterate over each record matching the current query
        # - **@yield** [T] Each model instance
        def self.each(&block : {{@type.id}} ->)
          query.each(&block)
        end

        # Check if any records exist matching the current query
        # - **@return** [Bool] True if records exist
        def self.exists? : Bool
          count_result = count
          count_result > 0
        end

        # Check if no records exist matching the current query
        # - **@return** [Bool] True if no records exist
        def self.empty?
          !exists?
        end

        # Find record by primary key
        # - **@param** id [Int32 | Int64 | UUID | String] The primary key value
        # - **@return** [T?] The record or nil if not found
        def self.find(id)
          {% if Pk == UUID %}
            # Convert UUID to string for query compatibility
            query.where(id: id.to_s).first
          {% else %}
            query.where(id: id).first
          {% end %}
        end

        def self.find?(id)
          {% if Pk == UUID %}
            query.where(id: id.to_s).first
          {% else %}
            query.where(id: id).first
          {% end %}
        end

        # Find record by primary key, raises if not found
        # - **@param** id [Int32 | Int64 | UUID | String] The primary key value
        # - **@return** [T] The record
        def self.find!(id)
          result = find(id)
          raise DB::NoResultsError.new("No records found with id=#{id}") unless result
          result
        end

        # Find record by attributes
        # - **@param** conditions [Hash] The conditions to search by
        # - **@return** [T?] The first matching record or nil
        def self.find_by(conditions : Hash(String | Symbol, DB::Any | Array(DB::Any)))
          query.where(conditions).first
        end

        # Find record by attributes with hash syntax
        # - **@param** fields [Hash] The conditions using hash syntax
        # - **@return** [T?] The first matching record or nil
        def self.find_by(**fields)
          query.where(**fields).first
        end

        # Find record by attributes, raises if not found
        # - **@param** conditions [Hash] The conditions to search by
        # - **@return** [T] The first matching record
        def self.find_by!(conditions : Hash(String | Symbol, DB::Any | Array(DB::Any)))
          result = find_by(conditions)
          raise DB::NoResultsError.new("No records found with conditions: #{conditions}") unless result
          result
        end

        # Find record by attributes, raises if not found (hash syntax)
        # - **@param** fields [Hash] The conditions using hash syntax
        # - **@return** [T] The first matching record
        def self.find_by!(**fields)
          result = find_by(**fields)
          raise DB::NoResultsError.new("No records found with conditions: #{fields}") unless result
          result
        end

        # Check if records exist with given conditions
        # - **@param** conditions [Hash] The conditions to check
        # - **@return** [Bool] True if records exist
        def self.exists?(conditions : Hash(String | Symbol, DB::Any | Array(DB::Any)))
          query.where(conditions).exists?
        end

        # Check if records exist with given conditions (hash syntax)
        # - **@param** fields [Hash] The conditions using hash syntax
        # - **@return** [Bool] True if records exist
        def self.exists?(**fields)
          query.where(**fields).exists?
        end

        # Batch processing - iterate over records in batches
        # - **@param** batch_size [Int32] Size of each batch
        # - **@yield** [T] Each record
        def self.find_each(batch_size : Int32 = 1000, &block : {{@type.id}} ->)
          query.find_each(batch_size, &block)
        end

        # Process records in batches
        # - **@param** batch_size [Int32] Size of each batch
        # - **@yield** [Array(T)] Each batch of records
        def self.find_in_batches(batch_size : Int32 = 1000, &block : Array({{@type.id}}) ->)
          query.find_in_batches(batch_size, &block)
        end

        # Extract column values from all matching records
        # - **@param** columns [Symbol*] The columns to extract
        # - **@return** [Array] Array of values or arrays if multiple columns
        def self.pluck(*columns : Symbol, as as_kind = DB::Any)
          query.pluck(*columns, as: as_kind)
        end

        # Extract a single column value from the first matching record
        # - **@param** column [Symbol] The column to extract
        # - **@return** [DB::Any?] The value or nil if no records
        def self.pick(column : Symbol, as as_kind = DB::Any)
          query.pick(column, as: as_kind)
        end

        # Get array of primary key values
        # - **@return** [Array] Array of primary key values
        def self.ids(as as_kind = Int64)
          query.ids(as: as_kind)
        end

        # Get maximum value of a column
        # - **@param** column [Symbol] The column to find maximum
        # - **@return** [DB::Any?] The maximum value or nil
        def self.maximum(column : Symbol)
          query.max(column)
        end

        # Get minimum value of a column
        # - **@param** column [Symbol] The column to find minimum
        # - **@return** [DB::Any?] The minimum value or nil
        def self.minimum(column : Symbol)
          query.min(column)
        end

        # Get average value of a column
        # - **@param** column [Symbol] The column to average
        # - **@return** [Float64?] The average value or nil
        def self.average(column : Symbol)
          query.avg(column)
        end

        # Get distinct values for a column
        # - **@param** column [Symbol] The column to get distinct values
        # - **@return** [Array(DB::Any)] Array of distinct values
        def self.distinct(column : Symbol, as as_kind = DB::Any)
          query.distinct.select(column).all(as: as_kind)
        end

        # Delete all records matching current scope
        # - **@return** [Int64] Number of deleted records
        def self.delete_all
          # Use CQL::Delete to delete all records matching the query
          delete_query = CQL::Delete
            .new({{@type.id}}.schema)
            .from({{@type.id}}.table)
          # Add where condition if it exists
          if where_condition = query.query.where
            delete_query.where(where_condition)
          end

          result = delete_query.commit
          result.rows_affected
        end

        # Replace existing order clause
        # - **@param** fields [Symbol*] The fields to order by
        # - **@return** [QueryBuilder(T)] A new query builder instance
        def self.reorder(*fields : Symbol | String)
          query.reorder(*fields)
        end

        # Replace existing order clause with hash syntax
        # - **@param** fields [Hash] The fields and directions to order by
        # - **@return** [QueryBuilder(T)] A new query builder instance
        def self.reorder(**fields)
          query.reorder(**fields)
        end

        # Reverse the order of the query
        # - **@return** [QueryBuilder(T)] A new query builder instance
        def self.reverse_order
          query.reverse_order
        end

        # Remove specific scopes from the query
        # - **@param** scopes [Symbol*] The scopes to remove
        # - **@return** [QueryBuilder(T)] A new query builder instance
        def self.unscope(*scopes : Symbol)
          query.unscope(*scopes)
        end



        # Return a QueryBuilder that will return no results
        # - **@return** [QueryBuilder(T)] A query builder that returns no results
        def self.none
          query.none
        end

        # Check if any records exist
        # - **@return** [Bool] True if any records exist
        def self.any?
          query.any?
        end

        # Check if many records exist (more than one)
        # - **@return** [Bool] True if more than one record exists
        def self.many?
          query.many?
        end

        # Get the count of records
        # - **@return** [Int64] The number of records
        def self.size
          query.size
        end
      end
    end
  end
end
