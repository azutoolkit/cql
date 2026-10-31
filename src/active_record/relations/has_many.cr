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
    # - **param** : dependent (Symbol) - What `delete!` does with the associated records (:destroy, :delete_all,
    #   :nullify, :restrict_with_error); without it, deleting the parent leaves them alone and `clear` nullifies
    # - **param** : inverse_of (Symbol) - The inverse association name (optional)
    # - **param** : scope (Proc) - Additional scope for the association (optional)
    #
    # **Example**
    # ```
    # class Article
    #   include CQL::ActiveRecord::Model(Int64)
    #   db_context AcmeDB, :articles
    #
    #   property author_id : Int64?
    # end
    #
    # class Author
    #   include CQL::ActiveRecord::Model(Int64)
    #   db_context AcmeDB, :authors
    #
    #   has_many :articles, Article, foreign_key: :author_id, dependent: :destroy
    # end
    # ```
    macro has_many(name, type, foreign_key = nil, dependent = nil, inverse_of = nil, scope = nil)
      {% valid_dependents = %w[destroy delete_all nullify restrict_with_error] %}
      {% unless name.is_a?(SymbolLiteral) %}
        {{ raise "CQL has_many error in #{@type}: association name must be a symbol literal, for example `has_many :posts, Post`." }}
      {% end %}
      {% unless foreign_key == nil || foreign_key.is_a?(SymbolLiteral) %}
        {{ raise "CQL has_many error in #{@type}: foreign_key must be a symbol literal, for example `has_many :posts, Post, foreign_key: :user_id`." }}
      {% end %}
      {% unless dependent == nil || (dependent.is_a?(SymbolLiteral) && valid_dependents.includes?(dependent.id.stringify)) %}
        {{ raise "CQL has_many error in #{@type}: unsupported dependent option `#{dependent}`. Supported options: #{valid_dependents.join(", ")}." }}
      {% end %}
      {% strategy = dependent || :nullify %}

      {% if dependent == :restrict_with_error %}
        restrict_delete_by {{name}}
      {% elsif dependent %}
        apply_on_delete {{name}}
      {% end %}

      # Determine foreign key name if not provided (a symbol literal or the default, as an identifier)
      {% fk = (foreign_key || "#{@type.name.split("::").last.underscore.id}_id").id %}

      module ::CQL::ActiveRecord::AssociationRegistry::{{@type.name.gsub(/::/, "__").id}}__has_many__{{name.id}}
        KIND = :has_many
        OWNER = {{@type}}
        TARGET = {{type}}
        ASSOCIATION = {{name}}
        FOREIGN_KEY = :{{fk}}
      end

      {% if target_model = type.resolve? %}
        {% parent_id_getter = @type.methods.find { |method| method.name == "id!" && method.args.empty? } %}
        {% target_fk_getter = target_model.methods.find { |method| method.name == fk.stringify && method.args.empty? } %}
        {% shared_key = fk.id == (target_model.constant(:CQL_PRIMARY_KEY_COLUMN) || :id).id %}
        {% unless target_fk_getter || shared_key %}
          {{ raise "CQL has_many error in #{@type}: target model #{type} does not define foreign key `#{fk}`. Add a typed getter/property to #{type}, for example `property #{fk} : #{parent_id_getter ? parent_id_getter.return_type : "ParentPk"}?`." }}
        {% end %}
        {% if parent_id_getter && !shared_key %}
          {% fk_type = target_fk_getter.return_type.stringify.split("|").map(&.strip).reject { |part| part == "Nil" || part == "::Nil" }.join(" | ") %}
          {% pk_type = (@type.constant(:CQL_PRIMARY_KEY_TYPE) || parent_id_getter.return_type).stringify.split("|").map(&.strip).reject { |part| part == "Nil" || part == "::Nil" }.join(" | ") %}
          {% unless fk_type == pk_type %}
            {{ raise "CQL has_many error in #{@type}: target foreign key #{type}##{fk} type " + fk_type + " does not match #{@type}.id! primary key type " + pk_type + ". Change `#{fk}` to " + pk_type + " or update the parent model primary key type." }}
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

        # Build base query; the collection scopes it to the parent
        base_query = safe_db_operation do
          build_query({{type.id}})
        end

        # Apply additional scope if provided
        {% if scope %}
          scoped_query = base_query.instance_eval({{scope}})
        {% else %}
          scoped_query = base_query
        {% end %}

        @{{name.id}} = CQL::ActiveRecord::Relations::Collection({{type.id}}, Pk).new(
          key: :{{fk}},
          id: parent_id,
          query: scoped_query,
          dependent: {{strategy}},
          auto_load: false,
          binding: binding
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
          key: :{{fk}},
          id: parent_id,
          dependent: {{strategy}},
          auto_load: false,
          binding: binding
        )
        @{{name.id}}.not_nil!._inject_preloaded(records)
      end

      # Class method to preload this association for a collection of parent records.
      # Fetches the related records with one query per *chunk_size* parent ids (the dialect's
      # bind-parameter limit by default) and distributes them.
      # - **param** : records (Array(self)) - The parent records
      # - **param** : chunk_size (Int32) - The most parent ids bound by one query
      # - **return** : Nil
      def self._preload_{{name.id}}(records : Array(self), chunk_size : Int32 = {{type.id}}.adapter.dialect.max_bind_params - 1) : Nil
        binding = preload_binding(records)
        parent_ids = records.compact_map(&.id)
        return if parent_ids.empty?

        grouped = {} of Pk => Array({{type.id}})
        CQL::ActiveRecord::IdChunks.each(parent_ids, chunk_size) do |ids|
          {{type.id}}.on(binding).where({ :{{fk}} => ids }).all.each do |record|
            fk_value = record.{{fk}}
            next if fk_value.nil?
            (grouped[fk_value.as(Pk)] ||= [] of {{type.id}}) << record
          end
        end

        # Inject preloaded records into each parent
        records.map! do |parent|
          parent_id = parent.id
          next parent if parent_id.nil?
          related = grouped[parent_id.as(Pk)]? || [] of {{type.id}}
          parent._set_preloaded_{{name.id}}(related)
          parent
        end
      end

      # Applies the `dependent:` strategy to the associated records in the database, loaded or not;
      # `delete!` calls it when `dependent:` is declared
      def handle_{{name.id}}_dependency : Nil
        clear_{{name.id}}_cache
        collection = {{name.id}}

        {% if strategy == :destroy %}
          collection.each { |record| destroy_dependent(record, {{name}}) }
        {% elsif strategy == :delete_all %}
          collection.delete_all
        {% elsif strategy == :nullify %}
          collection.nullify_all
        {% else %}
          raise RelationError.new("Cannot delete record because dependent {{name.id}} exist") unless collection.empty?
        {% end %}
      end

      # Count associated records without loading them
      def {{name.id}}_count : Int64
        return @{{name.id}}.not_nil!.size.to_i64 if @{{name.id}} && @{{name.id}}.not_nil!.loaded?

        parent_id = safe_id(self, Pk)

        safe_db_operation do
          build_query({{type.id}}).where({ :{{fk}} => CQL::ActiveRecord::IdChunks.bound(parent_id) }).count.get(Int64?) || 0_i64
        end
      end

      # Check if any associated records exist without loading them
      def {{name.id}}_any? : Bool
        !{{name.id}}.empty?
      end

      # Create associated records in batch
      def create_{{name.id}}(records : Array({{type.id}})) : Array({{type.id}})
        parent_id = safe_id(self, Pk)

        safe_db_operation do
          created_records = [] of {{type.id}}

          records.each do |record|
             record = record.with_binding(binding)
             record.attributes({ :{{fk}} => parent_id })
             record.new_record? ? record.create! : record.save!
             created_records << record
           end

          # Clear cache to ensure fresh data on next access
          @{{name.id}} = nil

          created_records
        end
      end

      # Inserts *rows* (column values) as associated records with `{{type.id}}.insert_all`, setting
      # `{{fk}}` on each to this record's id, and returns how many were inserted. Unlike
      # `create_{{name.id}}`, it runs no validations or callbacks and builds no records.
      def insert_{{name.id}}_all(rows : Array(Hash(Symbol, DB::Any)), batch_size : Int32? = nil) : Int64
        owner = { :{{fk}} => CQL::ActiveRecord::IdChunks.bound(safe_id(self, Pk)) }
        inserted = {{type.id}}.on(binding).insert_all(rows.map(&.merge(owner)), batch_size)
        @{{name.id}} = nil
        inserted
      end

      # Named-tuple rows; see the hash overload.
      def insert_{{name.id}}_all(rows : Array(NamedTuple), batch_size : Int32? = nil) : Int64
        insert_{{name.id}}_all(rows.map { |row| row.to_h.transform_values(&.as(DB::Any)) }, batch_size)
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
  end
end
