require "./definition"
require "./bound_model"
require "./association_registry"
require "./dsl/column"
require "./typed_columns"
require "./schema_validator"
require "./queryable"
require "./bulk_insert"
require "./id_chunks"
require "./insertable"
require "./updateable"
require "./deleteable"
require "./validations"
require "./attributes"
require "./callbacks"
require "./dependents"
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
    # class Article
    #   include CQL::ActiveRecord::Model(Int64)
    #   db_context AcmeDB, :posts
    #
    #   property title : String = ""
    #   property body : String?
    #   property user_id : Int64 = 0_i64
    #   property published : Bool = false
    #
    #   validate :title, presence: true, size: 3..100
    #
    #   before_validation :strip_title
    #
    #   belongs_to :user, User, :user_id
    #
    #   def initialize(@title : String = "", @user_id : Int64 = 0_i64)
    #   end
    #
    #   private def strip_title
    #     @title = @title.strip
    #   end
    # end
    # ```
    module Model(Pk)
      macro included
        CQL_PRIMARY_KEY_TYPE = {{Pk}}

        include DB::Serializable
        include DB::Serializable::NonStrict
        include CQL::ActiveRecord::Bindable
        include CQL::ActiveRecord::Definition
        include CQL::ActiveRecord::TypedColumns
        include CQL::ActiveRecord::Identifyable
        include CQL::ActiveRecord::Attributes
        include CQL::ActiveRecord::Callbacks
        include CQL::ActiveRecord::Validations
        include CQL::ActiveRecord::Queryable
        include CQL::ActiveRecord::Insertable
        include CQL::ActiveRecord::Updateable
        include CQL::ActiveRecord::Deleteable
        include CQL::ActiveRecord::Persistence
        include CQL::ActiveRecord::Dependents
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
          {% global = target_path.stringify.starts_with?("::") %}
          {% target_name = global ? target_path.stringify : "::" + target_path.stringify %}
          {% scopes = global ? [] of Nil : owner.name(generic_args: false).split("::") %}
          {% target = nil %}
          {% for depth in (0..scopes.size) %}
            {% prefix = scopes[0...(scopes.size - depth)].map { |scope| "::" + scope }.join("") %}
            {% target = target || parse_type(prefix + target_name).resolve? %}
          {% end %}
          {% association = metadata.constant(:ASSOCIATION) %}
          {% foreign_key = metadata.constant(:FOREIGN_KEY) %}

          {% unless target %}
            {{ raise "CQL association error in #{owner}: association `#{association}` references #{target_path}, but that model type was not found. Define the target model or require the file that defines it before compiling." }}
          {% end %}

          {% if kind == :has_many || kind == :has_one %}
            {% target_key = target.constant(:CQL_PRIMARY_KEY_COLUMN) || :id %}
            {% if foreign_key.id == target_key.id %}
              {{ raise "CQL #{kind.id} error in #{owner}: foreign key `#{foreign_key.id}` is the primary key of #{target}. Associations whose foreign key is the target's primary key (shared primary keys) are not supported: give #{target} its own key column and a separate `#{foreign_key.id}` column, or declare the association from #{target} with belongs_to." }}
            {% end %}
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
