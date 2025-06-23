require "./base_relation"
require "./many_collection"

module CQL::ActiveRecord::Relations
  # Enhanced many-to-many association module with improved type safety,
  # error handling, and performance optimizations.
  #
  # Provides methods to define and manage many-to-many relationships
  # through a join table with proper caching, lazy loading, and
  # comprehensive error handling.
  module ManyToMany
    include BaseRelation

    # Defines a many-to-many relationship between two models with enhanced features.
    # This method will define a getter method that returns a ManyCollection.
    # The collection can be used to add and remove records from the join table.
    #
    # - **param** : name (Symbol) - The name of the association
    # - **param** : type (Class) - The target model class
    # - **param** : join_through (Symbol | Class) - The join table model or table name
    # - **param** : foreign_key (Symbol) - Foreign key for this model in join table (optional)
    # - **param** : association_foreign_key (Symbol) - Foreign key for target model in join table (optional)
    # - **param** : dependent (Symbol) - Dependency handling (:destroy, :delete_all, :nullify)
    # - **param** : validate (Bool) - Whether to validate associated records
    # - **param** : autosave (Bool) - Whether to automatically save associated records
    #
    # **Example**
    # ```
    # class Movie
    #   include CQL::ActiveRecord::Model(Int64)
    #   property id : Int64
    #   property title : String
    #   many_to_many :actors, Actor, join_through: MoviesActors,
    #     foreign_key: :movie_id, association_foreign_key: :actor_id,
    #     dependent: :destroy
    # end
    #
    # class Actor
    #   include CQL::ActiveRecord::Model(Int64)
    #   property id : Int64
    #   property name : String
    #   many_to_many :movies, Movie, join_through: MoviesActors,
    #     foreign_key: :actor_id, association_foreign_key: :movie_id
    # end
    #
    # class MoviesActors
    #   include CQL::ActiveRecord::Model(Int64)
    #   property id : Int64
    #   property movie_id : Int64
    #   property actor_id : Int64
    # end
    # ```
    macro many_to_many(name, klass, join_through, foreign_key = nil, association_foreign_key = nil, dependent = :nullify, validate = true, autosave = false)
      # Determine foreign key names if not provided
      {% fk = foreign_key || "#{@type.name.underscore.id}_id".id %}
      {% target_fk = association_foreign_key || "#{klass.stringify.underscore.id}_id".id %}

      # Determine join table class
      {% join_class = join_through.is_a?(Path) ? join_through : join_through.camelcase.id %}

      # Instance variable for memoizing the collection
      @[DB::Field(ignore: true)]
      @_{{name.id}} : CQL::ActiveRecord::Relations::ManyCollection({{klass.id}}, {{join_class}}, Int32)?

      # Enhanced getter with caching and proper error handling
      @[DB::Field(ignore: true)]
      def {{name.id}} : CQL::ActiveRecord::Relations::ManyCollection({{klass.id}}, {{join_class}}, Int32)
        return @_{{name.id}}.not_nil! if @_{{name.id}}

        parent_id = safe_id(self, Int32)

        # Build a simpler query without complex joins for now
        # The ManyCollection will handle the join logic internally
        base_query = safe_db_operation do
          build_query({{klass.id}})
        end

        @_{{name.id}} = CQL::ActiveRecord::Relations::ManyCollection({{klass.id}}, {{join_class}}, Int32).new(
          key: :{{fk}},
          id: parent_id,
          target_key: :{{target_fk}},
          cascade: ({{dependent}} == :destroy || {{dependent}} == :delete_all),
          query: base_query,
          dependent: {{dependent}},
          validate: {{validate}},
          autosave: {{autosave}}
        )
      end

      # Reload the association and clear the memoized value
      def reload_{{name.id}} : CQL::ActiveRecord::Relations::ManyCollection({{klass.id}}, {{join_class}}, Int32)
        @_{{name.id}} = nil
        {{name.id}}.reload
        {{name.id}}
      end

      # Check if the association is loaded
      def {{name.id}}_loaded? : Bool
        !@_{{name.id}}.nil? && @_{{name.id}}.not_nil!.loaded?
      end

      # Clear the memoized association (useful for testing)
      def clear_{{name.id}}_cache
        @_{{name.id}} = nil
      end

      # Handle dependent associations when parent is destroyed
      def handle_{{name.id}}_dependency
        return unless @_{{name.id}} # Only process if association was accessed

        collection = {{name.id}}

        case {{dependent}}
        when :destroy
          # Destroy join records and optionally target records
          collection.clear_with_destroy
        when :delete_all
          # Delete join records and optionally target records
          collection.clear_with_delete
        when :nullify
          # This doesn't make sense for many-to-many, so we delete join records
          collection.clear_join_records
        end
      end

      # Count associated records without loading them
      def {{name.id}}_count : Int64
        return @_{{name.id}}.not_nil!.size.to_i64 if @_{{name.id}} && @_{{name.id}}.not_nil!.loaded?

        parent_id = safe_id(self, Int32)

        safe_db_operation do
           CQL::Query
             .new({{join_class}}.schema)
             .from({{join_class}}.table)
             .where({ :{{fk}} => parent_id })
             .count
             .get(Int64?) || 0_i64
         end
      end

      # Check if any associated records exist without loading them
      def {{name.id}}_any? : Bool
        return !@_{{name.id}}.not_nil!.empty? if @_{{name.id}} && @_{{name.id}}.not_nil!.loaded?

        parent_id = safe_id(self, Int32)

        safe_db_operation do
          begin
            CQL::Query
              .new({{join_class}}.schema)
              .from({{join_class}}.table)
              .where({ :{{fk}} => parent_id })
              .limit(1)
              .first({{join_class}})
            true
          rescue DB::NoResultsError
            false
          end
        end
      end

      # Check if a specific record is associated
      def {{name.id}}_include?(record : {{klass.id}}) : Bool
        return {{name.id}}.includes?(record) if @_{{name.id}} && @_{{name.id}}.not_nil!.loaded?

        parent_id = safe_id(self, Int32)
        target_id = safe_id(record, Int32)

        safe_db_operation do
          begin
            CQL::Query
              .new({{join_class}}.schema)
              .from({{join_class}}.table)
              .where({ :{{fk}} => parent_id, :{{target_fk}} => target_id })
              .limit(1)
              .first({{join_class}})
            true
          rescue DB::NoResultsError
            false
          end
        end
      end

      # Get IDs of associated records without loading full records
      def {{name.id}}_ids : Array(Int32)
        return {{name.id}}.ids if @_{{name.id}} && @_{{name.id}}.not_nil!.loaded?

        parent_id = safe_id(self, Int32)

                 safe_db_operation do
           records = CQL::Query
             .new({{join_class}}.schema)
             .from({{join_class}}.table)
             .where({ :{{fk}} => parent_id })
             .all({{join_class}})

           records.compact_map do |record|
             if fk_value = record.attributes[:{{target_fk}}]?
               fk_value.as(Int32)
             end
           end.compact
         end
      end

      # Set associated record IDs (replaces current associations)
      def {{name.id}}_ids=(ids : Array(Int32))
        {{name.id}}.ids = ids
      end

      # Add a single record to the association
      {%
        name_str = name.id.stringify
        singular_name = name_str.ends_with?("s") ? name_str[0..-2] : name_str
      %}
      def add_{{singular_name.id}}(record : {{klass.id}}) : Bool
        {{name.id}} << record
        true
      rescue ex : RelationError
        false
      end

      # Remove a single record from the association
      def remove_{{singular_name.id}}(record : {{klass.id}}) : Bool
        result = {{name.id}}.delete(record)
        !result.nil?
      end

      # Find associated records with given attributes
      def find_{{name.id}}(**attributes) : Array({{klass.id}})
        {{name.id}}.find(**attributes)
      end

      # Find first associated record with given attributes
      def find_{{name.id}}_by(**attributes) : {{klass.id}}?
        {{name.id}}.find_by(**attributes)
      end
    end
  end
end
