module CQL
  module ActiveRecord
    module Pagination
      macro included
        # Paginate results based on page number and items per page
        # - **@param** page_number [Int32] The page number to fetch
        # - **@param** per_page [Int32] The number of items per page
        # - **@return** [Array({{@type.id}})] The records for the page
        #
        # **Example** Paginating results
        #
        # ```
        # User.page(1, 10)
        # ```
        def self.page(page_number : Int32, per_page = 10)
          offset = (page_number - 1) * per_page
          query.limit(per_page).offset(offset).all({{@type.id}})
        end

        # Limit the number of results per page
        # - **@param** per_page [Int32] The number of items per page
        # - **@return** [Array({{@type.id}})] The records for the page
        #
        # **Example** Limiting results per page
        #
        # ```
        # User.per_page(10)
        # ```
        def self.per_page(per_page)
          query.limit(per_page).all({{@type.id}})
        end

        # Cursor-based pagination: get records after a given cursor ID
        # More efficient than offset-based pagination for large datasets.
        # Works best with ULID (time-sortable) or any ordered column.
        #
        # - **@param** cursor_id [Pk] The ID to start after
        # - **@param** limit [Int32] Maximum number of records to return
        # - **@return** [Array({{@type.id}})] Records after the cursor
        #
        # **Example** Cursor-based pagination
        #
        # ```
        # # Get first page
        # first_page = User.per_page(10)
        # # Get next page using last record's ID as cursor
        # next_page = User.after_cursor(first_page.last.id!, limit: 10)
        # ```
        def self.after_cursor(cursor_id : Pk, limit : Int32 = 10)
          query.where_gt(primary_key_column, CQL::ActiveRecord::IdChunks.bound(cursor_id))
               .order(primary_key_column)
               .limit(limit)
               .all({{@type.id}})
        end

        # Cursor-based pagination: get records before a given cursor ID
        # Useful for implementing "previous page" functionality.
        #
        # - **@param** cursor_id [Pk] The ID to end before
        # - **@param** limit [Int32] Maximum number of records to return
        # - **@return** [Array({{@type.id}})] Records before the cursor (in ascending order)
        #
        # **Example** Previous page navigation
        #
        # ```
        # page = User.after_cursor(20_i64, limit: 10)
        # previous_page = User.before_cursor(page.first.id!, limit: 10)
        # ```
        def self.before_cursor(cursor_id : Pk, limit : Int32 = 10)
          query.where_lt(primary_key_column, CQL::ActiveRecord::IdChunks.bound(cursor_id))
               .tap(&.query.order_by.[]=(table_columns[primary_key_column], ::Expression::OrderDirection::DESC))
               .limit(limit)
               .all({{@type.id}})
               .reverse
        end

        # Keyset pagination with a custom column
        # Allows pagination on any sortable column, not just the primary key.
        #
        # - **@param** column [Symbol] The column to paginate by
        # - **@param** after_value The value to start after
        # - **@param** limit [Int32] Maximum number of records to return
        # - **@return** [Array({{@type.id}})] Records after the given value
        #
        # **Example** Paginate by created_at timestamp
        #
        # ```
        # # Users created after a specific time
        # recent_users = User.paginate_by(:created_at, Time.utc - 1.day, limit: 20)
        # ```
        def self.paginate_by(column : Symbol, after_value, limit : Int32 = 10)
          query.where_gt(column, after_value.as(DB::Any))
               .order(column)
               .limit(limit)
               .all({{@type.id}})
        end
      end
    end
  end
end
