module Cql::Relations
  # A collection of records for a one to many relationship
  # This class is used to manage the relationship between two tables
  # through a foreign key column in the target table
  # and provide methods to manage the association between the two tables
  # and query records in the associated table based on the foreign key value
  # of the parent record.
  # - **param** : Target (Cql::Model) - The target model
  # - **param** : Pk (Int64) - The primary key type
  # - **return** : Nil
  #
  # **Example**
  #
  # ```
  # class User
  #   include Cql::Model(User, Int64)
  #   property id : Int64
  #   property name : String
  #   has_many :posts, Post, foreign_key: :user_id
  # end
  # ```
  class Collection(Target, Pk)
    @records : Array(Target) = [] of Target
    @target_table : Symbol

    # Initialize the many-to-many association collection class
    # - **param** : key (Symbol) - The key for the parent record
    # - **param** : id (Pk) - The id value for the parent record
    # - **param** : target_key (Symbol) - The key for the associated record
    # - **param** : cascade (Bool) - Delete associated records
    # - **param** : query (Cql::Query) - Query object
    # - **return** : ManyCollection
    #
    # **Example**
    #
    # ```
    # ManyCollection.new(
    #   :movie_id,
    #   1,
    #   :actor_id,
    #   false,
    #   Cql::Query.new(Actor.schema).from(Actor.table)
    # )
    # ```
    def initialize(
      @key : Symbol,                                                         # movie_id
      @id : Pk,                                                              # moive id value
      @cascade : Bool = false,                                               # delete associated records
      @query : Cql::Query = Cql::Query.new(Target.schema).from(Target.table) # query object
    )
      @target_table = Target.table
      @records = reload
    end

    # Create a new record and associate it with the parent record
    # - **return** : Array(Target)
    #
    # **Example**
    #
    # ```
    # movie.actors.all
    # movie.actors.create(name: "Carrie-Anne Moss")
    # movie.actors.reload
    #
    # => [#<Actor:0x00007f8b3b1b3f00 @id=1, @name="Carrie-Anne Moss">]
    # ```
    def all : Array(Target)
      @records
    end

    # Reload the association records from the database and return them
    # - **return** : Array(Target)
    #
    # **Example**
    #
    # ```
    # movie.actors.reload
    # => [#<Actor:0x00007f8b3b1b3f00 @id=1, @name="Carrie-Anne Moss">]
    # ```
    def reload
      @records = @query.all(Target)
    end

    # Returns a list if primary keys for the associated records
    # - **return** : Array(Pk)
    #
    # **Example**
    #
    # ```
    # movie.actors.ids
    # => [1, 2, 3]
    # ```
    def ids : Array(Pk)
      @records.map(&.id)
    end

    # Create a new record and associate it with the parent record if it doesn't exist
    # - **param** : record (Target)
    # - **return** : Array(Target)
    #
    # **Example**
    #
    # ```
    # movie.actors << Actor.new(name: "Laurence Fishburne")
    # movie.actors.reload
    # movie.actors.all
    # => [#<Actor:0x00007f8b3b1b3f00 @id=1, @name="Laurence Fishburne">]
    # ```
    def <<(record : Target)
      @records << create(record)
      @records
    end

    # Check if the association is empty or not
    # - **return** : Bool
    #
    # **Example**
    # ```
    # movie.actors.empty?
    # => true
    # ```
    def empty?
      @records.empty?
    end

    # Check if the association exists or not based on the attributes provided
    # - **param** : attributes (Hash(Symbol, String | Int64))
    # - **return** : Bool
    #
    # **Example**
    #
    # ```
    # movie.actors.exists?(name: "Keanu Reeves")
    # => true
    # ```
    def exists?(**attributes)
      @query.where(**attributes).limit(1).exists?
    end

    # Returns the number of associated records for the parent record
    # - **return** : Int64
    #
    # **Example**
    #
    # ```
    # movie.actors.size
    # => 1
    # ```
    def size
      @records.size
    end

    # Find associated records based on the attributes provided for the parent record
    # - **param** : attributes (Hash(Symbol, String | Int64))
    # - **return** : Array(Target)
    #
    # **Example**
    #
    # ```
    # movie.actors.find(name: "Keanu Reeves")
    # => [#<Actor:0x00007f8b3b1b3f00 @id=1, @name="Keanu Reeves">]
    # ```
    def find(**attributes)
      @query.where(**attributes).all(T)
    end

    # Create a new record and associate it with the parent record
    # - **param** : attributes (Hash(Symbol, String | Int64))
    # - **return** : Array(Target)
    # - **raise** : Cql::Error
    #
    # **Example**
    #
    # ```
    # movie.actors.create(name: "Carrie-Anne Moss")
    # movie.actors.reload
    # movie.actors.all
    # => [#<Actor:0x00007f8b3b1b3f00 @id=1, @name="Carrie-Anne Moss">]
    # ```
    def create(**attributes)
      target_id = record.persisted? ? record.id : Target.create(record)
      Target.find!(target_id)
    end

    # Create a new record and associate it with the parent record
    # - **param** : attributes (Hash(Symbol, String | Int64))
    # - **return** : Array(Target)
    # - **raise** : Cql::Error
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
      target_id = record.persisted? ? record.id : Target.create(record)
      Target.find!(target_id)
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
      clear
      Target.insert
        .into(@target_table)
        .values(ids.map { |id| {@key => @id} }).commit.rows_affected

      @records = reload
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
    def delete(record : T)
      Target.delete(record.id).commit.rows_affected
    end

    # Clears all associated records from the parent record and the database
    # - **return** : [] of T
    #
    # **Example**
    # ```
    # movie.actors.create(name: "Carrie-Anne Moss")
    # movie.actors.reload
    # movie.actors.all => 1
    # movie.actors.clear
    # movie.actors.reload
    # movie.actors.all => []
    # ```
    def clear
      Target.delete.where({id: @records.map(&.id)}).rows_affected
      @records = [] of Target
    end
  end

  # A collection of records for a many to many relationship
  # This class is used to manage the relationship between two tables
  # through a join table (through)
  #
  # A many-to-many association occurs when multiple records of one
  # model can be associated with multiple records of another model,
  # and vice versa. Typically, it requires a join table (or a junction table)
  # to store the relationships between the records of the two models.
  #
  # Here’s how a many-to-many association is commonly implemented
  # in CQL using Crystal.
  #
  # **Example**
  #
  # ```
  # class Movie
  #   include Cql::Model(Movie, Int64)
  #
  #   property id : Int64
  #   property title : String
  #
  #   many_to_many :actors, Actor, join_through: :movies_actors
  # end
  #
  # class Actor
  #   include Cql::Model(Actor, Int64)
  #   property id : Int64
  #   property name : String
  # end
  #
  # class MoviesActors
  #   include Cql::Model(MoviesActors, Int64)
  #   property id : Int64
  #   property movie_id : Int64
  #   property actor_id : Int64
  # end
  #
  # movie = Movie.create(title: "The Matrix")
  # actor = Actor.create(name: "Keanu Reeves")
  # ```
  class ManyCollection(Target, Through, Pk) < Collection(Target, Pk)
    @records : Array(Target) = [] of Target
    @target_table : Symbol
    @through_table : Symbol

    # Initialize the many-to-many association collection class
    # - **param** : key (Symbol) - The key for the parent record
    # - **param** : id (Pk) - The id value for the parent record
    # - **param** : target_key (Symbol) - The key for the associated record
    # - **param** : cascade (Bool) - Delete associated records
    # - **param** : query (Cql::Query) - Query object
    # - **return** : ManyCollection
    #
    # **Example**
    #
    # ```
    # ManyCollection.new(
    #   :movie_id,
    #   1,
    #   :actor_id,
    #   false,
    #   Cql::Query.new(Actor.schema).from(Actor.table)
    # )
    # ```
    def initialize(
      @key : Symbol,                                                         # movie_id
      @id : Pk,                                                              # moive id value
      @target_key : Symbol,                                                  # actor_id
      @cascade : Bool = false,                                               # delete associated records
      @query : Cql::Query = Cql::Query.new(Target.schema).from(Target.table) # query object
    )
      super(@key, @id, @cascade, @query)
      @through_table = Through.table
      @records = reload
    end

    # Create a new record and associate it with the parent record
    # - **param** : attributes (Hash(Symbol, String | Int64))
    # - **return** : Array(Target)
    # - **raise** : Cql::Error
    #
    # **Example**
    #
    # ```
    # movie.actors.create(name: "Carrie-Anne Moss")
    # movie.actors.reload
    # movie.actors.all
    # => [#<Actor:0x00007f8b3b1b3f00 @id=1, @name="Carrie-Anne Moss">]
    # ```
    def create(**attributes)
      target_id = record.persisted? ? record.id : Target.create(record)
      Through.create({@key => @id, @target_key => target_id})
      Target.find!(target_id)
    end

    # Create a new record and associate it with the parent record
    # - **param** : attributes (Hash(Symbol, String | Int64))
    # - **return** : Array(Target)
    # - **raise** : Cql::Error
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
      target_id = record.persisted? ? record.id : Target.create(record)
      Through.create({@key => @id, @target_key => target_id})
      Target.find!(target_id)
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
    def ids=(ids : Array(Int64))
      Through.delete.where({@key => @id}).commit.rows_affected
      Through.insert.into(Trough.table).values(
        ids.map { |id| {@key => @id, @target_key => id} }
      ).commit
      @records = reload
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
    def delete(record : T)
      total_records_deleted = Through.delete.where(
        {@key => @id, @target_key => record.id}
      ).commit.rows_affected
      if @cascade
        total_records_deleted += Target
          .delete(record.id)
          .commit
          .rows_affected > 0
      end
      total_records_deleted
    end

    # Clears all associated records from the parent record and the database
    # - **return** : [] of T
    #
    # **Example**
    # ```
    # movie.actors.create(name: "Carrie-Anne Moss")
    # movie.actors.reload
    # movie.actors.all => 1
    # movie.actors.clear
    # movie.actors.reload
    # movie.actors.all => []
    # ```
    def clear
      total_records_deleted = Through.delete.where({@key => @id}).rows_affected
      if @cascade
        total_records_deleted += Target
          .delete
          .where({id: @records.map(&.id)})
          .rows_affected
      end
      total_records_deleted
    end
  end
end
