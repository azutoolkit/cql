require "./base_relation"

module CQL::ActiveRecord::Relations
  # Enhanced has_one association module with improved type safety,
  # error handling, and performance optimizations.
  #
  # Provides methods to define and manage one-to-one relationships
  # where the foreign key is stored in the associated model.
  module HasOne
    include BaseRelation

    # Define the has_one association with enhanced features
    # - **param** : name (Symbol) - Association name
    # - **param** : kind (Class) - Associated model class
    # - **param** : foreign_key (Symbol) - Foreign key in the associated model (optional)
    # - **param** : dependent (Symbol) - What to do with associated record when parent is deleted (:destroy, :delete, :nullify)
    # - **param** : cache (Bool) - Whether to cache the associated record
    #
    # **Example**
    # ```
    # class User
    #   include CQL::Model(User, Int64)
    #   has_one :profile, Profile, foreign_key: :user_id, dependent: :destroy
    # end
    # ```
    macro has_one(name, kind, foreign_key = nil, dependent = :destroy, cache = true)
      # Determine foreign key name if not provided
      {% fk = foreign_key || "#{@type.name.underscore.id}_id".id %}

      # Cache variables (if caching enabled)
      {% if cache %}
        @[DB::Field(ignore: true)]
        @_cached_{{name.id}} : {{kind.id}}? = nil
        @[DB::Field(ignore: true)]
        @_{{name.id}}_loaded : Bool = false
      {% end %}

      # Enhanced getter with caching and proper error handling
      def {{name.id}} : {{kind.id}}?
        {% if cache %}
          # Return cached value if already loaded
          return @_cached_{{name.id}} if @_{{name.id}}_loaded
        {% end %}

        # Ensure we have a valid ID
        return nil if @id.nil?

        parent_id = safe_id(self, Pk)

        result = safe_db_operation do
          {{kind.id}}.find_by({{fk}}: parent_id)
        end

        {% if cache %}
          # Cache the result
          @_cached_{{name.id}} = result
          @_{{name.id}}_loaded = true
        {% end %}

        result
      end

      # Enhanced setter with validation and cache invalidation
      def {{name.id}}=(record : {{kind.id}}?)
        if record.nil?
          # Clear existing association
          current = {{name.id}}
          if current
            current.{{fk}} = nil
            safe_db_operation { current.save! }
          end
        else
          # Don't require the record to be persisted when setting association
          # ensure_persisted(record)
          parent_id = safe_id(self, typeof(@id))

          # Clear any existing association first
          existing = {{name.id}}
          if existing && existing.id != record.id
            existing.{{fk}} = nil
            safe_db_operation { existing.save! }
          end

          # Set the new association
          record.{{fk}} = parent_id
          safe_db_operation { record.save! }
        end

        {% if cache %}
          # Update cache
          @_cached_{{name.id}} = record
          @_{{name.id}}_loaded = true
        {% end %}

        record
      end

      # Build a new associated record without saving
      def build_{{name.id}}(**attributes) : {{kind.id}}
        parent_id = safe_id(self, typeof(@id))

        safe_db_operation do
          record = {{kind.id}}.new(**attributes)
          record.{{fk}} = parent_id
          record
        end
      end

      # Create and associate a new record
      def create_{{name.id}}(**attributes) : {{kind.id}}
        # Clear existing association first
        existing = {{name.id}}
        if existing
          case {{dependent}}
          when :destroy
            safe_db_operation { existing.delete! }
          when :delete
            safe_db_operation { {{kind.id}}.delete!(existing.id!) }
          when :nullify
            existing.{{fk}} = nil
            safe_db_operation { existing.save! }
          end
        end

        record = build_{{name.id}}(**attributes)
        safe_db_operation { record.create! }

        {% if cache %}
          @_cached_{{name.id}} = record
          @_{{name.id}}_loaded = true
        {% end %}

        record
      end

      # Update the associated record
      def update_{{name.id}}(**attributes) : {{kind.id}}
        current_record = {{name.id}}
        raise AssociationNotFound.new("No {{name.id}} to update") if current_record.nil?

        safe_db_operation do
          current_record.update!(**attributes)
          current_record
        end
      end

      # Delete the associated record based on dependent strategy
      def delete_{{name.id}} : Bool
        current_record = {{name.id}}
        return false if current_record.nil?

        result = case {{dependent}}
        when :destroy
          safe_db_operation do
            current_record.delete!
            true
          end
        when :delete
          safe_db_operation do
            {{kind.id}}.delete!(current_record.id!).rows_affected > 0
          end
        when :nullify
          safe_db_operation do
            current_record.{{fk}} = nil
            current_record.save!
            true
          end
        else
          raise ArgumentError.new("Invalid dependent option: {{dependent}}")
        end

        {% if cache %}
          if result
            @_cached_{{name.id}} = nil
            @_{{name.id}}_loaded = true
          end
        {% end %}

        result
      end

      # Clear the association without deleting the record (nullify foreign key)
      def clear_{{name.id}} : Bool
        current_record = {{name.id}}
        return false if current_record.nil?

        safe_db_operation do
          current_record.{{fk}} = nil
          current_record.save!
        end

        {% if cache %}
          @_cached_{{name.id}} = nil
          @_{{name.id}}_loaded = true
        {% end %}

        true
      end

      # Reload the association from the database
      {% if cache %}
        def reload_{{name.id}} : {{kind.id}}?
          @_{{name.id}}_loaded = false
          @_cached_{{name.id}} = nil
          {{name.id}}
        end
      {% end %}

      # Check if the association is loaded (for caching)
      {% if cache %}
        def {{name.id}}_loaded? : Bool
          @_{{name.id}}_loaded
        end
      {% end %}

      # Handle dependent associations when parent is destroyed
      def handle_{{name.id}}_dependency
        current_record = {{name.id}}
        return unless current_record

        case {{dependent}}
        when :destroy
          safe_db_operation { current_record.delete! }
        when :delete
          safe_db_operation { {{kind.id}}.delete!(current_record.id!) }
        when :nullify
          safe_db_operation do
            current_record.{{fk}} = nil
            current_record.save!
          end
        end
      end
    end
  end
end
