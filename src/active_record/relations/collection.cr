require "./base_relation"

module CQL::ActiveRecord::Relations
  # Enhanced collection class for one-to-many relationships with improved
  # type safety, error handling, and performance optimizations.
  #
  # This class manages the relationship between two tables through a foreign key
  # column in the target table and provides methods to manage the association
  # between the two tables and query records in the associated table based on
  # the foreign key value of the parent record.
  # - **param** : Target (CQL::Model) - The target model
  # - **param** : Pk (Int64) - The primary key type
  # - **return** : Nil
  #
  # **Example**
  #
  # ```
  # class User
  #   include CQL::ActiveRecord::Model(Int64)
  #   property id : Int64
  #   property name : String
  #   has_many :posts, Post, foreign_key: :user_id
  # end
  # ```
  class Collection(Target, Pk)
    include Enumerable(Target)
    include BaseRelation

    @records : Array(Target) = [] of Target
    @target_table : Symbol
    @loaded : Bool = false
    @dependent : Symbol = :nullify
    forward_missing_to @records

    # Initialize the collection class for a one-to-many relationship
    # - **param** : key (Symbol) - The foreign key in the target table (e.g., :user_id)
    # - **param** : id (Pk) - The id value for the parent record
    # - **param** : cascade (Bool) - Whether to delete associated records when parent is deleted (deprecated, use dependent)
    # - **param** : query (CQL::Query) - Base query object for the relationship
    # - **param** : auto_load (Bool) - Whether to automatically load associated records
    # - **param** : dependent (Symbol) - Dependency handling strategy
    # - **return** : Collection(Target, Pk)
    #
    # **Example**
    #
    # ```
    # Collection(Post, Int64).new(
    #   :user_id,
    #   1,
    #   cascade: true,
    #   query: CQL::Query.new(Post.schema).from(Post.table)
    # )
    # ```
    def initialize(
      @key : Symbol,                             # foreign key (e.g., user_id)
      @id : Pk,                                  # parent id value
      @cascade : Bool = false,                   # delete associated records (deprecated)
      @query : CQL::Query = build_query(Target), # query object
      auto_load : Bool = false,                  # automatically load records
      @dependent : Symbol = :nullify,            # dependency strategy
    )
      @target_table = Target.table
      @records = [] of Target

      # Handle legacy cascade parameter
      @dependent = :destroy if @cascade && @dependent == :nullify

      reload if auto_load
    end

    # Implements the each method for the Enumerable module
    # - **param** : block (Block(Target))
    # - **return** : Nil
    def each(&block : Target ->)
      load_records unless @loaded
      @records.each(&block)
    end

    # Returns all associated records
    # - **return** : Array(Target)
    #
    # **Example**
    #
    # ```
    # user.posts.all
    # => [#<Post:0x00007f8b3b1b3f00 @id=1, @title="Hello World">]
    # ```
    def all : Array(Target)
      load_records unless @loaded
      @records
    end

    # Reloads the association records from the database
    # - **return** : Array(Target)
    #
    # **Example**
    #
    # ```
    # user.posts.reload
    # => [#<Post:0x00007f8b3b1b3f00 @id=1, @title="Hello World">]
    # ```
    def reload
      @records = safe_db_operation do
        @query.where({@key => @id}).all(Target)
      end
      @loaded = true
      @records
    end

    # Check if the collection has been loaded
    # - **return** : Bool
    def loaded? : Bool
      @loaded
    end

    # Loads records if they haven't been loaded yet
    # - **return** : Array(Target)
    private def load_records
      reload unless @loaded
    end

    # Returns a list of primary keys for the associated records
    # - **return** : Array(Pk)
    #
    # **Example**
    #
    # ```
    # user.posts.ids
    # => [1, 2, 3]
    # ```
    def ids : Array(Pk)
      load_records unless @loaded
      @records.compact_map(&.id).map(&.as(Pk))
    end

    # Adds a record to the collection and saves it to the database
    # - **param** : record (Target)
    # - **return** : Array(Target)
    #
    # **Example**
    #
    # ```
    # user.posts << Post.new(title: "Hello World")
    # => [#<Post:0x00007f8b3b1b3f00 @id=1, @title="Hello World">]
    # ```
    def <<(record : Target)
      load_records unless @loaded
      created_record = create(record)
      @records << created_record unless @records.includes?(created_record)
      @records
    end

    # Checks if the collection is empty
    # - **return** : Bool
    #
    # **Example**
    # ```
    # user.posts.empty?
    # => true
    # ```
    def empty?
      load_records unless @loaded
      @records.empty?
    end

    # Checks if any records exist with the given attributes
    # - **param** : attributes (NamedTuple)
    # - **return** : Bool
    def exists?(**attributes)
      safe_db_operation do
        # Get IDs of associated records
        associated_ids = ids
        return false if associated_ids.empty?

        # Check if any associated records match the given attributes
        results = Target.where(**attributes)
          .where(id: associated_ids)
          .all
        !results.empty?
      end
    end

    # Returns the first record in the collection
    # - **return** : Target?
    def first?
      load_records unless @loaded
      @records.first?
    end

    # Returns the first record in the collection, raises if none found
    # - **return** : Target
    # - **raise** : AssociationNotFound if no records exist
    def first
      result = first?
      raise AssociationNotFound.new("No records found in collection") if result.nil?
      result
    end

    # Returns the last record in the collection
    # - **return** : Target?
    def last?
      load_records unless @loaded
      @records.last?
    end

    # Returns the last record in the collection, raises if none found
    # - **return** : Target
    # - **raise** : AssociationNotFound if no records exist
    def last
      result = last?
      raise AssociationNotFound.new("No records found in collection") if result.nil?
      result
    end

    # Returns the number of associated records
    # - **return** : Int32
    #
    # **Example**
    #
    # ```
    # user.posts.size
    # => 1
    # ```
    def size
      load_records unless @loaded
      @records.size
    end

    # Count records directly from database without loading
    # - **return** : Int64
    def count : Int64
      return @records.size.to_i64 if @loaded

      safe_db_operation do
        @query.where({@key => @id}).count
      end
    end

    # Find associated records matching the given attributes
    # - **param** : attributes (NamedTuple | Hash(Symbol, DB::Any))
    # - **return** : Array(Target)
    #
    # **Example**
    #
    # ```
    # user.posts.find(title: "Hello World")
    # => [#<Post:0x00007f8b3b1b3f00 @id=1, @title="Hello World">]
    # ```
    def find(**attributes)
      safe_db_operation do
        @query.where({@key => @id}).where(**attributes).all(Target)
      end
    end

    # Finds a single record by attributes
    # - **param** : attributes (NamedTuple | Hash(Symbol, DB::Any))
    # - **return** : Target?
    def find_by(**attributes)
      safe_db_operation do
        begin
          @query.where({@key => @id}).where(**attributes).first(Target)
        rescue DB::NoResultsError
          nil
        end
      end
    end

    # Creates a new, unsaved record with the parent association set
    # - **param** : attributes (NamedTuple | Hash(Symbol, DB::Any))
    # - **return** : Target
    #
    # **Example**
    #
    # ```
    # post = user.posts.build(title: "New Post")
    # post.save! # => true
    # ```
    def build(**attributes)
      safe_db_operation do
        record = Target.new(**attributes)
        record.attributes({@key => @id})
        record
      end
    end

    # Creates a new record with the given attributes and saves it
    # - **param** : attributes (NamedTuple | Hash(Symbol, DB::Any))
    # - **return** : Target
    # - **raise** : RelationError
    #
    # **Example**
    #
    # ```
    # user.posts.create(title: "Hello World")
    # => #<Post:0x00007f8b3b1b3f00 @id=1, @title="Hello World">
    # ```
    def create(**attributes)
      record = build(**attributes)
      safe_db_operation do
        record.create!
        # Add to internal array if loaded
        @records << record if @loaded
        record
      end
    end

    # Create and associate an existing record with the parent record
    # - **param** : record (Target)
    # - **return** : Target
    # - **raise** : RelationError
    def create(record : Target)
      record.attributes({@key => @id})
      safe_db_operation do
        Target.create!(record)
        record
      end
    end

    # Delete the associated record from the parent record if it exists
    # - **param** : record (Target)
    # - **return** : Bool
    #
    # **Example**
    #
    # ```
    # movie.actors.create(name: "Carrie-Anne Moss")
    # movie.actors.reload
    # movie.actors.all => 1
    #
    # movie.actors.delete(Actor.find(1))
    # movie.actors.reload
    # movie.actors.all
    #
    # => [] of Actor
    # ```
    def delete(record : Target)
      record_id = safe_id(record, Pk)
      delete(record_id)
    end

    # Delete the associated record from the parent record if it exists
    # - **param** : id (Pk)
    # - **return** : Bool
    #
    # **Example**
    #
    # ```
    # movie.actors.create(name: "Carrie-Anne Moss")
    # movie.actors.reload
    # movie.actors.all => 1
    # movie.actors.delete(1)
    # movie.actors.reload
    # movie.actors.all => []
    # ```
    def delete(id : Pk)
      result = safe_db_operation do
        CQL::Delete
          .new(Target.schema)
          .from(Target.table)
          .where({:id => id, @key => @id})
          .commit
          .rows_affected > 0
      end

      if result && @loaded
        @records.reject! { |record| record.id == id }
      end

      result
    end

    # Delete all associated records
    # - **return** : Int64 - Number of records deleted
    def delete_all : Int64
      result = safe_db_operation do
        CQL::Delete
          .new(Target.schema)
          .from(Target.table)
          .where({@key => @id})
          .commit
          .rows_affected
      end

      if @loaded
        @records.clear
      end

      result
    end

    # Set all foreign keys to nil (nullify association)
    # - **return** : Int64 - Number of records updated
    def nullify_all : Int64
      result = safe_db_operation do
        CQL::Update
          .new(Target.schema)
          .table(Target.table)
          .set({@key => nil})
          .where({@key => @id})
          .commit
          .rows_affected
      end

      if @loaded
        @records.each(&.attributes({@key => nil}))
      end

      result
    end

    # Associates the parent record with the records that match the primary keys provided
    # - **param** : ids (Array(Pk))
    # - **return** : Array(Target)
    #
    # **Example**
    #
    # ```
    # movie.actors.ids = [1, 2, 3]
    # movie.actors.reload
    # movie.actors.all => [
    # #<Actor:0x00007f8b3b1b3f00 @id=1, @name="Carrie-Anne Moss">,
    #    #<Actor:0x00007f8b3b1b3f00 @id=2, @name="Hugo Weaving">,
    #   #<Actor:0x00007f8b3b1b3f00 @id=3, @name="Laurence Fishburne">]
    # ```
    def ids=(ids : Array(Pk))
      safe_db_operation do
        # Update records to associate with parent
        ids.each do |id|
          Target.update_by(
            where_attrs: {:id => id},
            update_attrs: {@key => @id}
          )
        end

        reload
      end
    end

    # Returns a new query for chaining where conditions
    # - **param** : conditions (NamedTuple | Hash(Symbol, DB::Any))
    # - **return** : CQL::Query
    #
    # **Example**
    #
    # ```
    # user.posts.where(title: "Hello").where(published: true).all
    # => [#<Post:0x00007f8b3b1b3f00 @id=1, @title="Hello", @published=true>]
    # ```
    def where(**conditions)
      @query.where({@key => @id}).where(**conditions)
    end

    # Apply a limit to the query
    # - **param** : limit_count (Int32)
    # - **return** : CQL::Query
    def limit(limit_count : Int32)
      @query.where({@key => @id}).limit(limit_count)
    end

    # Apply an offset to the query
    # - **param** : offset_count (Int32)
    # - **return** : CQL::Query
    def offset(offset_count : Int32)
      @query.where({@key => @id}).offset(offset_count)
    end

    # Order the query results
    # - **param** : column (Symbol)
    # - **param** : direction (Symbol) - :asc or :desc
    # - **return** : CQL::Query
    def order(column : Symbol, direction : Symbol = :asc)
      @query.where({@key => @id}).order(column, direction)
    end

    # Clears all associated records from the parent record
    # - **return** : Int64 - Number of records affected
    #
    # **Example**
    # ```
    # user.posts.create(title: "Hello World")
    # user.posts.reload
    # user.posts.size => 1
    # user.posts.clear
    # user.posts.reload
    # user.posts.size => 0
    # ```
    def clear
      records_affected = 0

      case @dependent
      when :destroy
        # Call destroy on each record (triggers callbacks)
        load_records unless @loaded
        @records.each do |record|
          safe_db_operation { record.delete! }
          records_affected += 1
        end
      when :delete_all
        # Delete records without callbacks (more efficient)
        records_affected = delete_all
      when :nullify
        # Set foreign keys to nil
        records_affected = nullify_all
      else
        # Default to nullify for backward compatibility
        records_affected = nullify_all
      end

      reload if @loaded
      records_affected
    end

    # Check if the collection includes a specific record
    # - **param** : record (Target)
    # - **return** : Bool
    def includes?(record : Target) : Bool
      load_records unless @loaded
      @records.any? { |local_record| local_record.id == record.id }
    end

    # Add multiple records to the collection
    # - **param** : records (Array(Target))
    # - **return** : Array(Target)
    def concat(records : Array(Target)) : Array(Target)
      load_records unless @loaded

      records.each do |record|
        next if includes?(record)
        record.attributes({@key => @id})
        safe_db_operation { record.save! }
        @records << record
      end

      @records
    end

    # Remove records from the collection without deleting them
    # - **param** : records (Array(Target))
    # - **return** : Array(Target)
    def remove(records : Array(Target)) : Array(Target)
      load_records unless @loaded

      records.each do |record|
        if includes?(record)
          record.attributes({@key => nil})
          safe_db_operation { record.save! }
          @records.reject! { |local_record| local_record.id == record.id }
        end
      end

      @records
    end
  end
end
