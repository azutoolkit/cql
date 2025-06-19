require "./base_relation"

module CQL::ActiveRecord::Relations
  # Enhanced belongs_to association module with improved type safety,
  # error handling, and performance optimizations.
  #
  # Provides methods to define and manage many-to-one relationships
  # with proper caching, lazy loading, and comprehensive error handling.
  module BelongsTo
    include BaseRelation

    # Define the belongs_to association with enhanced features
    # - **param** : assoc (Symbol) - Association name
    # - **param** : klass (Class) - Associated model class
    # - **param** : foreign_key (Symbol) - Foreign key column name
    # - **param** : optional (Bool) - Whether association can be nil
    # - **param** : cache (Bool) - Whether to cache the associated record
    #
    # **Example**
    # ```
    # class Post
    #   include CQL::Model(Post, Int64)
    #   belongs_to :user, User, :user_id, optional: false, cache: true
    # end
    # ```
    macro belongs_to(assoc, klass, foreign_key, optional = true, cache = true)
      # Cache variable for the associated record (if caching enabled)
      {% if cache %}
        @[DB::Field(ignore: true)]
        @_cached_{{assoc.id}} : {{klass.id}}? = nil
        @[DB::Field(ignore: true)]
        @_{{assoc.id}}_loaded : Bool = false
      {% end %}

      # Enhanced getter with caching and proper error handling
      def {{assoc.id}} : {% if optional %}{{klass.id}}?{% else %}{{klass.id}}{% end %}
        {% if cache %}
          # Return cached value if already loaded
          {% if optional %}
            return @_cached_{{assoc.id}} if @_{{assoc.id}}_loaded
          {% else %}
            if @_{{assoc.id}}_loaded
              cached_value = @_cached_{{assoc.id}}
              return cached_value.not_nil! if cached_value
            end
          {% end %}
        {% end %}

        # Return nil if foreign key is not set, is 0, or is nil and association is optional
        {% if optional %}
          return nil if @{{foreign_key.id}}.nil? || @{{foreign_key.id}} == 0
        {% else %}
          if @{{foreign_key.id}}.nil? || @{{foreign_key.id}} == 0
            raise InvalidAssociation.new("Required association {{assoc.id}} foreign key is nil or 0")
          end
        {% end %}

        # Safely fetch the associated record
        fk_value = @{{foreign_key.id}}.not_nil!

        result = safe_db_operation do
          {{klass.id}}.find?(fk_value)
        end

        {% if !optional %}
          if result.nil?
            raise DB::NoResultsError.new("{{klass.id}} with id #{fk_value} not found")
          end
        {% end %}

        {% if cache %}
          # Cache the result
          @_cached_{{assoc.id}} = result
          @_{{assoc.id}}_loaded = true
        {% end %}

        result
      end

      # Enhanced setter with validation and cache invalidation
      def {{assoc.id}}=(record : {% if optional %}{{klass.id}}?{% else %}{{klass.id}}{% end %})
        {% if optional %}
          if record.nil?
            @{{foreign_key.id}} = nil
          else
            ensure_persisted(record)
            @{{foreign_key.id}} = safe_id(record, Int32)
          end
        {% else %}
          # For non-optional associations, record cannot be nil
          ensure_persisted(record)
          @{{foreign_key.id}} = safe_id(record, Int32)
        {% end %}

        {% if cache %}
          # Update cache
          @_cached_{{assoc.id}} = record
          @_{{assoc.id}}_loaded = true
        {% end %}

        record
      end

      # Build a new associated record without saving
      def build_{{assoc.id}}(**attributes) : {{klass.id}}
        safe_db_operation do
          {{klass.id}}.new(**attributes)
        end
      end

      # Create and associate a new record
      def create_{{assoc.id}}(**attributes) : {{klass.id}}
        record = build_{{assoc.id}}(**attributes)

        safe_db_operation do
          record.create!
          self.{{assoc.id}} = record
          record
        end
      end

      # Update the associated record
      def update_{{assoc.id}}(**attributes) : {{klass.id}}
        current_record = {{assoc.id}}
        {% if optional %}
          raise AssociationNotFound.new("No {{assoc.id}} to update") if current_record.nil?
        {% end %}

        safe_db_operation do
          current_record{% unless optional %}.not_nil!{% end %}.update!(**attributes)
          current_record{% unless optional %}.not_nil!{% end %}
        end
      end

      # Delete the associated record
      def delete_{{assoc.id}} : Bool
        current_record = {{assoc.id}}
        {% if optional %}
          return false if current_record.nil?
        {% end %}

        result = safe_db_operation do
          record_id = safe_id(current_record{% unless optional %}.not_nil!{% end %}, Int32)
          {{klass.id}}.delete!(record_id).rows_affected > 0
        end

        if result
          {% if optional %}
            @{{foreign_key.id}} = nil
          {% else %}
            # For non-optional associations, we can't set the foreign key to nil
            # So we'll just clear the cache but leave the foreign key as is
          {% end %}
          {% if cache %}
            @_cached_{{assoc.id}} = nil
            @_{{assoc.id}}_loaded = true
          {% end %}
        end

        result
      end

      # Clear the association without deleting the record
      def clear_{{assoc.id}}
        {% if optional %}
          @{{foreign_key.id}} = nil
        {% else %}
          # For non-optional associations, we can't clear the foreign key
          # This method shouldn't be used for non-optional associations
          raise InvalidAssociation.new("Cannot clear non-optional association {{assoc.id}}")
        {% end %}
        {% if cache %}
          @_cached_{{assoc.id}} = nil
          @_{{assoc.id}}_loaded = true
        {% end %}
      end

      # Reload the association from the database
      {% if cache %}
        def reload_{{assoc.id}} : {% if optional %}{{klass.id}}?{% else %}{{klass.id}}{% end %}
          @_{{assoc.id}}_loaded = false
          @_cached_{{assoc.id}} = nil
          {{assoc.id}}
        end
      {% end %}

      # Check if the association is loaded (for caching)
      {% if cache %}
        def {{assoc.id}}_loaded? : Bool
          @_{{assoc.id}}_loaded
        end
      {% end %}
    end
  end
end
