# Define our Post model with various scopes
class ScopesPost
  include CQL::ActiveRecord::Model(Int64)

  db_context MyApp::DB, :scopes_posts

  # Define attributes
  getter id : Int64?
  getter title : String
  getter body : String
  # ameba:disable Naming/QueryBoolMethods
  getter published : Bool
  # ameba:enable Naming/QueryBoolMethods
  getter category : String
  getter created_at : Time

  # Define scopes
  scope :published, -> { where(published: true) }
  scope :recent, -> { limit(3).order(created_at: :asc) }

  scope :with_title, ->(title_param : String) do
    where_like(:title, "%#{title_param}%")
  end

  scope :by_category, ->(category : String) { where(category: category) }

  # Constructor
  def initialize(
    @title : String,
    @body : String,
    @category : String,
    @published = false,
    @created_at = Time.utc,
  )
  end
end
