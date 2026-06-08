require "./definition"
require "./association_registry"
require "./schema_validator"
require "./queryable"
require "./insertable"
require "./updateable"
require "./deleteable"
require "./validations"
require "./attributes"
require "./callbacks"
require "./persistence"
require "./identifyable"
require "./relations"
require "./scopes"
require "./transactional"
require "./optimistic_locking"
require "./pagination"

module CQL
  alias Model = CQL::ActiveRecord::Model

  module ActiveRecord
    # The Model module provides Active Record functionality for your models.
    # It combines validations, callbacks, persistence, and relationship handling
    # following SOLID principles.
    #
    # **Example** Using the Model module
    #
    # ```
    # struct Post
    #   include CQL::ActiveRecord::Model
    #   db_context AcmeDB, :posts
    #
    #   # Define attributes
    #   getter id : Int64?
    #   getter title : String
    #   getter body : String
    #   getter published_at : Time
    #
    #   # Define validations
    #   validates :title, presence: true, length: {minimum: 3, maximum: 100}
    #   validates :body, presence: true
    #
    #   # Define callbacks
    #   before_save :set_published_at
    #
    #   # Define relationships
    #   has_many :comments, Comment, foreign_key: :post_id
    #
    #   # Constructor
    #   def initialize(@title : String, @body : String, @published_at : Time = Time.utc)
    #   end
    #
    #   # Callback method
    #   private def set_published_at
    #     @published_at = Time.utc if @published_at.nil?
    #   end
    # end
    # ```
    module Model(Pk)
      macro included
        CQL_PRIMARY_KEY_TYPE = {{Pk}}

        include DB::Serializable
        include DB::Serializable::NonStrict
        include CQL::ActiveRecord::Definition
        include CQL::ActiveRecord::Identifyable
        include CQL::ActiveRecord::Attributes
        include CQL::ActiveRecord::Callbacks
        include CQL::ActiveRecord::Validations
        include CQL::ActiveRecord::Queryable
        include CQL::ActiveRecord::Insertable
        include CQL::ActiveRecord::Updateable
        include CQL::ActiveRecord::Deleteable
        include CQL::ActiveRecord::Persistence
        include CQL::ActiveRecord::Relations
        include CQL::ActiveRecord::Scopes
        include CQL::ActiveRecord::Transactional
        include CQL::ActiveRecord::Pagination
      end

      macro finished
        {% for registry_constant in CQL::ActiveRecord::AssociationRegistry.constants %}
          {% metadata = CQL::ActiveRecord::AssociationRegistry.constant(registry_constant).resolve %}
          {% kind = metadata.constant(:KIND) %}
          {% owner = metadata.constant(:OWNER).resolve %}
          {% target_path = metadata.constant(:TARGET) %}
          {% target = target_path.resolve? %}
          {% association = metadata.constant(:ASSOCIATION) %}
          {% foreign_key = metadata.constant(:FOREIGN_KEY) %}

          {% unless target %}
            {{ raise "CQL association error in #{owner}: association `#{association}` references #{target_path}, but that model type was not found. Define the target model or require the file that defines it before compiling." }}
          {% end %}

          {% if kind == :belongs_to %}
            {% fk_getter = owner.methods.find { |method| method.name == foreign_key.id.stringify && method.args.empty? } %}
            {% unless fk_getter %}
              {{ raise "CQL belongs_to error in #{owner}: foreign key `#{foreign_key}` is not defined. Add a typed getter/property before the association, for example `property #{foreign_key.id} : #{target}.id_type?`." }}
            {% end %}

            {% target_id_getter = target.methods.find { |method| method.name == "id!" && method.args.empty? } %}
            {% if target_id_getter %}
              {% fk_type = fk_getter.return_type.stringify.split("|").map(&.strip).reject { |part| part == "Nil" || part == "::Nil" }.join(" | ") %}
              {% pk_type = (target.constant(:CQL_PRIMARY_KEY_TYPE) || target_id_getter.return_type).stringify.split("|").map(&.strip).reject { |part| part == "Nil" || part == "::Nil" }.join(" | ") %}
              {% unless fk_type == pk_type %}
                {{ raise "CQL belongs_to error in #{owner}: foreign key `#{foreign_key}` type " + fk_type + " does not match #{target}.id! primary key type " + pk_type + ". Change `#{foreign_key}` to " + pk_type + " or update the target model primary key type." }}
              {% end %}
            {% end %}
          {% elsif kind == :has_many %}
            {% parent_id_getter = owner.methods.find { |method| method.name == "id!" && method.args.empty? } %}
            {% target_fk_getter = target.methods.find { |method| method.name == foreign_key.id.stringify && method.args.empty? } %}
            {% unless target_fk_getter %}
              {{ raise "CQL has_many error in #{owner}: target model #{target} does not define foreign key `#{foreign_key}`. Add a typed getter/property to #{target}, for example `property #{foreign_key.id} : #{parent_id_getter ? parent_id_getter.return_type : "ParentPk"}?`." }}
            {% end %}
            {% if parent_id_getter %}
              {% fk_type = target_fk_getter.return_type.stringify.split("|").map(&.strip).reject { |part| part == "Nil" || part == "::Nil" }.join(" | ") %}
              {% pk_type = (owner.constant(:CQL_PRIMARY_KEY_TYPE) || parent_id_getter.return_type).stringify.split("|").map(&.strip).reject { |part| part == "Nil" || part == "::Nil" }.join(" | ") %}
              {% unless fk_type == pk_type %}
                {{ raise "CQL has_many error in #{owner}: target foreign key #{target}##{foreign_key.id} type " + fk_type + " does not match #{owner}.id! primary key type " + pk_type + ". Change `#{foreign_key}` to " + pk_type + " or update the parent model primary key type." }}
              {% end %}
            {% end %}
          {% end %}
        {% end %}
      end
    end
  end
end
