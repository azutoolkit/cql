require "./base_relation"
require "./collection"

module CQL::ActiveRecord::Relations
  # Enhanced has_many association module with improved type safety,
  # error handling, and performance optimizations.
  #
  # Provides methods to define and manage one-to-many relationships
  # where the foreign key is stored in the associated model.
  # Supports cascading deletes, lazy loading, and proper dependency management.
  module HasMany
    include BaseRelation

    # Define the has_many association with enhanced features
    # - **param** : name (Symbol) - The name of the association
    # - **param** : type (Class) - The target model class
    # - **param** : foreign_key (Symbol) - The foreign key column in the target table (optional)
    # - **param** : dependent (Symbol) - Dependency handling (:destroy, :delete_all, :nullify, :restrict_with_error)
    # - **param** : inverse_of (Symbol) - The inverse association name (optional)
    # - **param** : scope (Proc) - Additional scope for the association (optional)
    #
    # **Example**
    # ```
    # class User
    #   include CQL::Model(Int64)
    #   property id : Int64
    #   property name : String
    #   has_many :posts, Post, foreign_key: :user_id, dependent: :destroy
    # end
    # ```
    macro has_many(name, type, foreign_key = nil, dependent = :nullify, inverse_of = nil, scope = nil)
      {% valid_dependents = %w(destroy delete_all nullify restrict_with_error) %}
      {% unless name.is_a?(SymbolLiteral) %}
        {{ raise "CQL has_many error in #{@type}: association name must be a symbol literal, for example `has_many :posts, Post`." }}
      {% end %}
      {% unless foreign_key == nil || foreign_key.is_a?(SymbolLiteral) %}
        {{ raise "CQL has_many error in #{@type}: foreign_key must be a symbol literal, for example `has_many :posts, Post, foreign_key: :user_id`." }}
      {% end %}
      {% unless dependent.is_a?(SymbolLiteral) && valid_dependents.includes?(dependent.id.stringify) %}
        {{ raise "CQL has_many error in #{@type}: unsupported dependent option `#{dependent}`. Supported options: #{valid_dependents.join(", ")}." }}
      {% end %}

      # Determine foreign key name if not provided
      {% fk = foreign_key || "#{@type.name.underscore.id}_id".id %}

      module ::CQL::ActiveRecord::AssociationRegistry::{{@type.name.gsub(/::/, "__").id}}__has_many__{{name.id}}
        KIND = :has_many
        OWNER = {{@type}}
        TARGET = {{type}}
        ASSOCIATION = {{name}}
        FOREIGN_KEY = {{fk}}
      end

      {% if target_model = type.resolve? %}
        {% parent_id_getter = @type.methods.find { |method| method.name == "id!" && method.args.empty? } %}
        {% target_fk_getter = target_model.methods.find { |method| method.name == fk.id.stringify && method.args.empty? } %}
        {% unless target_fk_getter %}
          {{ raise "CQL has_many error in #{@type}: target model #{type} does not define foreign key `#{fk}`. Add a typed getter/property to #{type}, for example `property #{fk} : #{parent_id_getter ? parent_id_getter.return_type : "ParentPk"}?`." }}
        {% end %}
        {% if parent_id_getter %}
          {% fk_type = target_fk_getter.return_type.stringify.split("|").map(&.strip).reject { |part| part == "Nil" || part == "::Nil" }.join(" | ") %}
          {% pk_type = (@type.constant(:CQL_PRIMARY_KEY_TYPE) || parent_id_getter.return_type).stringify.split("|").map(&.strip).reject { |part| part == "Nil" || part == "::Nil" }.join(" | ") %}
          {% unless fk_type == pk_type %}
            {{ raise "CQL has_many error in #{@type}: target foreign key #{type}##{fk.id} type " + fk_type + " does not match #{@type}.id! primary key type " + pk_type + ". Change `#{fk}` to " + pk_type + " or update the parent model primary key type." }}
          {% end %}
        {% end %}
      {% end %}

      # Define an instance variable to memoize the collection
      @[DB::Field(ignore: true)]
      @{{name.id}} : CQL::ActiveRecord::Relations::Collection({{type.id}}, Pk)?

      # Enhanced getter that memoizes the collection with proper error handling
      @[DB::Field(ignore: true)]
      def {{name.id}} : CQL::ActiveRecord::Relations::Collection({{type.id}}, Pk)
        return @{{name.id}}.not_nil! if @{{name.id}}

        parent_id = safe_id(self, Pk)

                 # Build base query
         base_query = safe_db_operation do
           build_query({{type.id}}).where({ {{fk}} => parent_id })
         end

        # Apply additional scope if provided
        {% if scope %}
          scoped_query = base_query.instance_eval({{scope}})
        {% else %}
          scoped_query = base_query
        {% end %}

        @{{name.id}} = CQL::ActiveRecord::Relations::Collection({{type.id}}, Pk).new(
          key: {{fk}},
          id: parent_id,
          cascade: ({{dependent}} == :destroy || {{dependent}} == :delete_all),
          query: scoped_query,
          dependent: {{dependent}},
          auto_load: false
        )
      end

      # Method to reload the association and clear the memoized value
      def reload_{{name.id}} : CQL::ActiveRecord::Relations::Collection({{type.id}}, Pk)
        @{{name.id}} = nil
        {{name.id}}
      end

      # Check if the association is loaded
      def {{name.id}}_loaded? : Bool
        !@{{name.id}}.nil? && @{{name.id}}.not_nil!.loaded?
      end

      # Clear the memoized association (useful for testing)
      def clear_{{name.id}}_cache
        @{{name.id}} = nil
      end

      # Inject preloaded records into the association without database query.
      # Used by eager loading/preload to avoid N+1 queries.
      # - **param** : records (Array({{type.id}})) - The preloaded records for this association
      # - **return** : Nil
      def _set_preloaded_{{name.id}}(records : Array({{type.id}})) : Nil
        parent_id = safe_id(self, Pk)

        @{{name.id}} = CQL::ActiveRecord::Relations::Collection({{type.id}}, Pk).new(
          key: {{fk}},
          id: parent_id,
          cascade: ({{dependent}} == :destroy || {{dependent}} == :delete_all),
          dependent: {{dependent}},
          auto_load: false
        )
        @{{name.id}}.not_nil!._inject_preloaded(records)
      end

      # Class method to preload this association for a collection of parent records.
      # Executes a single query to fetch all related records and distributes them.
      # - **param** : records (Array(self)) - The parent records
      # - **param** : parent_ids (Array) - The parent IDs
      # - **return** : Nil
      def self._preload_{{name.id}}(records : Array(self), parent_ids : Array) : Nil
        return if records.empty? || parent_ids.empty?

        # Fetch all related records in one query
        related_records = {{type.id}}.where({ {{fk}} => parent_ids }).all

        # Group related records by foreign key
        grouped = {} of Pk => Array({{type.id}})
        related_records.each do |record|
          fk_value = record.{{fk.id}}
          next if fk_value.nil?
          key = fk_value.as(Pk)
          grouped[key] ||= [] of {{type.id}}
          grouped[key] << record
        end

        # Inject preloaded records into each parent
        records.each do |parent|
          parent_id = parent.id
          next if parent_id.nil?
          related = grouped[parent_id.as(Pk)]? || [] of {{type.id}}
          parent._set_preloaded_{{name.id}}(related)
        end
      end

      # Handle dependent associations when parent is destroyed
      def handle_{{name.id}}_dependency
        return unless @{{name.id}} # Only process if association was accessed

        collection = {{name.id}}

        case {{dependent}}
        when :destroy
          # Call destroy on each record (triggers callbacks)
          collection.each do |record|
            safe_db_operation { record.delete! }
          end
        when :delete_all
          # Delete all records without callbacks (more efficient)
          safe_db_operation { collection.delete_all }
        when :nullify
          # Set foreign key to nil
          safe_db_operation { collection.nullify_all }
        when :restrict_with_error
          # Prevent deletion if associated records exist
          unless collection.empty?
            raise RelationError.new("Cannot delete record because dependent {{name.id}} exist")
          end
        end
      end

      # Count associated records without loading them
      def {{name.id}}_count : Int64
        return @{{name.id}}.not_nil!.size.to_i64 if @{{name.id}} && @{{name.id}}.not_nil!.loaded?

        parent_id = safe_id(self, Pk)

        safe_db_operation do
          build_query({{type.id}}).where({ {{fk}} => parent_id }).count
        end
      end

      # Check if any associated records exist without loading them
      def {{name.id}}_any? : Bool
        return !@{{name.id}}.not_nil!.empty? if @{{name.id}} && @{{name.id}}.not_nil!.loaded?

        parent_id = safe_id(self, Pk)

        safe_db_operation do
          count_result = build_query({{type.id}}).where({ {{fk}} => parent_id }).count.get(Int64?)
          (count_result || 0_i64) > 0_i64
        end
      end

      # Create associated records in batch
      def create_{{name.id}}(records : Array({{type.id}})) : Array({{type.id}})
        parent_id = safe_id(self, Pk)

        safe_db_operation do
          created_records = [] of {{type.id}}

          records.each do |record|
             record.attributes({ {{fk}} => parent_id })
             record.create!
             created_records << record
           end

          # Clear cache to ensure fresh data on next access
          @{{name.id}} = nil

          created_records
        end
      end

      # Find associated records with given attributes
      def find_{{name.id}}(**attributes) : Array({{type.id}})
        {{name.id}}.find(**attributes)
      end

      # Find first associated record with given attributes
      def find_{{name.id}}_by(**attributes) : {{type.id}}?
        {{name.id}}.find_by(**attributes)
      end
    end

    # Class method to handle all association dependencies during destruction
    # This will be called from the model's destroy method
    def handle_association_dependencies
      # This method will be extended by models with associations
      # Each has_many association will add its own dependency handler
    end
  end
end
