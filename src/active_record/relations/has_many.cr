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
    #   include CQL::Model(User, Int64)
    #   property id : Int64
    #   property name : String
    #   has_many :posts, Post, foreign_key: :user_id, dependent: :destroy
    # end
    # ```
    macro has_many(name, type, foreign_key = nil, dependent = :nullify, inverse_of = nil, scope = nil)
      # Determine foreign key name if not provided
      {% fk = foreign_key || "#{@type.name.underscore.id}_id".id %}

      # Define an instance variable to memoize the collection
      @[DB::Field(ignore: true)]
      @_{{name.id}} : CQL::ActiveRecord::Relations::Collection({{type.id}}, Pk)?

      # Enhanced getter that memoizes the collection with proper error handling
      @[DB::Field(ignore: true)]
      def {{name.id}} : CQL::ActiveRecord::Relations::Collection({{type.id}}, Pk)
        return @_{{name.id}}.not_nil! if @_{{name.id}}

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

        @_{{name.id}} = CQL::ActiveRecord::Relations::Collection({{type.id}}, Pk).new(
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
        @_{{name.id}} = nil
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
        return @_{{name.id}}.not_nil!.size.to_i64 if @_{{name.id}} && @_{{name.id}}.not_nil!.loaded?

        parent_id = safe_id(self, Pk)

                 safe_db_operation do
           build_query({{type.id}}).where({ {{fk}} => parent_id }).count
         end
      end

      # Check if any associated records exist without loading them
      def {{name.id}}_any? : Bool
        return !@_{{name.id}}.not_nil!.empty? if @_{{name.id}} && @_{{name.id}}.not_nil!.loaded?

        parent_id = safe_id(self, Pk)

                 safe_db_operation do
           begin
             build_query({{type.id}}).where({ {{fk}} => parent_id }).limit(1).first({{type.id}})
             true
           rescue DB::NoResultsError
             false
           end
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
          @_{{name.id}} = nil

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
