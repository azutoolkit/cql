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
      macro included
        # Return a new query object for the current table
        # - **@return** [Query] The query object
        #
        # **Example** Fetching all records
        #
        # ```
        # User.query.all(User)
        # User.query.where(active: true).all(User)
        # ```
        def self.query
          Query({{@type.id}}).new({{@type.id}}.schema).from({{@type.id}}.table)
        end

        # Fetch all records of type T
        # - **@return** [Array({{@type.id}})] The records
        #
        # **Example** Fetching all records
        #
        # ```
        # User.all
        # ```
        def self.all
          query.all
        end

        # Find a record by ID, return nil if not found
        # - **@param** id [PrimaryKey] The ID of the record
        # - **@return** [T?] The record, or nil if not found
        #
        # **Example** Fetching a record by ID
        #
        # ```
        # User.find(1)
        # ```
        def self.find(id : Pk)
          query.where(id: id).first
        rescue DB::NoResultsError
          nil
        end

        def self.find?(id : Pk)
          query.where(id: id).first
        rescue DB::NoResultsError
          nil
        end

        # Find a record by ID, raise an error if not found
        # - **@param** id [PrimaryKey] The ID of the record
        # - **@return** [T] The record
        # - **@raise** [DB::NoResultsError] If the record is not found
        # - **@raise** [CQL::Schema::ConnectionError] If there is a database connection error
        #
        # **Example** Fetching a record by ID
        #
        # ```
        # User.find!(1)
        # ```
        def self.find!(id : Pk)
          query.where(id: id).first!
        rescue e : CQL::Schema::ConnectionError
          # Only convert to NoResultsError if the error message indicates no results
          # This maintains compatibility with existing tests while allowing real
          # connection errors to propagate
          if e.message.to_s.includes?("no results")
            raise DB::NoResultsError.new("Record not found")
          else
            raise e # Re-raise the original error for actual connection issues
          end
        end

        # Find a record by specific fields
        # - **@param** fields [Hash(Symbol, DB::Any)] The fields to match
        # - **@return** [T?] The record, or nil if not found
        #
        # **Example** Fetching a record by email
        #
        # ```
        # User.find_by(email: "alice@example.com")
        # ```
        def self.find_by(**fields)
          query.where(**fields).limit(1).first
        rescue DB::NoResultsError
          nil
        rescue e : CQL::Schema::ConnectionError
          # Only return nil if the error message indicates no results
          # This maintains compatibility with existing behavior while allowing real
          # connection errors to propagate
          if e.message.to_s.includes?("no results")
            nil
          else
            raise e # Re-raise the original error for actual connection issues
          end
        end

        def self.find_by(attributes : Hash(Symbol, DB::Any))
          query.where(attributes).limit(1).first
        rescue DB::NoResultsError
          nil
        rescue e : CQL::Schema::ConnectionError
          # Only return nil if the error message indicates no results
          # This maintains compatibility with existing behavior while allowing real
          # connection errors to propagate
          if e.message.to_s.includes?("no results")
            nil
          else
            raise e # Re-raise the original error for actual connection issues
          end
        end

        def self.find_by!(attributes : Hash(Symbol, DB::Any))
          query.where(attributes).limit(1).first!
        rescue e : CQL::Schema::ConnectionError
          # Only convert to NoResultsError if the error message indicates no results
          # This maintains compatibility with existing tests while allowing real
          # connection errors to propagate
          if e.message.to_s.includes?("no results")
            raise DB::NoResultsError.new("Record not found")
          else
            raise e # Re-raise the original error for actual connection issues
          end
        end

        # Find a record by specific fields, raise an error if not found
        # - **@param** fields [Hash(Symbol, DB::Any)] The fields to match
        # - **@return** [T] The record
        # - **@raise** [DB::NoResultsError] If the record is not found
        # - **@raise** [CQL::Schema::ConnectionError] If there is a database connection error
        #
        # **Example** Fetching a record by email
        # ```
        # User.find_by!(email: "alice@example.com")
        # ```
        def self.find_by!(**fields)
          query.where(**fields).limit(1).first!
        rescue e : CQL::Schema::ConnectionError
          # Only convert to NoResultsError if the error message indicates no results
          # This maintains compatibility with existing tests while allowing real
          # connection errors to propagate
          if e.message.to_s.includes?("no results")
            raise DB::NoResultsError.new("Record not found")
          else
            raise e # Re-raise the original error for actual connection issues
          end
        end

        # Find all records matching specific fields
        # - **@param** fields [Hash(Symbol, DB::Any)] The fields to match
        # - **@return** [Array({{@type.id}})] The records
        #
        # **Example** Fetching all active users
        #
        # ```
        # User.find_all_by(active: true)
        # ```
        def self.find_all_by(**fields)
          query.where(**fields).all
        end

        # Count all records in the table
        # - **@return** [Int64] The number of records
        #
        # **Example** Counting all records
        #
        # ```
        # User.count
        # ```
        def self.count
          query.count
        end

        # Check if records exist matching specific fields
        # - **@param** fields [Hash(Symbol, DB::Any)] The fields to match
        # - **@return** [Bool] True if records exist, false otherwise
        #
        # **Example** Checking if a record exists by email
        #
        # ```
        # User.exists?(email: "alice@example.com")
        # ```
        def self.exists?(**fields)
          query.select.where(**fields).limit(1).first != nil
        rescue DB::NoResultsError
          false
        end

        # Fetch the first record in the table
        # - **@return** [T?] The first record, or nil if the table is empty
        #
        # **Example** Fetching the first record
        #
        # ```
        # User.first
        # ```
        def self.first
          query.order(id: :asc).limit(1).first
        end

        # Fetch the last record in the table
        # - **@return** [T?] The last record, or nil if the table is empty
        #
        # **Example** Fetching the last record
        #
        # ```
        # User.last
        # ```
        def self.last
          query.order(id: :desc).limit(1).first
        end

        # Start a chainable query with a where clause using a block
        # - **@yield** [FilterBuilder] The block to build the condition
        # - **@return** [Query] The chainable query
        #
        # **Example**
        #
        # ```
        # User.where { |q| q.name == "Alice" & q.active == true }.all
        # ```
        def self.where(&block)
          query.where(&block)
        end

        # Start a chainable query with an order clause
        # - **@param** fields [Hash(Symbol, Symbol)] The fields to order by
        # - **@return** [Query] The chainable query
        #
        # **Example** Building a query with order
        #
        # ```
        # User.order(name: :asc).all
        # ```
        def self.order(**fields)
          query.order(**fields)
        end

        # Start a chainable query with a limit
        # - **@param** limit [Int32] The maximum number of records to return
        # - **@return** [Query] The chainable query
        #
        # **Example** Building a query with limit
        #
        # ```
        # User.limit(10).all
        # ```
        def self.limit(limit : Int32)
          query.limit(limit)
        end

        # Start a chainable query with an offset
        # - **@param** offset [Int32] The number of records to skip
        # - **@return** [Query] The chainable query
        #
        # **Example** Building a query with offset
        #
        # ```
        # User.offset(10).all
        # ```
        def self.offset(offset : Int32)
          query.offset(offset)
        end

        # Start a chainable query with a select clause
        # - **@param** fields [Array(Symbol)] The fields to select
        # - **@return** [Query] The chainable query
        #
        # **Example** Building a query with select
        #
        # ```
        # User.select(:id, :name).all
        # ```
        def self.select(*fields)
          query.select(*fields)
        end

        # Start a chainable query with a group by clause
        # - **@param** fields [Array(Symbol)] The fields to group by
        # - **@return** [Query] The chainable query
        #
        # **Example** Building a query with group by
        #
        # ```
        # User.group_by(:role).count
        # ```
        def self.group_by(*fields)
          query.group_by(*fields)
        end

        # Start a chainable query with a join clause
        # - **@param** table [Symbol] The table to join
        # - **@param** on [Hash(Symbol, Symbol) | NamedTuple] The join condition
        # - **@return** [Query] The chainable query
        #
        # **Example** Building a query with join
        #
        # ```
        # User.join(:posts, {id: :user_id}).all
        # ```
        def self.join(table : Symbol, on)
          on_hash = on.is_a?(Hash) ? on : on.to_h
          query.join(table, on_hash)
        end

        # Minimum value for a column
        def self.minimum(field : Symbol)
          query.minimum(field)
        end

        # Maximum value for a column
        def self.maximum(field : Symbol)
          query.maximum(field)
        end

        # Sum for a column
        def self.sum(field : Symbol)
          query.sum(field)
        end

        # Average for a column
        def self.average(field : Symbol)
          query.average(field)
        end

        # Group by fields (alias for group_by)
        def self.group(*fields)
          query.group(*fields)
        end

        # Having clause
        def self.having(condition : String, *args)
          query.having(condition, *args)
        end

        # Distinct
        def self.distinct
          query.distinct
        end

        # None (returns an empty relation)
        def self.none
          query.none
        end

        # Readonly (no-op for now, for API compatibility)
        def self.readonly
          query.readonly
        end

        # Lock (for update)
        def self.lock(lock_clause : String? = nil)
          query.lock(lock_clause)
        end

        # From (change the table for the query)
        def self.from(table : Symbol)
          query.from(table)
        end
      end

      macro create_scope_method(name_ident, scope_proc_code)
        def {{name_ident.id}}(*args)
          # `self` here is an instance of ::CQL::Query(CURRENT_MODEL_CLASS).
          # `self.query` should be the current accumulated CQL::Query.
          # `self.model_class` should be CURRENT_MODEL_CLASS.

          # Execute the scope_proc_code. `self` inside the proc is CURRENT_MODEL_CLASS.
          # This will typically return a Query(CURRENT_MODEL_CLASS) or a raw CQL::Query.
          scope_logic_result = ({{scope_proc_code}}).call(*args)

          cql_query_fragment_for_scope : ::CQL::Query
          if scope_logic_result.is_a?(::CQL::Query)
            cql_query_fragment_for_scope = scope_logic_result
          elsif scope_logic_result.is_a?(Query({{@type.id}}))
            # Assumes Query has a `query` getter for its underlying CQL::Query.
            cql_query_fragment_for_scope = scope_logic_result.query
          else
            raise "Scope '{{name_ident.id}}' for model #{CURRENT_MODEL_CLASS}, when applied in a chain, " \
                  "did not produce a compatible CQL::Query or Query(#{{{@type.id}}}). " \
                  "Received: #{scope_logic_result.class}"
          end

          # Merge the new scope's CQL query fragment into the existing query of this Query instance.
          # Assumes `self.query.merge(...)` returns a new, merged CQL::Query instance.
          current_underlying_query = self.query # Assumes .query getter
          new_underlying_query = current_underlying_query.merge(cql_query_fragment_for_scope)

          # Return a new Query instance with the merged query, promoting immutability.
          # Assumes Query(ModelType).new(cql_query) constructor.
          Query({{@type.id}}).new(new_underlying_query)
        end
      end
    end
  end
end
