module CQL
  module ActiveRecord
    module Queryable
      # The QueryBuilder class provides a chainable interface for building queries
      # while maintaining type safety and integration with the CQL::Query system.
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
        def with_query(&block : CQL::Query -> CQL::Query)
          # Create a new query by applying the block to a copy of the current query
          new_query = block.call(@query.clone)
          QueryBuilder(T).new(new_query, @model_class)
        end

        # Clone the current QueryBuilder and apply modifications
        # - **@return** [QueryBuilder(T)] A new query builder instance
        private def clone_builder : QueryBuilder(T)
          QueryBuilder(T).new(@query.clone, @model_class)
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
        def where(&block : -> Expression::ConditionBuilder)
          @query = query.where(&block)
          clone_builder.tap(&.query)
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
        def having(&block : Expression::HavingBuilder -> Expression::Having)
          @query = query.where(&block)
          clone_builder.tap(&.query)
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
        def join(table_or_alias : Symbol, &block : Expression::FilterBuilder -> Expression::ConditionBuilder)
          @query = query.join(table_or_alias, &block)
          clone_builder.tap(&.query)
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
        def left(table_or_alias : Symbol, &block : Expression::FilterBuilder -> Expression::ConditionBuilder)
          @query = query.left(table_or_alias, &block)
          clone_builder.tap(&.query)
        end

        # Execute right join with block conditions
        # - **@param** table_or_alias [Symbol | Hash] The table or alias mapping
        # - **@yield** [FilterBuilder] The block to build join conditions
        # - **@return** [QueryBuilder(T)] Self for chaining
        def right(table_or_alias : Symbol, &block : Expression::FilterBuilder -> Expression::ConditionBuilder)
          @query = query.right(table_or_alias, &block)
          clone_builder.tap(&.query)
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
          result || 0_i64
        end

        # Add sum aggregate
        # - **@param** column [Symbol] The column to sum
        # - **@return** [Float64 | Int64] The sum result
        def sum(column : Symbol)
          result = @query.sum(column)
          result = result.get(Int64 | Float64 | Int32 | Nil) if result.responds_to?(:get)
          result || 0_i64
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
        def each(&block : T ->)
          @query.each(as: T, &block)
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
        def find_each(batch_size : Int32 = 1000, & : T ->)
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
        def find_in_batches(batch_size : Int32 = 1000, & : Array(T) ->)
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
          records.each(&.delete!)
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
          # Set up the FROM clause with the model's table
          table = @model_class.table
          none_query.from(table)
          # Add an impossible condition to ensure no results
          # Use a condition that will never be true
          none_query.where(id: -1)
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
