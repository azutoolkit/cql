require "./base_relation"
require "./collection"

module CQL
  module ActiveRecord::Relations
    # Enhanced collection class for many-to-many relationships with improved
    # type safety, error handling, and performance optimizations.
    #
    # A many-to-many association occurs when multiple records of one
    # model can be associated with multiple records of another model,
    # and vice versa. This requires a join table (or junction table)
    # to store the relationships between the records of the two models.
    #
    # **Example**
    # ```
    # class Movie
    #   include CQL::Model(Int64)
    #   property id : Int64
    #   property title : String
    #   many_to_many :actors, Actor, join_through: MoviesActors
    # end
    #
    # class Actor
    #   include CQL::Model(Int64)
    #   property id : Int64
    #   property name : String
    # end
    #
    # class MoviesActors
    #   include CQL::Model(Int64)
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
      @dependent : Symbol = :nullify
      @validate : Bool = true
      @autosave : Bool = false

      # Initialize the many-to-many association collection class
      # - **param** : key (Symbol) - The key for the parent record
      # - **param** : id (Pk) - The id value for the parent record
      # - **param** : target_key (Symbol) - The key for the associated record
      # - **param** : cascade (Bool) - Delete associated records (deprecated, use dependent)
      # - **param** : query (CQL::Query) - Query object
      # - **param** : dependent (Symbol) - Dependency handling strategy
      # - **param** : validate (Bool) - Whether to validate records
      # - **param** : autosave (Bool) - Whether to automatically save records
      # - **return** : ManyCollection
      def initialize(
        @key : Symbol,                             # movie_id
        @id : Pk,                                  # movie id value
        @target_key : Symbol,                      # actor_id
        @cascade : Bool = false,                   # delete associated records (deprecated)
        @query : CQL::Query = build_query(Target), # query object
        @dependent : Symbol = :nullify,            # dependency strategy
        @validate : Bool = true,                   # validate records
        @autosave : Bool = false,                  # autosave records
      )
        # Handle legacy cascade parameter with deprecation warning
        if @cascade
          Relations::Log.warn { "DEPRECATION WARNING: The 'cascade' parameter is deprecated and will be removed in v1.0.0. Use 'dependent: :destroy' instead." }
          @dependent = :destroy if @dependent == :nullify
        end

        # Initialize parent with auto_load: false to prevent loading in base initializer
        super(@key, @id, @cascade, @query, auto_load: false, dependent: @dependent)
        @through_table = Through.table
        @records = [] of Target
      end

      # Override reload to perform the correct JOIN query for many-to-many
      # - **return** : Array(Target)
      def reload
        @records = safe_db_operation do
          @query.all(Target)
        end
        @loaded = true
        @records
      end

      # Adds an existing record to the association.
      # Creates the association in the join table.
      # Raises an error if the target record is not persisted.
      # - **param** : record (Target)
      # - **return** : self
      def <<(record : Target)
        ensure_persisted(record)
        target_id = safe_id(record, Pk)

        # Create join table record to establish association
        safe_db_operation do
          Through.find_or_create_by({@key => @id, @target_key => target_id})
        end

        # Add to internal array only if already loaded and not already present
        if @loaded && !includes?(record)
          @records << record
        end

        self
      end

      # Create a new target record with given attributes and associate it
      # - **param** : attributes (Hash | NamedTuple)
      # - **return** : Target
      # - **raise** : RelationError on creation failure
      def create(**attributes)
        record = build(**attributes)
        create(record)
      end

      # Associates an existing or new target record with the parent record.
      # Creates the association in the join table. If the target record is new,
      # it's created first.
      # - **param** : record (Target) - The record to associate (can be new or persisted)
      # - **return** : Target - The associated (and possibly created) record
      # - **raise** : RelationError on creation failure
      def create(record : Target)
        # Save the target record if it's not persisted
        unless record.persisted?
          safe_db_operation { record.create! }
        end

        target_id = safe_id(record, Pk)

        # Create the association in the join table
        safe_db_operation do
          Through.find_or_create_by({@key => @id, @target_key => target_id})
        end

        # Add to internal array only if already loaded and not already present
        if @loaded && !includes?(record)
          @records << record
        end

        record
      end

      # Deletes the association for the given record.
      # For many-to-many relationships, this only removes the join table record.
      # - **param** : record (Target)
      # - **return** : Target? - The record if association was removed, nil otherwise
      def delete(record : Target) : Target?
        record_id = safe_id(record, Pk)
        success = delete(record_id)
        success ? record : nil
      end

      # Deletes the association for the record with the given ID.
      # For many-to-many relationships, this removes the join table record
      # and handles the target record based on the dependent strategy.
      # - **param** : id (Pk)
      # - **return** : Target? - The target record if association was removed, nil otherwise
      def delete(id : Pk) : Target?
        record_to_remove = @records.find { |record| record.id == id } if @loaded

        # Delete the association record from the join table
        rows_affected = safe_db_operation do
          CQL::Delete
            .new(Through.schema)
            .from(@through_table)
            .where({@key => @id, @target_key => id})
            .commit
            .rows_affected
        end

        deleted_target_record = nil

        if rows_affected > 0
          # Handle target record based on dependent strategy
          case @dependent
          when :destroy
            # Destroy the target record (with callbacks)
            deleted_target_record = record_to_remove || safe_db_operation { Target.find?(id) }
            if deleted_target_record
              safe_db_operation { deleted_target_record.delete! }
            end
          when :delete_all
            # Delete the target record (without callbacks)
            deleted_target_record = record_to_remove || safe_db_operation { Target.find?(id) }
            if deleted_target_record
              safe_db_operation { Target.delete!(id) }
            end
          else
            # For :nullify or default, just preserve the target record
            deleted_target_record = record_to_remove || safe_db_operation { Target.find?(id) }
          end

          # Remove from internal array if it was loaded
          if @loaded && record_to_remove
            @records.delete(record_to_remove)
          end

          deleted_target_record
        else
          # Return nil to indicate no association was removed
          nil
        end
      end

      # Clears all associated records from the parent record.
      # Removes associations from the join table and handles target records
      # based on the dependent strategy.
      # - **return** : self
      def clear
        case @dependent
        when :destroy
          clear_with_destroy
        when :delete_all
          clear_with_delete
        else
          clear_join_records
        end

        # Clear internal state
        @records.clear if @loaded
        self
      end

      # Clear associations and destroy target records
      def clear_with_destroy
        if @dependent == :destroy
          # Get target records before clearing associations
          target_records = @loaded ? @records.dup : all

          # Clear join table associations
          clear_join_records

          # Destroy the target records as well (cascade)
          target_records.each do |record|
            safe_db_operation { record.delete! }
          end
        else
          clear_join_records
        end

        # Clear internal state since associations are gone
        @records.clear if @loaded
        self
      end

      # Clear associations and delete target records (without callbacks)
      def clear_with_delete
        if @dependent == :delete_all
          # Get target IDs before clearing associations
          target_ids = @loaded ? @records.compact_map(&.id) : ids

          # Clear join table associations
          clear_join_records

          # Delete target records without callbacks
          target_ids.each do |id|
            safe_db_operation { Target.delete!(id) }
          end
        else
          clear_join_records
        end

        # Clear internal state since associations are gone
        @records.clear if @loaded
        self
      end

      # Clear only the join table records (preserve target records)
      def clear_join_records
        safe_db_operation do
          CQL::Delete
            .new(Through.schema)
            .from(@through_table)
            .where({@key => @id})
            .commit
        end

        # Clear internal state since associations are gone
        @records.clear if @loaded
        self
      end

      # Build a new target record but don't save it or create association
      # - **param** : attributes (Hash | NamedTuple)
      # - **return** : Target
      def build(**attributes) : Target
        safe_db_operation do
          Target.new(**attributes)
        end
      end

      # Override exists? to check via join table
      def exists?(**attributes) : Bool
        safe_db_operation do
          # Get IDs from join table
          through_records = CQL::Query
            .new(Through.schema)
            .from(@through_table)
            .where({@key => @id})
            .all(Through)

          target_ids = through_records.compact_map do |record|
            record.attributes[@target_key]?.as(Pk?) if record.attributes[@target_key]?
          end.compact

          return false if target_ids.empty?

          # Check if any target records with the given attributes exist in the associated IDs
          results = Target.where(**attributes)
            .where(id: target_ids)
            .all
          !results.empty?
        end
      end

      # Check if the collection includes a specific record
      def includes?(record : Target) : Bool
        if @loaded
          @records.any? { |local_record| local_record.id == record.id }
        else
          record_id = safe_id(record, Pk)
          safe_db_operation do
            begin
              result = CQL::Query
                .new(Through.schema)
                .from(@through_table)
                .where({@key => @id, @target_key => record_id})
                .limit(1)
                .first(Through)
              !result.nil?
            rescue DB::NoResultsError
              false
            end
          end
        end
      end

      # Set the associated record IDs (replaces current associations)
      def ids=(ids : Array(Pk))
        # Clear existing associations
        clear_join_records

        # Create new associations
        if ids.any?
          safe_db_operation do
            values = ids.map { |id| {@key => @id, @target_key => id} }
            CQL::Insert
              .new(Through.schema)
              .into(@through_table)
              .values(values)
              .commit
          end
        end

        # Reload if already loaded
        reload if @loaded
      end

      # Get associated record IDs
      def ids : Array(Pk)
        if @loaded
          @records.compact_map(&.id).map(&.as(Pk))
        else
          safe_db_operation do
            through_records = CQL::Query
              .new(Through.schema)
              .from(@through_table)
              .where({@key => @id})
              .all(Through)

            through_records.compact_map do |record|
              record.attributes[@target_key]?.as(Pk?) if record.attributes[@target_key]?
            end.compact
          end
        end
      end

      # Add multiple records to the association
      def concat(records : Array(Target)) : Array(Target)
        records.each { |record| self << record }
        @loaded ? @records : all
      end

      # Remove multiple records from the association
      def remove(records : Array(Target)) : Array(Target)
        records.each { |record| delete(record) }
        @loaded ? @records : all
      end

      # Override find to properly handle many-to-many relationships via join table
      # - **param** : attributes (NamedTuple | Hash(Symbol, DB::Any))
      # - **return** : Array(Target)
      def find(**attributes)
        safe_db_operation do
          # Get IDs from join table
          through_records = CQL::Query
            .new(Through.schema)
            .from(@through_table)
            .where({@key => @id})
            .all(Through)

          target_ids = through_records.compact_map do |record|
            record.attributes[@target_key]?.as(Pk?) if record.attributes[@target_key]?
          end.compact

          return [] of Target if target_ids.empty?

          # Query target records with the given attributes and IDs
          Target.where(**attributes)
            .where(id: target_ids)
            .all
        end
      end

      # Override find_by to properly handle many-to-many relationships via join table
      # - **param** : attributes (NamedTuple | Hash(Symbol, DB::Any))
      # - **return** : Target?
      def find_by(**attributes)
        safe_db_operation do
          # Get IDs from join table
          through_records = CQL::Query
            .new(Through.schema)
            .from(@through_table)
            .where({@key => @id})
            .all(Through)

          target_ids = through_records.compact_map do |record|
            record.attributes[@target_key]?.as(Pk?) if record.attributes[@target_key]?
          end.compact

          return nil if target_ids.empty?

          # Query target records with the given attributes and IDs
          begin
            Target.where(**attributes)
              .where(id: target_ids)
              .first
          rescue DB::NoResultsError
            nil
          end
        end
      end
    end
  end
end
