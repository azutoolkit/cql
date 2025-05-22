require "./definition"
require "./query"
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

module CQL
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
      end
    end
  end
end
