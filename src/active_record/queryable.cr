require "../query"
require "json"
require "digest/md5"

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
        def self.where(&block)
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
        def self.join(table_or_alias : Symbol, &block : Expression::FilterBuilder -> _)
          query.join(table_or_alias, &block)
        end

        # Execute left join with block conditions
        # - **@param** table_or_alias [Symbol | Hash] The table or alias mapping
        # - **@yield** [FilterBuilder] The block to build join conditions
        # - **@return** [QueryBuilder(T)] The query builder instance
        def self.left(table_or_alias : Symbol, &block : Expression::FilterBuilder -> _)
          query.left(table_or_alias, &block)
        end

        # Execute right join with block conditions
        # - **@param** table_or_alias [Symbol | Hash] The table or alias mapping
        # - **@yield** [FilterBuilder] The block to build join conditions
        # - **@return** [QueryBuilder(T)] The query builder instance
        def self.right(table_or_alias : Symbol, &block : Expression::FilterBuilder -> _)
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
        def self.each(&block)
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
        # - **@param** id [Int32 | Int64] The primary key value
        # - **@return** [T?] The record or nil if not found
        def self.find(id)
          query.where(id: id).first
        end

        def self.find?(id)
          query.where(id: id).first
        end

        # Find record by primary key, raises if not found
        # - **@param** id [Int32 | Int64] The primary key value
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
          # This would need to be implemented using CQL::Delete
          # For now, we'll use a simple approach
          records = query.all
          records.each(&.delete)
          records.size.to_i64
        end

        # Alias methods for consistency with Rails ActiveRecord
        def self.min(column : Symbol)
          minimum(column)
        end

        def self.max(column : Symbol)
          maximum(column)
        end

        def self.avg(column : Symbol)
          average(column)
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

      # The QueryBuilder class provides a chainable interface for building queries
      # while maintaining type safety and integration with the CQL::Query system.
      class QueryBuilder(T)
        @query : CQL::Query
        @model_class : T.class

        # Initialize a new QueryBuilder with the given query
        # - **@param** query [CQL::Query] The underlying query object
        # - **@param** model_class [T.class] The model class
        def initialize(@query : CQL::Query, @model_class : T.class = T)
        end

        # Get the model class
        def model_class : T.class
          @model_class
        end

        # Create a QueryBuilder for the given model type
        # - **@param** model_class [Class] The model class
        # - **@return** [QueryBuilder(T)] A new query builder instance
        def self.from_model(model_class : T.class) : QueryBuilder(T) forall T
          schema = model_class.schema
          table = model_class.table
          query = CQL::Query.new(schema).from(table)
          new(query, model_class)
        end

        # Get the underlying CQL::Query object
        # - **@return** [CQL::Query] The query object
        def query
          @query
        end

        # Create a new QueryBuilder with a modified query using a block
        # - **@yield** [CQL::Query] The query to modify
        # - **@return** [QueryBuilder(T)] A new query builder instance
        def with_query(&block)
          # Create a new query by applying the block to a copy of the current query
          new_query = block.call(clone_query(@query))
          QueryBuilder(T).new(new_query, @model_class)
        end

        # Clone the current QueryBuilder and apply modifications
        # - **@return** [QueryBuilder(T)] A new query builder instance
        private def clone_builder : QueryBuilder(T)
          QueryBuilder(T).new(clone_query(@query), @model_class)
        end

        # Clone a CQL::Query object since it doesn't have a built-in clone method
        private def clone_query(original_query : CQL::Query) : CQL::Query
          # Create a new query with the same schema
          new_query = CQL::Query.new(original_query.schema)

          # Copy properties that have setters
          new_query.where = original_query.where
          new_query.having = original_query.having
          new_query.limit = original_query.limit
          new_query.offset = original_query.offset
          new_query.distinct = original_query.distinct?

          # Copy collections by adding elements one by one
          original_query.columns.each { |col| new_query.columns << col }
          original_query.query_tables.each { |key, value| new_query.query_tables[key] = value }
          original_query.group_by.each { |col| new_query.group_by << col }
          original_query.order_by.each { |key, value| new_query.order_by[key] = value }
          original_query.joins.each { |join| new_query.joins << join }
          original_query.aggr_columns.each { |aggr| new_query.aggr_columns << aggr }

          new_query
        end

        # Add columns to select
        # - **@param** columns [Symbol*] The columns to select
        # - **@return** [QueryBuilder(T)] Self for chaining
        def select(*columns : Symbol | String)
          clone_builder.tap(&.query.select(*columns))
        end

        # Add columns to select with hash syntax
        # - **@param** fields [Hash] The fields to select using hash syntax
        # - **@return** [QueryBuilder(T)] Self for chaining
        def select(**fields)
          clone_builder.tap(&.query.select(**fields))
        end

        # Add where conditions
        # - **@param** conditions [Hash] The conditions to filter by
        # - **@return** [QueryBuilder(T)] Self for chaining
        def where(conditions : Hash(String | Symbol, DB::Any | Array(DB::Any)))
          clone_builder.tap(&.query.where(conditions))
        end

        # Add where conditions with hash syntax
        # - **@param** fields [Hash] The conditions using hash syntax
        # - **@return** [QueryBuilder(T)] Self for chaining
        def where(**fields)
          clone_builder.tap(&.query.where(**fields))
        end

        # Add where conditions with block
        # - **@yield** [FilterBuilder] The block to build conditions
        # - **@return** [QueryBuilder(T)] Self for chaining
        def where(&block)
          clone_builder.tap(&.query.where)
        end

        # Add LIKE conditions
        # - **@param** field [Symbol | String] The field to match
        # - **@param** pattern [String] The LIKE pattern
        # - **@return** [QueryBuilder(T)] Self for chaining
        def where_like(field : Symbol | String, pattern : String)
          clone_builder.tap(&.query.where_like(field, pattern))
        end

        # Add order by clauses
        # - **@param** fields [Symbol*] The fields to order by
        # - **@return** [QueryBuilder(T)] Self for chaining
        def order(*fields : Symbol | String)
          clone_builder.tap(&.query.order(*fields))
        end

        # Add order by clauses with hash syntax
        # - **@param** fields [Hash] The fields and directions to order by
        # - **@return** [QueryBuilder(T)] Self for chaining
        def order(**fields)
          clone_builder.tap(&.query.order(**fields))
        end

        # Set limit for the query
        # - **@param** value [Int32] The limit value
        # - **@return** [QueryBuilder(T)] Self for chaining
        def limit(value : Int32)
          clone_builder.tap(&.query.limit(value))
        end

        # Set offset for the query
        # - **@param** value [Int32] The offset value
        # - **@return** [QueryBuilder(T)] Self for chaining
        def offset(value : Int32)
          clone_builder.tap(&.query.offset(value))
        end

        # Add group by clauses
        # - **@param** columns [Symbol*] The columns to group by
        # - **@return** [QueryBuilder(T)] Self for chaining
        def group(*columns : Symbol | String)
          clone_builder.tap(&.query.group(*columns))
        end

        # Add having conditions
        # - **@yield** [HavingBuilder] The block to build having conditions
        # - **@return** [QueryBuilder(T)] Self for chaining
        def having(&block)
          clone_builder.tap(&.query.having)
        end

        # Set distinct flag
        # - **@return** [QueryBuilder(T)] Self for chaining
        def distinct
          clone_builder.tap(&.query.distinct)
        end

        # Execute automatic inner join
        # - **@param** table_or_alias [Symbol | Hash] The table or alias mapping
        # - **@return** [QueryBuilder(T)] Self for chaining
        def join(table_or_alias : Symbol)
          clone_builder.tap(&.query.join(table_or_alias))
        end

        # Execute inner join with block conditions
        # - **@param** table_or_alias [Symbol | Hash] The table or alias mapping
        # - **@yield** [FilterBuilder] The block to build join conditions
        # - **@return** [QueryBuilder(T)] Self for chaining
        def join(table_or_alias : Symbol, &block : Expression::FilterBuilder -> _)
          clone_builder.tap(&.query.join(table_or_alias))
        end

        # Execute automatic left join
        # - **@param** table_or_alias [Symbol | Hash] The table or alias mapping
        # - **@return** [QueryBuilder(T)] Self for chaining
        def left(table_or_alias : Symbol)
          clone_builder.tap(&.query.left(table_or_alias))
        end

        # Execute automatic right join
        # - **@param** table_or_alias [Symbol | Hash] The table or alias mapping
        # - **@return** [QueryBuilder(T)] Self for chaining
        def right(table_or_alias : Symbol)
          clone_builder.tap(&.query.right(table_or_alias))
        end

        # Execute left join with block conditions
        # - **@param** table_or_alias [Symbol | Hash] The table or alias mapping
        # - **@yield** [FilterBuilder] The block to build join conditions
        # - **@return** [QueryBuilder(T)] Self for chaining
        def left(table_or_alias : Symbol, &block : Expression::FilterBuilder ->)
          clone_builder.tap(&.query.left(table_or_alias))
        end

        # Execute right join with block conditions
        # - **@param** table_or_alias [Symbol | Hash] The table or alias mapping
        # - **@yield** [FilterBuilder] The block to build join conditions
        # - **@return** [QueryBuilder(T)] Self for chaining
        def right(table_or_alias : Symbol, &block : Expression::FilterBuilder ->)
          clone_builder.tap(&.query.right(table_or_alias))
        end

        # Execute automatic inner join using named arguments for table aliasing
        # - **@param** tables_with_aliases [NamedTuple] Table name => alias
        # - **@return** [QueryBuilder(T)] Self for chaining
        def join(**tables_with_aliases)
          clone_builder.tap(&.query.join(**tables_with_aliases))
        end

        # Execute automatic left join using named arguments for table aliasing
        # - **@param** tables_with_aliases [NamedTuple] Table name => alias
        # - **@return** [QueryBuilder(T)] Self for chaining
        def left(**tables_with_aliases)
          clone_builder.tap(&.query.left(**tables_with_aliases))
        end

        # Execute automatic right join using named arguments for table aliasing
        # - **@param** tables_with_aliases [NamedTuple] Table name => alias
        # - **@return** [QueryBuilder(T)] Self for chaining
        def right(**tables_with_aliases)
          clone_builder.tap(&.query.right(**tables_with_aliases))
        end

        # Add count aggregate
        # - **@param** column [Symbol] The column to count (defaults to *)
        # - **@return** [Int64] The count result
        def count(column : Symbol = :*)
          result = @query.count(column)
          result = result.get(Int64 | Int32 | Nil) if result.responds_to?(:get)
          result || 0
        end

        # Add sum aggregate
        # - **@param** column [Symbol] The column to sum
        # - **@return** [Float64 | Int64] The sum result
        def sum(column : Symbol)
          result = @query.sum(column)
          result = result.get(Int64 | Float64 | Int32 | Nil) if result.responds_to?(:get)
          result || 0
        end

        # Add avg aggregate
        # - **@param** column [Symbol] The column to average
        # - **@return** [Float64] The average result
        def avg(column : Symbol)
          result = @query.avg(column)
          result = result.get(Float64 | Int64 | Int32 | Nil) if result.responds_to?(:get)
          result || 0.0
        end

        # Add min aggregate
        # - **@param** column [Symbol] The column to find minimum
        # - **@return** [DB::Any] The minimum result
        def min(column : Symbol)
          result = @query.min(column)
          result = result.get(Int64 | Float64 | Int32 | Nil) if result.responds_to?(:get)
          result || 0
        end

        # Add max aggregate
        # - **@param** column [Symbol] The column to find maximum
        # - **@return** [DB::Any] The maximum result
        def max(column : Symbol)
          result = @query.max(column)
          result = result.get(Int64 | Float64 | Int32 | Nil) if result.responds_to?(:get)
          result || 0
        end

        # Merge with another QueryBuilder
        # - **@param** other [QueryBuilder(T)] The other query builder to merge
        # - **@return** [QueryBuilder(T)] A new merged query builder
        def merge(other : QueryBuilder(T))
          merged_query = @query.merge(other.query)
          QueryBuilder(T).new(merged_query, @model_class)
        end

        # Execute the query and return all results
        # - **@return** [Array(T)] Array of model instances
        def all(as as_kind = T)
          @query.all(as_kind)
        end

        # Execute the query and return the first result
        # - **@return** [T?] First model instance or nil
        def first(as as_kind = T)
          @query.first(as_kind)
        end

        # Execute the query and return the first result, raises if not found
        # - **@return** [T] First model instance
        def first!(as as_kind = T)
          @query.first!(as_kind)
        end

        # Execute the query and return the last result (using reverse order)
        # - **@return** [T?] Last model instance or nil
        def last(as as_kind = T)
          results = @query.all(as_kind)
          results.last?
        end

        # Execute the query and return the last result, raises if not found
        # - **@return** [T] Last model instance
        def last!(as as_kind = T)
          result = last
          raise "No records found" unless result
          result
        end

        # Execute the query and return a scalar value
        # - **@param** as [Type] The type to cast the result to
        # - **@return** [Type] The scalar result
        def get(as as_kind)
          @query.get(as_kind)
        end

        # Iterate over each result
        # - **@yield** [T] Each model instance
        def each(&block)
          @query.each(T) do |record|
            yield record
          end
        end

        # Check if any records exist
        # - **@return** [Bool] True if records exist
        def exists? : Bool
          count_result = count
          count_result > 0
        end

        def exists?(**conditions)
          where(**conditions).exists?
        end

        # Check if no records exist
        # - **@return** [Bool] True if no records exist
        def empty?
          !exists?
        end

        # Convert to SQL string for debugging
        # - **@return** [String] The SQL query string
        def to_sql
          @query.to_sql.first
        end

        # Get the SQL query and parameters
        # - **@return** [Tuple(String, Array)] The SQL query and parameters
        def to_sql_with_params
          @query.to_sql
        end

        # Additional QueryBuilder methods needed for full Active Record compatibility

        # Find record by primary key
        # - **@param** id [Int32 | Int64] The primary key value
        # - **@return** [T?] The record or nil if not found
        def find(id)
          where(id: id).first
        end

        # Find record by primary key, raises if not found
        # - **@param** id [Int32 | Int64] The primary key value
        # - **@return** [T] The record
        def find!(id)
          result = find(id)
          raise DB::NoResultsError.new("No records found with id=#{id}") unless result
          result
        end

        # Find record by attributes
        # - **@param** conditions [Hash] The conditions to search by
        # - **@return** [T?] The first matching record or nil
        def find_by(conditions : Hash(String | Symbol, DB::Any | Array(DB::Any)))
          where(conditions).first
        end

        # Find record by attributes with hash syntax
        # - **@param** fields [Hash] The conditions using hash syntax
        # - **@return** [T?] The first matching record or nil
        def find_by(**fields)
          where(**fields).first
        end

        # Find record by attributes, raises if not found
        # - **@param** conditions [Hash] The conditions to search by
        # - **@return** [T] The first matching record
        def find_by!(conditions : Hash(String | Symbol, DB::Any | Array(DB::Any)))
          result = find_by(conditions)
          raise DB::NoResultsError.new("No records found with conditions: #{conditions}") unless result
          result
        end

        # Find record by attributes, raises if not found (hash syntax)
        # - **@param** fields [Hash] The conditions using hash syntax
        # - **@return** [T] The first matching record
        def find_by!(**fields)
          result = find_by(**fields)
          raise DB::NoResultsError.new("No records found with conditions: #{fields}") unless result
          result
        end

        # Batch processing - iterate over records in batches
        # - **@param** batch_size [Int32] Size of each batch
        # - **@yield** [T] Each record
        def find_each(batch_size : Int32 = 1000, &block : T ->)
          # Ensure we have a consistent ordering to avoid infinite loops
          # If no ordering is specified, order by primary key (usually id)
          query_with_order = @query.order_by.empty? ? order(:id) : self

          offset = 0
          max_iterations = 10000 # Safety limit to prevent infinite loops
          iteration_count = 0
          processed_ids = Set(Int64).new

          loop do
            iteration_count += 1
            break if iteration_count > max_iterations

            batch = query_with_order.limit(batch_size).offset(offset).all
            break if batch.empty?

            # Check if we're processing the same records again (infinite loop detection)
            batch_ids = batch.compact_map(&.id).map(&.to_i64).to_set
            if batch_ids.subset_of?(processed_ids)
              # We're processing the same records again, break to avoid infinite loop
              break
            end

            batch.each do |model_record|
              if id = model_record.id
                id_i64 = id.to_i64
                unless processed_ids.includes?(id_i64)
                  processed_ids.add(id_i64)
                  yield model_record
                end
              end
            end

            # If we got fewer records than requested, we've reached the end
            break if batch.size < batch_size

            offset += batch_size
          end
        end

        # Process records in batches
        # - **@param** batch_size [Int32] Size of each batch
        # - **@yield** [Array(T)] Each batch of records
        def find_in_batches(batch_size : Int32 = 1000, &block : Array(T) ->)
          # Ensure we have a consistent ordering to avoid infinite loops
          # If no ordering is specified, order by primary key (usually id)
          query_with_order = @query.order_by.empty? ? order(:id) : self

          offset = 0
          max_iterations = 10000 # Safety limit to prevent infinite loops
          iteration_count = 0
          processed_ids = Set(Int64).new

          loop do
            iteration_count += 1
            break if iteration_count > max_iterations

            batch = query_with_order.limit(batch_size).offset(offset).all
            break if batch.empty?

            # Check if we're processing the same records again (infinite loop detection)
            batch_ids = batch.compact_map(&.id).map(&.to_i64).to_set
            if batch_ids.subset_of?(processed_ids)
              # We're processing the same records again, break to avoid infinite loop
              break
            end

            # Filter out already processed records
            new_records = batch.reject do |record|
              if id = record.id
                processed_ids.includes?(id.to_i64)
              else
                false
              end
            end

            # Add new record IDs to processed set
            new_records.each do |record|
              if id = record.id
                processed_ids.add(id.to_i64)
              end
            end

            yield new_records unless new_records.empty?

            # If we got fewer records than requested, we've reached the end
            break if batch.size < batch_size

            offset += batch_size
          end
        end

        # Extract column values from all matching records
        # - **@param** columns [Symbol*] The columns to extract
        # - **@return** [Array] Array of values or arrays if multiple columns
        def pluck(*columns : Symbol, as as_kind)
          if columns.size == 1
            self.select(columns.first).all(as: as_kind)
          else
            self.select(*columns).all(as: as_kind)
          end
        end

        # Extract a single column value from the first matching record
        # - **@param** column [Symbol] The column to extract
        # - **@return** [DB::Any?] The value or nil if no records
        def pick(column : Symbol, as as_kind = DB::Any)
          @query.select(column).limit(1).first(as_kind)
        end

        # Get array of primary key values
        # - **@return** [Array] Array of primary key values
        def ids(as as_kind = Int64)
          # Use a different approach to get just the ID values
          # We need to get the raw values, not deserialize into models
          query, params = @query.select(:id).to_sql
          @query.schema.exec_query do |conn|
            conn.query_all(query, args: params, as: as_kind)
          end
        end

        # Get maximum value of a column
        # - **@param** column [Symbol] The column to find maximum
        # - **@return** [DB::Any?] The maximum value or nil
        def maximum(column : Symbol)
          max(column)
        end

        # Get minimum value of a column
        # - **@param** column [Symbol] The column to find minimum
        # - **@return** [DB::Any?] The minimum value or nil
        def minimum(column : Symbol)
          min(column)
        end

        # Get average value of a column
        # - **@param** column [Symbol] The column to average
        # - **@return** [Float64?] The average value or nil
        def average(column : Symbol)
          avg(column)
        end

        # Get distinct values for a column
        # - **@param** column [Symbol] The column to get distinct values
        # - **@return** [Array(DB::Any)] Array of distinct values
        def distinct_values(column : Symbol, as as_kind = DB::Any)
          distinct.select(column).all(as: as_kind)
        end

        # Replace existing order clause
        # - **@param** fields [Symbol*] The fields to order by
        # - **@return** [QueryBuilder(T)] Self for chaining
        def reorder(*fields : Symbol | String)
          # Clear existing order and add new one
          @query.order_by.clear if @query.responds_to?(:order_by)
          order(*fields)
        end

        # Replace existing order clause with hash syntax
        # - **@param** fields [Hash] The fields and directions to order by
        # - **@return** [QueryBuilder(T)] Self for chaining
        def reorder(**fields)
          # Clear existing order and add new one
          @query.order_by.clear if @query.responds_to?(:order_by)
          order(**fields)
        end

        # Reverse the order of records
        # - **@return** [QueryBuilder(T)] Self for chaining
        def reverse_order
          # This would need specific implementation in CQL::Query
          # For now, return self to maintain chainability
          self
        end

        # Remove specific scopes
        # - **@param** scope_type [Symbol] The type of scope to remove
        # - **@return** [QueryBuilder(T)] Self for chaining
        def unscope(scope_type : Symbol)
          # This would need specific implementation in CQL::Query
          # For now, return self to maintain chainability
          self
        end

        # Delete all records matching current scope
        # - **@return** [Int64] Number of deleted records
        def delete_all
          records = all
          records.each(&.delete)
          records.size.to_i64
        end

        # Alias for group method to match ActiveRecord naming
        # - **@param** columns [Symbol*] The columns to group by
        # - **@return** [QueryBuilder(T)] Self for chaining
        def group_by(*columns : Symbol | String)
          group(*columns)
        end

        # Return a QueryBuilder that will return no results
        # - **@return** [QueryBuilder(T)] A query builder that returns no results
        def none
          # Create a query with an impossible condition
          none_query = CQL::Query.new(@query.schema)
          QueryBuilder(T).new(none_query, @model_class)
        end

        # Check if any records exist
        # - **@return** [Bool] True if any records exist
        def any?
          exists?
        end

        # Check if many records exist (more than one)
        # - **@return** [Bool] True if more than one record exists
        def many?
          count > 1
        end

        # Get the count of records
        # - **@return** [Int64] The number of records
        def size
          count
        end
      end
    end
  end
end
