module Cql
  module Record(T)
    macro included
      class_getter schema : Cql::Schema?
      class_getter table : Symbol?

      def self.define(schema : Cql::Schema, table : Symbol)
        @@schema = schema
        @@table = table
      end

      # Define class-level methods for querying and manipulating data
      # Build a new object of type T with the given attributes
      # - **@param** attrs [Hash(Symbol, DB::Any)] The attributes to use
      # - **@return** [T] The new object
      #
      # **Example** Building a new user object
      #
      # ```
      # user_repo.build(name: "Alice", email: " [email protected]")
      # ```
      #
      def self.build(attrs : Hash(Symbol, DB::Any))
        T.new(attrs)
      end

      def self.build(**fields)
        T.new(**fields)
      end

      # Return a new query object for the current table
      # - **@return** [Query] The query object
      #
      # **Example** Fetching all records
      #
      # ```
      # user_repo.query.all(T)
      # user_repo.query.where(active: true).all(T)
      # ```
      def self.query
        Cql::Query.new(T.schema.not_nil!).from(T.table.not_nil!)
      end

      # Fetch all records of type T
      # - **@return** [Array(T)] The records
      #
      # **Example** Fetching all records
      #
      # ```
      # user_repo.all
      # ```
      def self.all
        query.all(T)
      end

      # Find a record by ID, return nil if not found
      # - **@param** id [PrimaryKey] The ID of the record
      # - **@return** [T?] The record, or nil if not found
      #
      # **Example** Fetching a record by ID
      #
      # ```
      # user_repo.find(1)
      # ```
      def self.find(id)
        query.where(id: id).first(T)
      rescue DB::NoResultsError
        nil
      end

      # Find a record by ID, raise an error if not found
      # - **@param** id [PrimaryKey] The ID of the record
      # - **@return** [T] The record
      #
      # **Example** Fetching a record by ID
      #
      # ```
      # user_repo.find!(1)
      # ```
      def self.find!(id)
        query.where(id: id).first!(T)
      end

      # Find a record by specific fields
      # - **@param** fields [Hash(Symbol, DB::Any)] The fields to match
      # - **@return** [T?] The record, or nil if not found
      #
      # **Example** Fetching a record by email
      #
      # ```
      # user_repo.find_by(email: " [email protected]")
      # ```
      def self.find_by(**fields)
        query.where(**fields).first(T)
      end

      # Find all records matching specific fields
      # - **@param** fields [Hash(Symbol, DB::Any)] The fields to match
      # - **@return** [Array(T)] The records
      #
      # **Example** Fetching all active users
      #
      # ```
      # user_repo.find_all_by(active: true)
      # ```
      def self.find_all_by(**fields)
        query.where(**fields).all(T)
      end

      # Return a new insert object for the current table
      # - **@return** [Insert] The insert object
      #
      # **Example** Creating a new record
      #
      # ```
      # user_repo.insert.values(name: "Alice", email: " [email protected]").commit
      # ```
      def self.insert
        Cql::Insert.new(T.schema.not_nil!).into(T.table.not_nil!)
      end

      # Create a new record with given attributes
      # - **@param** attrs [Hash(Symbol, DB::Any)] The attributes to use
      # - **@return** [PrimaryKey] The ID of the new record
      # **Example** Creating a new record
      # ```
      # user_repo.create(name: "Alice", email: " [email protected]")
      # ```
      def self.create(attrs : Hash(Symbol, DB::Any))
        insert.values(attrs).commit.last_insert_id
      end

      # Create a new record with given fields
      # - **@param** fields [Hash(Symbol, DB::Any)] The fields to use
      # - **@return** [PrimaryKey] The ID of the new record
      #
      # **Example** Creating a new record

      # ```
      # user_repo.create(name: "Alice", email: " [email protected]")
      # ```
      def self.create(**fields)
        insert.values(**fields).commit.last_insert_id
      end

      def self.create(record : T)
        insert.values(record.attributes).commit.last_insert_id
      end

      # Return a new update object for the current table
      # - **@return** [Update] The update object
      #
      # **Example** Updating a record
      #
      # ```
      # user_repo.update.set(active: true).where(id: 1).commit
      # ```
      def self.update
        Cql::Update.new(T.schema.not_nil!).table(T.table.not_nil!)
      end

      # Update a record by ID with given attributes
      # - **@param** id [PrimaryKey] The ID of the record
      # - **@param** attrs [Hash(Symbol, DB::Any)] The attributes to update
      #
      # **Example** Updating a record by ID
      #
      # ```
      # user_repo.update(1, active: true)
      # ```
      def self.update(id, attrs : Hash(Symbol, DB::Any))
        update.set(**attrs).where(id: id).commit
      end

      # Update a record by ID with given fields
      # - **@param** id [PrimaryKey] The ID of the record
      # - **@param** fields [Hash(Symbol, DB::Any)] The fields to update
      #
      # **Example** Updating a record by ID
      #
      # ```
      # user_repo.update(1, active: true)
      # ```
      def self.update(id, **fields)
        update.set(**fields).where(id: id).commit
      end

      def self.update(id, record : T)
        update.set(record.attributes).where(id: id).commit
      end

      def self.update(record : T)
        update.set(record.attributes).where(id: record.id).commit
      end

      # Update records matching where attributes with update attributes
      # - **@param** where_attrs [Hash(Symbol, DB::Any)] The attributes to match
      # - **@param** update_attrs [Hash(Symbol, DB::Any)] The attributes to update
      #
      # **Example** Updating records by email
      #
      # ```
      # user_repo.update_by(email: " [email protected]", active: true)
      # ```
      def self.update_by(
        where_attrs : Hash(Symbol, DB::Any),
        update_attrs : Hash(Symbol, DB::Any)
      )
        update.set(**update_attrs).where(**where_attrs).commit
      end

      # Update all records with given attributes
      # - **@param** attrs [Hash(Symbol, DB::Any)] The attributes to update
      #
      # **Example** Updating all records
      #
      # ```
      # user_repo.update_all(active: true)
      # ```
      def self.update_all(attrs : Hash(Symbol, DB::Any))
        update.set(**attrs).commit
      end

      # Return a new delete object for the current table
      # - **@return** [Delete] The delete object
      #
      # **Example** Deleting a record
      #
      # ```
      # user_repo.delete.where(id: 1).commit
      # ```
      def self.delete
        Cql::Delete.new(T.schema.not_nil!).from(T.table.not_nil!)
      end

      # Delete a record by ID
      # - **@param** id [PrimaryKey] The ID of the record
      #
      # **Example** Deleting a record by ID
      #
      # ```
      # user_repo.delete(1)
      # ```
      def self.delete(id)
        delete.where(id: id).commit
      end

      # Delete records matching specific fields
      # - **@param** fields [Hash(Symbol, DB::Any)] The fields to match
      #
      # **Example** Deleting records by email
      #
      # ```
      # user_repo.delete_by(email: " [email protected]")
      # ```
      def self.delete_by(**fields)
        delete.where(**fields).commit
      end

      # Delete all records in the table
      #
      # **Example** Deleting all records
      #
      # ```
      # user_repo.delete_all
      # ```
      def self.delete_all
        delete.commit
      end

      # Count all records in the table
      # - **@return** [Int64] The number of records
      #
      # **Example** Counting all records
      #
      # ```
      # user_repo.count
      # ```
      def self.count
        query.count.first!(Int64)
      end

      # Check if records exist matching specific fields
      # - **@param** fields [Hash(Symbol, DB::Any)] The fields to match
      # - **@return** [Bool] True if records exist, false otherwise
      #
      # **Example** Checking if a record exists by email
      #
      # ```
      # user_repo.exists?(email: " [email protected]")
      # ```
      def self.exists?(**fields)
        query.select.where(**fields).limit(1).first(T) != nil
      rescue DB::NoResultsError
        false
      end

      # Fetch the first record in the table
      # - **@return** [T?] The first record, or nil if the table is empty
      #
      # **Example** Fetching the first record
      #
      # ```
      # user_repo.first
      # ```
      def self.first
        query.order(id: :asc).limit(1).first(T)
      end

      # Fetch the last record in the table
      # - **@return** [T?] The last record, or nil if the table is empty
      #
      # **Example** Fetching the last record
      #
      # ```
      # user_repo.last
      # ```
      def self.last
        query.order(id: :desc).limit(1).first(T)
      end

      # Paginate results based on page number and items per page
      # - **@param** page_number [Int32] The page number to fetch
      # - **@param** per_page [Int32] The number of items per page
      # - **@return** [Array(T)] The records for the page
      #
      # **Example** Paginating results
      #
      # ```
      # user_repo.page(1, 10)
      # ```
      def self.page(page_number, per_page = 10)
        offset = (page_number - 1) * per_page
        query.limit(per_page).offset(offset).all(T)
      end

      # Limit the number of results per page
      # - **@param** per_page [Int32] The number of items per page
      # - **@return** [Array(T)] The records for the page
      #
      # **Example** Limiting results per page
      #
      # ```
      # user_repo.per_page(10)
      # ```
      def self.per_page(per_page)
        query.limit(per_page).all(T)
      end

      # Define instance-level methods for saving and deleting records
      def save
        if @id.nil?
          T.create(self)
        else
          T.update(self)
        end
      end

      def update(fields : Hash(Symbol, DB::Any))
        T.update(fields, where)
      end

      def update(**fields)
        T.update(id, fields)
      end

      def update
        T.update(@id, self) unless @id.nil?
      end

      def delete
        T.delete(@id) unless @id.nil?
      end
    end
  end
end
