require "./base_relation"

module CQL::ActiveRecord::Relations
  # Logger for deprecation warnings
  Log = ::Log.for("CQL::Relations")

  # Collection for one-to-many relationships.
  #
  # This class manages the relationship between two tables through a foreign key
  # column in the target table and provides methods to manage the association
  # between the two tables and query records in the associated table based on
  # the foreign key value of the parent record.
  # - **param** : Target (CQL::ActiveRecord::Model) - The target model
  # - **param** : Pk - The parent's primary key type
  #
  # `has_many` returns one, for example `has_many :posts, Post, foreign_key: :user_id` in `User`:
  #
  # ```
  # user.posts.create(title: "Hello World")
  # user.posts.size # => 1
  # ```
  class Collection(Target, Pk)
    include Enumerable(Target)
    include BaseRelation

    getter binding : CQL::Binding?
    @base_query : CQL::Query?
    @scoped_query : CQL::Query?
    @records : Array(Target) = [] of Target
    @target_table : Symbol
    @loaded : Bool = false
    @dependent : Symbol = :nullify

    # Initialize the collection class for a one-to-many relationship
    # - **param** : key (Symbol) - The foreign key in the target table (e.g., :user_id)
    # - **param** : id (Pk) - The id value for the parent record
    # - **param** : cascade (Bool) - Whether to delete associated records when parent is deleted (deprecated, use dependent)
    # - **param** : query (CQL::Query) - Base query; the collection scopes it to the parent and operations run on clones of it
    # - **param** : auto_load (Bool) - Whether to automatically load associated records
    # - **param** : dependent (Symbol) - Dependency handling strategy
    # - **return** : Collection(Target, Pk)
    #
    # **Example**
    #
    # ```
    # CQL::ActiveRecord::Relations::Collection(Post, Int64).new(
    #   :user_id,
    #   1_i64,
    #   query: CQL::Query.new(Post.schema).from(Post.table),
    #   dependent: :destroy
    # )
    # ```
    def initialize(
      @key : Symbol,                         # foreign key (e.g., user_id)
      @id : Pk,                              # parent id value
      @cascade : Bool = false,               # delete associated records (deprecated)
      query @base_query : CQL::Query? = nil, # base query; scoped to the parent on first use
      auto_load : Bool = false,              # automatically load records
      @dependent : Symbol = :nullify,        # dependency strategy
      @binding : CQL::Binding? = nil,
    )
      @binding ||= @base_query.try(&.schema.binding)
      @target_table = Target.table
      @records = [] of Target

      # Handle legacy cascade parameter with deprecation warning
      if @cascade
        Log.warn { "DEPRECATION WARNING: The 'cascade' parameter is deprecated and will be removed in v1.0.0. Use 'dependent: :destroy' instead." }
        @dependent = :destroy if @dependent == :nullify
      end

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
    # ```
    def all : Array(Target)
      load_records unless @loaded
      @records
    end

    # Execute a query and return results of specified type
    # This is used for method chaining with where, limit, offset, etc.
    # - **param** : type (Class) - The model type to return
    # - **return** : Array(T)
    #
    # **Example**
    #
    # ```
    # user.posts.offset(2).all(Post)
    # ```
    def all(type : T.class) : Array(T) forall T
      # This method should not be called on the collection directly
      # It's only available after chaining query methods
      load_records unless @loaded
      @records.as(Array(T))
    end

    # Reloads the association records from the database
    # - **return** : Array(Target)
    #
    # **Example**
    #
    # ```
    # user.posts.reload
    # ```
    def reload
      @records = safe_db_operation do
        query_copy.all(Target)
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

    # Inject preloaded records without database query
    # Used by eager loading/preload to set association data that was
    # loaded in a batch query to avoid N+1 queries.
    # - **param** : records (Array(Target)) - The preloaded records
    # - **return** : Nil
    def _inject_preloaded(records : Array(Target)) : Nil
      @records = records
      @loaded = true
    end

    # Returns a list of primary keys for the associated records
    # - **return** : Array(Pk)
    #
    # **Example**
    #
    # ```
    # user.posts.ids
    # ```
    def ids : Array(Pk)
      load_records unless @loaded
      @records.compact_map(&.id).map(&.as(Pk))
    end

    # Adds a record to the collection, as `create(record)` does.
    # - **param** : record (Target)
    # - **return** : Array(Target)
    # - **raise** : CQL::RecordInvalid when a saved record fails its validations
    #
    # **Example**
    #
    # ```
    # user.posts << Post.new(title: "Hello World")
    # ```
    def <<(record : Target)
      record = record.with_binding(binding)
      load_records unless @loaded
      created_record = create(record)
      # a reload hides a soft-deleted record
      @records << created_record if created_record.persisted? && !includes?(created_record)
      @records
    end

    # Checks if the collection is empty
    # - **return** : Bool
    #
    # **Example**
    # ```
    # user.posts.empty?
    # ```
    def empty?
      return @records.empty? if @loaded

      safe_db_operation { !query_builder(query_copy).exists? }
    end

    # Checks if any records exist with the given attributes
    # - **param** : attributes (NamedTuple)
    # - **return** : Bool
    def exists?(**attributes)
      return !empty? if attributes.empty?

      safe_db_operation { query_builder(query_copy).exists?(**attributes) }
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
        query_copy.count.get(Int64?) || 0_i64
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
    # ```
    def find(**attributes)
      safe_db_operation do
        query_copy.where(**attributes).all(Target)
      end
    end

    # Finds a single record by attributes
    # - **param** : attributes (NamedTuple | Hash(Symbol, DB::Any))
    # - **return** : Target?
    def find_by(**attributes)
      safe_db_operation do
        query_copy.where(**attributes).first(Target)
      rescue DB::NoResultsError
        nil
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
        record = Target.new(**attributes).with_binding(binding)
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

    # Associates *record* with the parent: a new record is inserted without validations, a saved
    # one (soft-deleted included) gets its foreign key updated with `save!`.
    # - **param** : record (Target)
    # - **return** : Target
    # - **raise** : RelationError, or CQL::RecordInvalid when a saved record fails its validations
    def create(record : Target)
      record = record.with_binding(binding)
      record.attributes({@key => @id})
      safe_db_operation do
        if record.new_record?
          record = Target.on(binding).create!(record)
        else
          record.save!
        end
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
    # post = user.posts.create(title: "Hello World")
    # user.posts.delete(post) # => true
    # ```
    def delete(record : Target)
      record = record.with_binding(binding)
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
    # post = user.posts.create(title: "Hello World")
    # user.posts.delete(post.id!) # => true
    # ```
    def delete(id : Pk)
      result = safe_db_operation do
        CQL::Delete
          .new(Target.on(binding).schema)
          .from(Target.table)
          .where({Target.primary_key_column => bound_id(id), @key => bound_id(@id)})
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
          .new(Target.on(binding).schema)
          .from(Target.table)
          .where({@key => bound_id(@id)})
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
          .new(Target.on(binding).schema)
          .table(Target.table)
          .set({@key => nil})
          .where({@key => bound_id(@id)})
          .commit
          .rows_affected
      end

      if @loaded
        @records.each(&.attributes({@key => nil}))
        @records.clear # Clear the collection since records are no longer associated
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
    # user.posts.ids = [1_i64, 2_i64, 3_i64]
    # ```
    def ids=(ids : Array(Pk))
      safe_db_operation do
        target_key = Expression::Column.new(Target.cql_column(Target.primary_key_column))
        CQL::ActiveRecord::IdChunks.each(ids, Target.adapter.dialect.max_bind_params - 1) do |chunk|
          CQL::Update.new(Target.on(binding).schema).table(Target.table).set({@key => bound_id(@id)}).where { target_key.in(chunk) }.commit
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
    # user.posts.where(title: "Hello").where(published: true).all(Post)
    # ```
    def where(**conditions)
      query_copy.where(**conditions)
    end

    # A raw SQL fragment with bound `?` / `:name` values, scoped to this association.
    def where(__sql sql : String, *positional, **named)
      query_copy.where(sql, *positional, **named)
    end

    # Apply a limit to the query
    # - **param** : limit_count (Int32)
    # - **return** : CQL::Query
    def limit(limit_count : Int32)
      query_copy.limit(limit_count)
    end

    # Apply an offset to the query
    # - **param** : offset_count (Int32)
    # - **return** : CQL::Query
    def offset(offset_count : Int32)
      query_copy.offset(offset_count)
    end

    # Order the query results, for example `user.posts.order(created_at: :desc)`
    # - **param** : order_by (column: direction) - each column with :asc or :desc
    # - **return** : CQL::Query
    def order(**order_by)
      query_copy.order(**order_by)
    end

    # Clears all associated records from the parent record with the association's `dependent:`
    # strategy (`:destroy`, `:delete_all`, or `:nullify`, the default, which needs a nullable foreign key)
    # - **return** : Int64 - Number of records affected
    #
    # **Example**
    # ```
    # user.posts.create(title: "Hello World")
    # user.posts.clear
    # ```
    def clear
      records_affected = 0_i64

      case @dependent
      when :destroy
        # Call destroy on each record (triggers callbacks)
        load_records unless @loaded
        all_or_none do
          @records.each do |record|
            record = record.with_binding(binding)
            safe_db_operation { record.delete! }
            records_affected += 1
          end
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

    # Runs a destroy in one transaction on the target's schema (a savepoint inside an open one), so a target whose
    # `delete!` raises (a stale one) rolls back the deletes before it, and a rollback has the collection load its rows
    # again. Statements on another schema, such as a many_to_many join table's, run outside it.
    private def all_or_none(&)
      Target.on(binding).schema.transaction do
        Target.on(binding).schema.on_rollback { @loaded = false }
        yield
      end
    end

    # Check if the collection includes a specific record
    # - **param** : record (Target)
    # - **return** : Bool
    def includes?(record : Target) : Bool
      record = record.with_binding(binding)
      load_records unless @loaded
      @records.any? { |local_record| local_record.id == record.id }
    end

    # Explicitly implement Enumerable methods that use blocks to avoid forwarding issues

    # Map over the collection
    # - **param** : block (Block(Target, U))
    # - **return** : Array(U)
    def map(&block : Target -> U) forall U
      load_records unless @loaded
      @records.map(&block)
    end

    # Select records matching the given block
    # - **param** : block (Block(Target, Bool))
    # - **return** : Array(Target)
    def select(&block : Target -> Bool)
      load_records unless @loaded
      @records.select(&block)
    end

    # Reject records matching the given block
    # - **param** : block (Block(Target, Bool))
    # - **return** : Array(Target)
    def reject(&block : Target -> Bool)
      load_records unless @loaded
      @records.reject(&block)
    end

    # Find the first record matching the given block
    # - **param** : block (Block(Target, Bool))
    # - **return** : Target?
    def find(&block : Target -> Bool)
      load_records unless @loaded
      @records.find(&block)
    end

    # Check if any record matches the given block
    # - **param** : block (Block(Target, Bool))
    # - **return** : Bool
    def any?(&block : Target -> Bool)
      load_records unless @loaded
      @records.any?(&block)
    end

    # Check if all records match the given block
    # - **param** : block (Block(Target, Bool))
    # - **return** : Bool
    def all?(&block : Target -> Bool)
      load_records unless @loaded
      @records.all?(&block)
    end

    # Get element at index, returns nil if out of bounds
    # - **param** : index (Int32)
    # - **return** : Target?
    def []?(index : Int32)
      load_records unless @loaded
      @records[index]?
    end

    # Get element at index, raises if out of bounds
    # - **param** : index (Int32)
    # - **return** : Target
    def [](index : Int32)
      load_records unless @loaded
      @records[index]
    end

    # Convert to array
    # - **return** : Array(Target)
    def to_a
      load_records unless @loaded
      @records.dup
    end

    # Each with index
    # - **param** : block (Block(Target, Int32))
    # - **return** : Nil
    def each_with_index(&block : Target, Int32 ->)
      load_records unless @loaded
      @records.each_with_index(&block)
    end

    # Map with index
    # - **param** : block (Block(Target, Int32, U))
    # - **return** : Array(U)
    def map_with_index(&block : Target, Int32 -> U) forall U
      load_records unless @loaded
      @records.map_with_index(&block)
    end

    # Get the length/size of the collection
    # - **return** : Int32
    def length
      size
    end

    # Add multiple records to the collection
    # - **param** : records (Array(Target))
    # - **return** : Array(Target)
    def concat(records : Array(Target)) : Array(Target)
      load_records unless @loaded

      records.each do |record|
        record = record.with_binding(binding)
        next if includes?(record)
        record.attributes({@key => @id})
        safe_db_operation { record.save! }
        @records << record if record.persisted? # a reload hides a soft-deleted record
      end

      @records
    end

    # Remove records from the collection without deleting them
    # - **param** : records (Array(Target))
    # - **return** : Array(Target)
    def remove(records : Array(Target)) : Array(Target)
      load_records unless @loaded

      records.each do |record|
        record = record.with_binding(binding)
        if includes?(record)
          record.attributes({@key => nil})
          safe_db_operation { record.save! }
          @records.reject! { |local_record| local_record.id == record.id }
        end
      end

      @records
    end

    # Scopes the base query to the parent record; the caller's query is never mutated.
    protected def scope_to_parent(query : CQL::Query) : CQL::Query
      query.clone.where({@key => bound_id(@id)})
    end

    private def query_builder(query : CQL::Query) : CQL::ActiveRecord::Queryable::QueryBuilder(Target)
      CQL::ActiveRecord::Queryable::QueryBuilder(Target).new(query, Target)
    end

    # *id* as a bound value (UUIDs as strings)
    private def bound_id(id) : DB::Any
      CQL::ActiveRecord::IdChunks.bound(id)
    end

    private def query_copy : CQL::Query
      (@scoped_query ||= scope_to_parent(@base_query || build_query(Target))).clone
    end
  end
end
