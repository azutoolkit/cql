module Cql
  # Write documentation for Record module
  #
  # **Example** Using the Record module
  #
  # ```
  # AcmeDB = Cql::Schema.define(:acme_db, adapter: Cql::Adapter::Postgres,
  #   uri: "postgresql://example:example@localhost:5432/example") do
  #   table :posts do
  #     primary :id, Int64, auto_increment: true
  #     text :title
  #     text :body
  #     timestamp :published_at
  #   end
  #
  #   table :comments do
  #     primary
  #     bigint :post_id
  #     text :body
  #   end
  # end
  #
  # struct Post < Cql::Record(Int64)
  #   db_context AcmeDB, :posts
  #
  #   getter id : Int64?
  #   getter title : String
  #   getter body : String
  #   getter published_at : Time
  #
  #   def initialize(@title : String, @body : String, @published_at : Time = Time.utc)
  #   end
  # end
  #
  # struct Comment < Cql::Record(Int64)
  #   db_context AcmeDB, :comments
  #
  #   getter id : Int64?
  #   getter post_id : Int64
  #   getter body : String
  #
  #   def initialize(@post_id : Int64, @body : String)
  #   end
  # end
  # ```
  abstract struct Record(Pk)
    macro inherited
      include DB::Serializable
      include DB::Serializable::NonStrict
      include Cql::Relations
      @@schema : Cql::Schema? = nil
      @@table : Symbol? = nil

      # Define the schema and table for the record
      # - **@param** schema [Cql::Schema] The schema to use
      # - **@param** table [Symbol] The table to use
      # - **@return** [Nil]
      #
      # **Example** Defining the schema and table
      #
      # ```
      # struct User < Cql::Record(Int64)
      #   db_context AcmeDB, :users
      # end
      # ```
      def self.db_context(schema : Cql::Schema, table : Symbol)
        @@schema = schema
        @@table = table
      end

      # Return the schema for the record
      # - **@return** [Cql::Schema] The schema
      #
      # **Example** Fetching the schema
      #
      # ```
      # User.schema
      # ```
      def self.schema
        @@schema.not_nil!
      end

      # Return the table for the record
      # - **@return** [Symbol] The table
      # **Example** Fetching the table
      # ```
      # User.table
      # ```
      def self.table
        @@table.not_nil!
      end

      # Return the adapter for the schema
      # - **@return** [Cql::Adapter] The adapter
      # **Example** Fetching the adapter
      # ```
      # User.adapter
      # ```
      def self.adapter
        schema.adapter
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
      def self.build(**fields)
        new(**fields)
      end

      # Return a new query object for the current table
      # - **@return** [Query] The query object
      #
      # **Example** Fetching all records
      #
      # ```
      # user_repo.query.all({{@type.id}})
      # user_repo.query.where(active: true).all({{@type.id}})
      # ```
      def self.query
        Cql::Query.new({{@type.id}}.schema).from({{@type.id}}.table)
      end

      # Fetch all records of type T
      # - **@return** [Array({{@type.id}})] The records
      #
      # **Example** Fetching all records
      #
      # ```
      # user_repo.all
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
      # user_repo.find(1)
      # ```
      def self.find(id)
        query.where(id: id).first({{@type.id}})
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
        query.where(id: id).first!({{@type.id}})
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
        query.where(**fields).first({{@type.id}})
      end

      # Find a record by specific fields, raise an error if not found
      # - **@param** fields [Hash(Symbol, DB::Any)] The fields to match
      # - **@return** [T] The record
      #
      # **Example** Fetching a record by email
      # ```
      # user_repo.find_by!(email: " [email protected]")
      # ```
      def self.find_by!(**fields)
        query.where(**fields).first!({{@type.id}})
      end

      # Find all records matching specific fields
      # - **@param** fields [Hash(Symbol, DB::Any)] The fields to match
      # - **@return** [Array({{@type.id}})] The records
      #
      # **Example** Fetching all active users
      #
      # ```
      # user_repo.find_all_by(active: true)
      # ```
      def self.find_all_by(**fields)
        query.where(**fields).all({{@type.id}})
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
        Cql::Insert.new({{@type.id}}.schema).into({{@type.id}}.table)
      end

      # Create a new record with given attributes
      # - **@param** attrs [Hash(Symbol, DB::Any)] The attributes to use
      # - **@return** [PrimaryKey] The ID of the new record
      # **Example** Creating a new record
      # ```
      # user_repo.create(name: "Alice", email: " [email protected]")
      # ```
      def self.create(attrs : Hash(Symbol, DB::Any))
        insert.values(attrs).last_insert_id
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
        insert.values(**fields).last_insert_id
      end

      def self.create(record : {{@type.id}})
        attrs = record.attributes
        attrs.delete(:id)
        create(attrs)
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
        Cql::Update.new({{@type.id}}.schema).table({{@type.id}}.table)
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

      # Update a record by ID with given record
      # - **@param** id [PrimaryKey] The ID of the record
      # - **@param** record [T] The record to update
      #
      # **Example** Updating a record by ID
      #
      # ```
      # User.update(1, name: "Alice", email: " [email protected]")
      # ```
      def self.update(id, fields : Hash(Symbol, DB::Any))
        update.set(**fields).where(id: id).commit
      end

      # Update a record by ID with given record object
      # - **@param** id [PrimaryKey] The ID of the record
      # - **@param** record [T] The record to update
      #
      # **Example** Updating a record by ID
      #
      # ```
      # bob = User.new(name: "Bob", email: " [email protected]")
      # id = bob.save
      #
      # bob.reload!
      #
      # User.update(1, bob)
      # ```
      def self.update(id, record : {{@type.id}})
        update.set(record.attributes).where(id: id).commit
      end

      # Update a record with given attributes
      # - **@param** attrs [Hash(Symbol, DB::Any)] The attributes to update
      # - **@param** where [Hash(Symbol, DB::Any)] The attributes to match
      #
      # **Example** Updating a record by email
      #
      # ```
      # user_repo.update(email: " [email protected]", active: true)
      # ```
      def self.update(record : {{@type.id}})
        attrs = record.attributes
        attrs.delete(:id)
        update.set(attrs).where(id: record.id).commit
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
        Cql::Delete.new({{@type.id}}.schema).from({{@type.id}}.table)
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
        query.count(:id).first!(Int64)
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
      # user_repo.first
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
      # user_repo.last
      # ```
      def self.last
        query.order(id: :desc).limit(1).first({{@type.id}})
      end

      # Paginate results based on page number and items per page
      # - **@param** page_number [Int32] The page number to fetch
      # - **@param** per_page [Int32] The number of items per page
      # - **@return** [Array({{@type.id}})] The records for the page
      #
      # **Example** Paginating results
      #
      # ```
      # user_repo.page(1, 10)
      # ```
      def self.page(page_number, per_page = 10)
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
      # user_repo.per_page(10)
      # ```
      def self.per_page(per_page)
        query.limit(per_page).all({{@type.id}})
      end
    end

    # Define instance-level methods for querying and manipulating data
    # Fetch the record's ID or raise an error if it's nil
    # - **@return** [PrimaryKey] The ID
    #
    # **Example** Fetching the record's ID
    #
    # ```
    # user.reload!
    # ```
    def reload!
      record = {{@type.id}}.find!(id)
      {% for ivar in @type.instance_vars %}
      @{{ ivar }} = record.{{ ivar }}
      {% end %}
    end

    # Check if the record has been persisted to the database
    # - **@return** [Bool] True if the record has an ID, false otherwise
    #
    # **Example** Checking if the record is persisted
    # ```
    # user.persisted?
    # ```
    def persisted?
      !id.nil?
    end

    # Define instance-level methods for saving and deleting records
    # Save the record to the database or update it if it already exists
    # - **@return** [Nil]
    #
    # **Example** Saving the record
    #
    # ```
    # user.save
    # ```
    def save
      if @id.nil?
        @id = {{@type.id}}.create(self).as(Pk)
      else
        {{@type.id}}.update(self)
      end
    end

    # Delete the record from the database if it exists
    # - **@return** [Nil]
    #
    # **Example** Deleting the record
    #
    # ```
    # user.delete
    # ```
    def update(fields : Hash(Symbol, DB::Any))
      {{@type.id}}.update(fields, where)
    end

    # Update the record with the given fields
    # - **@param** fields [Hash(Symbol, DB::Any)] The fields to update
    # - **@return** [Nil]
    #
    # **Example** Updating the record
    #
    # ```
    # user.update(name: "Alice", email: " [email protected]")
    # ```
    def update(**fields)
      {{@type.id}}.update(id, **fields)
    end

    # Update the record with the given record object
    #
    #
    # **Example** Updating the record
    #
    # ```
    # bob = User.new(name: "Bob", email: " [email protected]")
    # id = bob.save
    #
    # bob.reload!
    # bon.name = "Juan"
    #
    # bob.update
    # ```
    def update
      {{@type.id}}.update(id, self) unless id.nil?
    end

    # Delete the record from the database
    # - **@return** [Nil]
    #
    # **Example** Deleting the record
    #
    # ```
    # user.delete
    # ```
    def delete
      {{@type.id}}.delete(id) unless id.nil?
    end

    # Define instance-level methods for querying and manipulating data
    # Fetch the record's ID or raise an error if it's nil
    # - **@return** [PrimaryKey] The ID
    #
    # **Example** Fetching the record's ID
    #
    # ```
    # user.attributes
    # -> { id: 1, name: "Alice", email: " [email protected]" }
    # ```
    def attributes
      hash = Hash(Symbol, DB::Any).new
      {% for ivar in @type.instance_vars %}
        {% unless ivar.annotation(DB::Field) && ivar.annotation(DB::Field).named_args[:ignore] %}
        hash[:{{ ivar }}] = {{ ivar }}
        {% end %}
      {% end %}
      hash
    end

    # Set the record's attributes from a hash
    # - **@param** attrs [Hash(Symbol, DB::Any)] The attributes to set
    # - **@return** [Nil]
    #
    # **Example** Setting the record's attributes
    #
    # ```
    # user.attributes = {name: "Alice", email: "[email protected]"}
    # ```
    def attributes(attrs : Hash(Symbol, DB::Any))
      attrs.each do |key, value|
        {% for ivar in @type.instance_vars %}
        @{{ivar.id}} = value if key == :{{ivar.id}} && value.is_a?({{ivar.type}})
        {% end %}
      end
    end

    # Identity method for the record ID
    # - **@return** [PrimaryKey] The ID
    #
    # **Example** Fetching the record's ID
    #
    # ```
    # user.id
    # ```
    def id
      @id.not_nil!
    end

    # Set the record's ID
    # - **@param** id [PrimaryKey] The ID
    #
    # **Example** Setting the record's ID
    #
    # ```
    # user.id = 1
    # ```
    def id=(id : Pk)
      @id = id
    end
  end
end
