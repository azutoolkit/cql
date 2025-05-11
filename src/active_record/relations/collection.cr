module CQL::ActiveRecord::Relations
  # A collection of records for a one to many relationship
  # This class is used to manage the relationship between two tables
  # through a foreign key column in the target table
  # and provide methods to manage the association between the two tables
  # and query records in the associated table based on the foreign key value
  # of the parent record.
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

    @records : Array(Target) = [] of Target
    @target_table : Symbol
    @loaded : Bool = false
    forward_missing_to @records

    # Initialize the collection class for a one-to-many relationship
    # - **param** : key (Symbol) - The foreign key in the target table (e.g., :user_id)
    # - **param** : id (Pk) - The id value for the parent record
    # - **param** : cascade (Bool) - Whether to delete associated records when parent is deleted
    # - **param** : query (CQL::Query) - Base query object for the relationship
    # - **param** : auto_load (Bool) - Whether to automatically load associated records
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
      @key : Symbol,                                                          # foreign key (e.g., user_id)
      @id : Pk,                                                               # parent id value
      @cascade : Bool = false,                                                # delete associated records
      @query : CQL::Query = CQL::Query.new(Target.schema).from(Target.table), # query object
      auto_load : Bool = true,                                                # automatically load records
    )
      @target_table = Target.table
      @records = [] of Target
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
      @records = @query.where({@key => @id}).all(Target)
      @loaded = true
      @records
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
      @records.map(&.id!)
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
      @records << create(record)
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
    #
    # **Example**
    #
    # ```
    # user.posts.exists?(title: "Hello World")
    # => true
    # ```
    def exists?(**attributes)
      # Directly check for existence without creating a hash
      @query.where(**attributes).where({@key => @id}).limit(1).first(Target) != nil
    rescue DB::NoResultsError | CQL::Schema::ConnectionError
      false
    end

    # Returns the first record in the collection
    # - **return** : Target?
    #
    # **Example**
    #
    # ```
    # user.posts.first
    # => #<Post:0x00007f8b3b1b3f00 @id=1, @title="Hello World">
    # ```
    def first
      load_records unless @loaded
      @records.first
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
      @query.where({@key => @id}).where(**attributes).all(Target)
    end

    # Finds a single record by attributes
    # - **param** : attributes (NamedTuple | Hash(Symbol, DB::Any))
    # - **return** : Target?
    #
    # **Example**
    #
    # ```
    # user.posts.find_by(title: "Hello World")
    # => #<Post:0x00007f8b3b1b3f00 @id=1, @title="Hello World">
    # ```
    def find_by(**attributes)
      @query.where({@key => @id}).where(**attributes).first(Target)
    rescue DB::NoResultsError
      nil
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
      record = Target.build(**attributes)
      record.attributes({@key => @id})
      record
    end

    # Creates a new record with the given attributes and saves it
    # - **param** : attributes (NamedTuple | Hash(Symbol, DB::Any))
    # - **return** : Target
    # - **raise** : CQL::Error
    #
    # **Example**
    #
    # ```
    # user.posts.create(title: "Hello World")
    # => #<Post:0x00007f8b3b1b3f00 @id=1, @title="Hello World">
    # ```
    def create(**attributes)
      record = build(**attributes)
      @records << Target.create!(record)
      record
    end

    # Create a new record and associate it with the parent record
    # - **param** : attributes (Hash(Symbol, String | Int64))
    # - **return** : Array(Target)
    # - **raise** : CQL::Error
    #
    # **Example**
    #
    # ```
    # movie.actors.create!(name: "Hugo Weaving")
    # movie.actors.reload
    # movie.actors.all
    # => [#<Actor:0x00007f8b3b1b3f00 @id=1, @name="Hugo Weaving">]
    # ```
    def create(record : Target)
      record.attributes({@key => @id})
      @records << Target.create!(record)
      record
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
      delete(record.id!)
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
      CQL::Delete
        .new(Target.schema)
        .from(Target.table)
        .where({:id => id, @key => @id})
        .commit
      reload
      true
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
      # Then, create new associations
      ids.each do |id|
        Target.update_by(
          where_attrs: {:id => id}, update_attrs: {@key => @id})
      end

      reload
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

    # Clears all associated records from the parent record
    # - **return** : Int64 - Number of records deleted
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
      records_deleted = 0

      if @cascade
        # Get target IDs before deleting associations
        load_records unless @loaded
        target_ids = @records.map(&.id!)

        # Delete associations
        records_deleted = CQL::Delete
          .new(Target.schema)
          .from(Target.table)
          .where({@key => @id})
          .commit
          .rows_affected

        # Delete target records
        target_ids.each do |id|
          Target.delete!(id)
        end
      else
        # Just delete associations
        records_deleted = CQL::Delete
          .new(Target.schema)
          .from(Target.table)
          .where({@key => @id})
          .commit
          .rows_affected
      end

      reload
      records_deleted
    end
  end
end
