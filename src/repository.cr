module Cql
  # A repository for a specific table
  # This class provides a high-level interface for interacting with a table
  # It provides methods for querying, creating, updating, and deleting records
  # It also provides methods for pagination and counting records
  #
  # **Example** Creating a new repository
  #
  # ```
  # class UserRepository < Cql::Repository(User)
  #  def initialize(@schema : Schema, @table : Symbol)
  # end
  #
  # user_repo = UserRepository.new(schema, :users)
  # user_repo.all
  # user_repo.find(1)
  # ```
  class Repository(T)
    getter query : Cql::Query
    getter insert : Cql::Insert
    getter update : Cql::Update
    getter delete : Cql::Delete

    # Initialize the repository with a schema and table name
    #
    # - **@param** schema [Schema] The schema to use
    # - **@param** table [Symbol] The name of the table
    # - **@return** [Repository] The repository object
    #
    # **Example** Creating a new repository
    #
    # ```
    # class UserRepository < Cql::Repository(User)
    # end
    #
    # user_repo = UserRepository.new(schema, :users
    # ```
    def initialize(@schema : Schema, @table : Symbol)
      @query = Query.new(@schema).from(@table)
      @insert = Insert.new(@schema).into(@table)
      @update = Update.new(@schema).table(@table)
      @delete = Delete.new(@schema).from(@table)
    end

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
    def build(attrs : Hash(Symbol, DB::Any))
      T.new(attrs)
    end

    # Fetch all records of type T
    # - **@return** [Array(T)] The records
    #
    # **Example** Fetching all records
    #
    # ```
    # user_repo.all
    # ```
    def all
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
    def find(id)
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
    def find!(id)
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
    def find_by(**fields)
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
    def find_all_by(**fields)
      query.where(**fields).all(T)
    end

    # Create a new record with given attributes
    # - **@param** attrs [Hash(Symbol, DB::Any)] The attributes to use
    # - **@return** [PrimaryKey] The ID of the new record
    # **Example** Creating a new record
    # ```
    # user_repo.create(name: "Alice", email: " [email protected]")
    # ```
    def create(attrs : Hash(Symbol, DB::Any))
      insert.values(attrs).commit.last_insert_id
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
    def update(id, attrs : Hash(Symbol, DB::Any))
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
    def update(id, **fields)
      update.set(**fields).where(id: id).commit
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
    def update_by(
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
    def update_all(attrs : Hash(Symbol, DB::Any))
      update.set(**attrs).commit
    end

    # Delete a record by ID
    # - **@param** id [PrimaryKey] The ID of the record
    #
    # **Example** Deleting a record by ID
    #
    # ```
    # user_repo.delete(1)
    # ```
    def delete(id)
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
    def delete_by(**fields)
      delete.where(**fields).commit
    end

    # Delete all records in the table
    #
    # **Example** Deleting all records
    #
    # ```
    # user_repo.delete_all
    # ```
    def delete_all
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
    def count
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
    def exists?(**fields)
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
    def first
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
    def last
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
    def page(page_number, per_page = 10)
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
    def per_page(per_page)
      query.limit(per_page).all(T)
    end
  end
end
