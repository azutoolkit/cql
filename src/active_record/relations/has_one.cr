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
    # - **param** : dependent (Symbol) - What to do with the associated record (:destroy, :delete, :nullify): when it is
    #   replaced or deleted through the association (default :destroy), and, only when declared, when the parent is deleted
    # - **param** : cache (Bool) - Whether to cache the associated record
    #
    # **Example**
    # ```
    # class User
    #   include CQL::Model(Int64)
    #   has_one :profile, Profile, foreign_key: :user_id, dependent: :destroy
    # end
    # ```
    macro has_one(name, kind, foreign_key = nil, dependent = nil, cache = true)
      {% valid_dependents = %w[destroy delete nullify] %}
      {% unless dependent == nil || (dependent.is_a?(SymbolLiteral) && valid_dependents.includes?(dependent.id.stringify)) %}
        {{ raise "CQL has_one error in #{@type}: unsupported dependent option `#{dependent}`. Supported options: #{valid_dependents.join(", ")}." }}
      {% end %}
      {% strategy = dependent || :destroy %}

      {% if dependent %}
        apply_on_delete {{name}}
      {% end %}

      # Determine foreign key name if not provided (a symbol literal or the default, as an identifier)
      {% fk = (foreign_key || "#{@type.name.split("::").last.underscore.id}_id").id %}

      module ::CQL::ActiveRecord::AssociationRegistry::{{@type.name.gsub(/::/, "__").id}}__has_one__{{name.id}}
        KIND = :has_one
        OWNER = {{@type}}
        TARGET = {{kind}}
        ASSOCIATION = {{name}}
        FOREIGN_KEY = :{{fk}}
      end

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
        return nil if id.nil?

        parent_id = safe_id(self, Pk)

        result = safe_db_operation do
          {{kind.id}}.find_by({{fk}}: CQL::ActiveRecord::IdChunks.bound(parent_id))
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
          parent_id = safe_id(self, Pk)

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

      {% if cache %}
        # Loads this association for *records* with one query per *chunk_size* parent ids (the
        # dialect's bind-parameter limit by default). Like the lazy reader, a parent with several
        # children gets an arbitrary one. Keys are compared as strings, so the child's foreign key
        # type need not match the parent's primary key type.
        def self._preload_{{name.id}}(records : Array(self), chunk_size : Int32 = {{kind.id}}.adapter.dialect.max_bind_params - 1) : Nil
          \{% if {{kind.id}}.has_method?({{fk.stringify}}) %}
            found = {} of String => {{kind.id}}
            CQL::ActiveRecord::IdChunks.each(records.compact_map(&.id), chunk_size) do |ids|
              {{kind.id}}.where({:{{fk}} => ids}).all.each do |child|
                child.{{fk}}.try { |key| found[key.to_s] ||= child }
              end
            end
            records.each do |record|
              id = record.id
              record._set_preloaded_{{name.id}}(found[id.to_s]?) unless id.nil?
            end
          \{% else %}
            raise ArgumentError.new("Cannot preload {{name.id}}: {{kind.id}} has no {{fk}} attribute")
          \{% end %}
        end

        def _set_preloaded_{{name.id}}(record : {{kind.id}}?) : Nil
          @_cached_{{name.id}} = record
          @_{{name.id}}_loaded = true
        end
      {% end %}

      # Build a new associated record without saving
      def build_{{name.id}}(**attributes) : {{kind.id}}
        parent_id = safe_id(self, Pk)

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
          case {{strategy}}
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

        result = case {{strategy}}
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
          raise ArgumentError.new("Invalid dependent option: {{strategy}}")
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

      # Applies the `dependent:` strategy to the associated record in the database, ignoring the
      # cache; `delete!` calls it when `dependent:` is declared
      def handle_{{name.id}}_dependency : Nil
        {% if cache %}
          @_{{name.id}}_loaded = false
        {% end %}
        current_record = {{name.id}}
        return unless current_record

        {% if strategy == :destroy %}
          destroy_dependent(current_record, {{name}})
        {% elsif strategy == :delete %}
          safe_db_operation { {{kind.id}}.delete!(current_record.id!) }
        {% else %}
          safe_db_operation do
            current_record.{{fk}} = nil
            current_record.save!
          end
        {% end %}
      end
    end
  end
end
