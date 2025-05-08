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
          CQL::Query.new({{@type.id}}.schema).from({{@type.id}}.table)
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
          query.all({{@type.id}})
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
          query
          .where(id: id)
          .first(as: {{@type.id}})
        rescue DB::NoResultsError
          nil
        end


        def self.find?(id : Pk)
          query.where(id: id).first(as: {{@type.id}})
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
          query.where(id: id).first!({{@type.id}})
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
          query.where(**fields).limit(1).first({{@type.id}})
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
          query.where(attributes).limit(1).first({{@type.id}})
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
          query.where(attributes).limit(1).first!({{@type.id}})
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
          query.where(**fields).limit(1).first!({{@type.id}})
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
          query.where(**fields).all({{@type.id}})
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
          query.count(:id).first!(Int64)
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
          query.select.where(**fields).limit(1).first({{@type.id}}) != nil
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
          query.order(id: :asc).limit(1).first({{@type.id}})
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
          query.order(id: :desc).limit(1).first({{@type.id}})
        end

        # Start a chainable query with a where clause
        # - **@param** fields [Hash(Symbol, DB::Any)] The fields to match
        # - **@return** [ChainableQuery] The chainable query
        #
        # **Example** Building a query with where condition
        #
        # ```
        # User.where(active: true).order(created_at: :desc).limit(10).all
        # ```
        def self.where(**fields)
          ChainableQuery({{@type.id}}).new(query.where(**fields))
        end

        # Start a chainable query with an order clause
        # - **@param** fields [Hash(Symbol, Symbol)] The fields to order by
        # - **@return** [ChainableQuery] The chainable query
        #
        # **Example** Building a query with order
        #
        # ```
        # User.order(name: :asc).all
        # ```
        def self.order(**fields)
          ChainableQuery({{@type.id}}).new(query.order(**fields))
        end

        # Start a chainable query with a limit
        # - **@param** limit [Int32] The maximum number of records to return
        # - **@return** [ChainableQuery] The chainable query
        #
        # **Example** Building a query with limit
        #
        # ```
        # User.limit(10).all
        # ```
        def self.limit(limit : Int32)
          ChainableQuery({{@type.id}}).new(query.limit(limit))
        end

        # Start a chainable query with an offset
        # - **@param** offset [Int32] The number of records to skip
        # - **@return** [ChainableQuery] The chainable query
        #
        # **Example** Building a query with offset
        #
        # ```
        # User.offset(10).all
        # ```
        def self.offset(offset : Int32)
          ChainableQuery({{@type.id}}).new(query.offset(offset))
        end

        # Start a chainable query with a select clause
        # - **@param** fields [Array(Symbol)] The fields to select
        # - **@return** [ChainableQuery] The chainable query
        #
        # **Example** Building a query with select
        #
        # ```
        # User.select(:id, :name).all
        # ```
        def self.select(*fields)
          ChainableQuery({{@type.id}}).new(query.select(*fields))
        end

        # Start a chainable query with a group by clause
        # - **@param** fields [Array(Symbol)] The fields to group by
        # - **@return** [ChainableQuery] The chainable query
        #
        # **Example** Building a query with group by
        #
        # ```
        # User.group_by(:role).count
        # ```

        def self.group_by(*fields)
          ChainableQuery({{@type.id}}).new(query.group(*fields))
        end

        # Start a chainable query with a join clause
        # - **@param** table [Symbol] The table to join
        # - **@param** on [Hash(Symbol, Symbol) | NamedTuple] The join condition
        # - **@return** [ChainableQuery] The chainable query
        #
        # **Example** Building a query with join
        #
        # ```
        # User.join(:posts, {id: :user_id}).all
        # ```
        def self.join(table : Symbol, on)
          on_hash = on.is_a?(Hash) ? on : on.to_h
          ChainableQuery({{@type.id}}).new(query.join(table, on_hash))
        end
      end

      # A chainable query class that wraps a CQL::Query
      # and knows about the model type it's querying
      class ChainableQuery(Target)
        @model_class : Target.class = Target

        forward_missing_to Target

        def initialize(@query : CQL::Query)
        end

        # Execute the query and return all matching records
        # - **@return** [Array(T)] The matching records
        def all
          @query.all(@model_class)
        end

        # Execute the query and return the first matching record
        # - **@return** [T?] The first matching record, or nil if none found
        def first
          @query.first(@model_class)
        rescue DB::NoResultsError
          nil
        end

        # Execute the query and return the first matching record, raising if none found
        # - **@return** [T] The first matching record
        # - **@raise** [DB::NoResultsError] If no records found
        def first!
          @query.first!(@model_class)
        end

        # Count the number of matching records
        # - **@return** [Int64] The number of matching records
        def count
          @query.count(:id).first!(Int64)
        end

        # Add a where clause to the query
        # - **@param** fields [Hash(Symbol, DB::Any)] The fields to match
        # - **@return** [ChainableQuery] The chainable query
        def where(**fields)
          ChainableQuery(Target).new(@query.where(**fields))
        end

        # Add an order clause to the query
        # - **@param** fields [Hash(Symbol, Symbol)] The fields to order by
        # - **@return** [ChainableQuery] The chainable query
        def order(**fields)
          ChainableQuery(Target).new(@query.order(**fields))
        end

        # Add a limit clause to the query
        # - **@param** limit [Int32] The maximum number of records to return
        # - **@return** [ChainableQuery] The chainable query
        def limit(limit : Int32)
          ChainableQuery(Target).new(@query.limit(limit))
        end

        # Add an offset clause to the query
        # - **@param** offset [Int32] The number of records to skip
        # - **@return** [ChainableQuery] The chainable query
        def offset(offset : Int32)
          ChainableQuery(Target).new(@query.offset(offset))
        end

        # Add a select clause to the query
        # - **@param** fields [Array(Symbol)] The fields to select
        # - **@return** [ChainableQuery] The chainable query
        def select(*fields)
          ChainableQuery(Target).new(@query.select(*fields))
        end

        # Add a group by clause to the query
        # - **@param** fields [Array(Symbol)] The fields to group by
        # - **@return** [ChainableQuery] The chainable query
        def group_by(*fields)
          ChainableQuery(Target).new(@query.group(*fields))
        end

        # Add a join clause to the query
        # - **@param** table [Symbol] The table to join
        # - **@param** on [Hash(Symbol, Symbol) | NamedTuple] The join condition
        # - **@return** [ChainableQuery] The chainable query
        def join(table : Symbol, on)
          on_hash = on.is_a?(Hash) ? on : on.to_h
          ChainableQuery(Target).new(@query.join(table, on_hash))
        end
      end
    end
  end
end
