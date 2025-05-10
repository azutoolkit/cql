module CQL
  module ActiveRecord
    module Pagination
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
    end
  end
end
