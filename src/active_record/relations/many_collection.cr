require "./collection"

module CQL
  module ActiveRecord::Relations
    # A collection of records for a many to many relationship
    # This class is used to manage the relationship between two tables
    # through a join table (through)
    #
    # A many-to-many association occurs when multiple records of one
    # model can be associated with multiple records of another model,
    # and vice versa. Typically, it requires a join table (or a junction table)
    # to store the relationships between the records of the two models.
    #
    # Here's how a many-to-many association is commonly implemented
    # in CQL using Crystal.
    #
    # **Example**
    #
    # ```
    # class Movie
    #   include CQL::Model(Movie, Int64)
    #
    #   property id : Int64
    #   property title : String
    #
    #   many_to_many :actors, Actor, join_through: :movies_actors
    # end
    #
    # class Actor
    #   include CQL::Model(Actor, Int64)
    #   property id : Int64
    #   property name : String
    # end
    #
    # class MoviesActors
    #   include CQL::Model(MoviesActors, Int64)
    #   property id : Int64
    #   property movie_id : Int64
    #   property actor_id : Int64
    # end
    #
    # movie = Movie.create(title: "The Matrix")
    # actor = Actor.create(name: "Keanu Reeves")
    # ```
    class ManyCollection(Target, Through, Pk) < Collection(Target, Pk)
      @through_table : Symbol
      @loaded : Bool = false # Added for lazy loading

      # Initialize the many-to-many association collection class
      # - **param** : key (Symbol) - The key for the parent record
      # - **param** : id (Pk) - The id value for the parent record
      # - **param** : target_key (Symbol) - The key for the associated record
      # - **param** : cascade (Bool) - Delete associated records
      # - **param** : query (CQL::Query) - Query object
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
      #   CQL::Query.new(Actor.schema).from(Actor.table)
      # )
      # ```
      def initialize(
        @key : Symbol,                                                          # movie_id
        @id : Pk,                                                               # moive id value
        @target_key : Symbol,                                                   # actor_id
        @cascade : Bool = false,                                                # delete associated records
        @query : CQL::Query = CQL::Query.new(Target.schema).from(Target.table), # query object
      )
        # Pass auto_load: false to prevent loading in base initializer
        super(@key, @id, @cascade, @query, auto_load: false)
        @through_table = Through.table
        @records = [] of Target # Initialize records array
        # Removed initial reload call
      end

      # Loads records if they haven't been loaded yet
      # - **return** : Nil
      private def load_records
        reload unless @loaded
      end

      # Override each to use lazy loading
      def each(&block : Target ->)
        load_records
        @records.each(&block)
      end

      # Override all to use lazy loading
      def all : Array(Target)
        load_records
        @records
      end

      # Reload the association records from the database and return them
      # This now performs the correct JOIN query.
      # - **return** : Array(Target)
      #
      # **Example**
      #
      # ```
      # movie.actors.reload
      # => [#<Actor:0x00007f8b3b1b3f00 @id=1, @name="Carrie-Anne Moss">]
      # ```
      def reload
        @records = @query.all(Target) # Execute and map to Target instances
        @loaded = true
        @records
      end

      # Adds an existing record to the association.
      # Saves the association to the join table.
      # Raises an error if the target record is not persisted.
      # - **param** : record (Target)
      # - **return** : self
      #
      # **Example**
      # ```
      # movie = Movie.find(1)
      # actor = Actor.create(name: "Laurence Fishburne")
      # movie.actors << actor
      # movie.actors.reload.size # => 3 (assuming 2 existed before)
      # ```
      def <<(record : Target)
        raise ArgumentError.new("Cannot associate an unsaved record") unless record.persisted?
        target_id = record.id!

        # Use find_or_create_by for the join table to avoid duplicates
        # Assuming Through model has appropriate find_or_create_by
        Through.find_or_create_by({@key => @id, @target_key => target_id})

        # Add to internal array only if already loaded and not already present
        @records << record if @loaded && !@records.any? { |_record| _record.id == target_id } # Use any? with block

        self # Return self to allow chaining
      end

      # Create a new target record with given attributes, creates the association
      # in the join table, and adds the record to the collection if loaded.
      # Wraps the creation process in a transaction.
      # - **param** : attributes (Hash(Symbol, String | Int64) | NamedTuple)
      # - **return** : Target
      # - **raise** : CQL::Error on creation failure
      #
      # **Example**
      #
      # ```
      # movie.actors.create(name: "Carrie-Anne Moss")
      # => #<Actor:0x... @id=..., @name="Carrie-Anne Moss">
      # movie.actors.all # includes the new actor if loaded
      # ```
      def create(**attributes)
        # Note: build might not set association keys automatically depending on Model impl.
        record = Target.build(**attributes)
        create(record) # Delegate to the other create method
      end

      # Associates an existing or new target record with the parent record.
      # Creates the association in the join table. If the target record is new,
      # it's created first. Wraps the process in a transaction.
      # Adds the record to the collection if loaded.
      # - **param** : record (Target) - The record to associate (can be new or persisted)
      # - **return** : Target - The associated (and possibly created) record
      # - **raise** : CQL::Error on creation failure
      #
      # **Example**
      #
      # ```
      # actor = Actor.new(name: "Hugo Weaving")
      # movie.actors.create(actor)
      # => #<Actor:0x... @id=..., @name="Hugo Weaving">
      # movie.actors.all # includes the new actor if loaded
      # ```
      def create(record : Target)
        # Save the target record if it's not persisted
        unless record.persisted?
          record.attributes({@key => @id})
          record.create!
        end

        target_id = record.id!

        # Create the association in the join table, avoid duplicates
        Through.find_or_create_by({@key => @id, @target_key => target_id})

        # Add to internal array only if already loaded and not already present
        if @loaded && !@records.any? { |_record| _record.id == target_id }
          @records << record
        end
        record # Return the created/associated record
      end

      # Deletes the association for the given record.
      # If cascade is true, also deletes the target record itself.
      # Removes the record from the collection if loaded.
      # - **param** : record (Target)
      # - **return** : Target? - The deleted target record (if found and cascade=true), or nil
      #
      # **Example**
      #
      # ```
      # actor = movie.actors.find_by(name: \"Carrie-Anne Moss\")
      # movie.actors.delete(actor)
      # movie.actors.all # \"Carrie-Anne Moss\" is gone
      # Actor.find_by(name: \"Carrie-Anne Moss\") # => nil if cascade was true
      # ```
      def delete(record : Target) : Target?
        delete(record.id!) # Delegate to delete by ID
      end

      # Deletes the association for the record with the given ID.
      # If cascade is true, also deletes the target record itself.
      # Removes the record from the collection if loaded.
      # Wraps target deletion in a transaction if cascade is true.
      # - **param** : id (Pk)
      # - **return** : Target? - The target record if cascade was true and deletion occurred, otherwise nil.
      #
      # **Example**
      #
      # ```
      # movie.actors.delete(1) # Assuming actor with ID 1 exists
      # movie.actors.reload    # Actor 1 is gone
      # Actor.find?(1)         # => nil if cascade was true
      # ```
      def delete(id : Pk) : Target?
        deleted_target_record = nil
        record_to_remove_from_loaded = @records.find { |_record| _record.id == id } if @loaded

        # Delete the association record from the join table
        rows_affected = CQL::Delete
          .new(Through.schema)
          .from(@through_table)
          .where({@key => @id, @target_key => id})
          .commit
          .rows_affected

        # If association existed and cascade is enabled, delete the target record
        if rows_affected > 0 && @cascade
          # Fetch the record before deleting if cascading, to return it
          deleted_target_record = Target.find?(id)
          if deleted_target_record
            # Use transaction for atomicity if needed (though Target.delete might be atomic)
            # Target.schema.transaction do
            Target.delete!(id) # Use delete, handles if record doesn't exist
            # end
          end
        end

        # Remove from internal array if it was loaded and the association was actually deleted
        if @loaded && record_to_remove_from_loaded && rows_affected > 0
          @records.delete(record_to_remove_from_loaded)
        end

        # Return the target record only if it was deleted due to cascade=true
        deleted_target_record
      end

      # Clears all associated records from the parent record.
      # Removes associations from the join table.
      # If cascade is true, also deletes the target records themselves.
      # Clears the internal collection. Wraps the operation in a transaction.
      # - **return** : self
      #
      # **Example**
      # ```
      # movie.actors.create(name: \"Carrie-Anne Moss\")
      # movie.actors.clear
      # movie.actors.size # => 0
      # Actor.exists?(name: \"Carrie-Anne Moss\") # => false if cascade was true
      # ```
      def clear
        target_ids_to_delete = [] of Pk

        if @cascade
          # Get target IDs associated through the join table before deleting associations
          # Assumes Through model has standard query capabilities
          target_ids_to_delete = CQL::Query
            .new(Through.schema)
            .from(Through.table)
            .where({@key => @id})
            .all(Through)
            .map(&.id!)
        end

        # Delete all associations from the join table
        CQL::Delete
          .new(Through.schema)
          .from(Through.table)
          .where({@key => @id})
          .commit

        # If cascading, delete the target records
        if @cascade && !target_ids_to_delete.empty?
          # Assumes Target.delete accepts an array of IDs
          target_ids_to_delete.each do |id|
            Target.delete!(id)
          end
        end

        # Clear internal state
        @records.clear
        @loaded = true # Collection is now loaded and known to be empty

        self # Return self
      end

      # Build a new target record associated with this parent, but don\'t save it.
      # The association is only truly formed when saved via `create` or `<<`.
      # - **param** : attributes (Hash | NamedTuple) - Attributes for the new target record.
      # - **return** : Target - The newly built target record.
      #
      # **Example**
      #
      # ```
      # new_actor = movie.actors.build(name: \"Agent Smith\")
      # new_actor.persisted? # => false
      # new_actor.save # Creates Actor and the MoviesActors record via appropriate callbacks/methods if defined
      # ```
      def build(**attributes) : Target
        Target.new(**attributes)
        # Note: The built record isn\'t added to @records until saved & collection reloaded/accessed.
      end

      # --- Query Methods Overrides ---

      # Find associated records matching the given attributes.
      # Queries the database directly using a JOIN.
      # - **param** : attributes (NamedTuple | Hash(Symbol, DB::Any))
      # - **return** : Array(Target)
      #
      # **Example**
      # ```
      # movie.actors.find(name: \"Keanu Reeves\")
      # => [#<Actor...>]
      # ```
      def find(**attributes) : Array(Target)
        @query.where(**attributes).all(Target)
      end

      # Find the first associated record matching the given attributes.
      # Queries the database directly using a JOIN.
      # - **param** : attributes (NamedTuple | Hash(Symbol, DB::Any))
      # - **return** : Target?
      #
      # **Example**
      # ```
      # movie.actors.find_by(name: \"Keanu Reeves\")
      # => #<Actor...>
      # ```
      def find_by(**attributes) : Target?
        @query.where(**attributes).first(Target)
      end

      # Returns a query scope for associated records, filtered by attributes.
      # Allows chaining further query methods (e.g., .limit, .order).
      # Queries the database directly using a JOIN.
      # - **param** : attributes (NamedTuple | Hash(Symbol, DB::Any))
      # - **return** : CQL::Query
      #
      # **Example**
      # ```
      # movie.actors.where(name: \"Keanu Reeves\").limit(1).first
      # ```
      def where(**attributes) : CQL::Query
        @query.where(**attributes)
      end

      # Checks if any associated records exist matching the given attributes.
      # Queries the database directly using a JOIN.
      # - **param** : attributes (NamedTuple | Hash(Symbol, DB::Any))
      # - **return** : Bool
      #
      # **Example**
      # ```
      # movie.actors.exists?(name: \"Keanu Reeves\") # => true
      # ```
      def exists?(**attributes) : Bool
        # Use first? for efficiency, only needs to know if at least one exists
        @query.where(**attributes).limit(1).first?(Target)
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
        @query.where(**attributes).all(Target)
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
        @query.where(**attributes)
          .limit(1).first(Target) != nil
      rescue DB::NoResultsError | CQL::Schema::ConnectionError
        false
      end

      def ids=(ids : Array(Pk))
        Insert
          .new(Through.schema)
          .into(Through.table)
          .values(ids.map { |id| {@key => @id, @target_key => id} })
          .commit
          .rows_affected
      end
    end
  end
end
