struct Post
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :posts

  getter id : Int64?
  getter title : String
  getter content : String
  getter published : Bool
  property views_count : Int64
  getter user_id : Int64
  getter category_id : Int64?
  getter created_at : Time?
  getter updated_at : Time?

  belongs_to :user, User, foreign_key: :user_id
  belongs_to :category, Category, foreign_key: :category_id, optional: true
  has_many :comments, Comment, foreign_key: :post_id

  def initialize(@title : String, @content : String, @user_id : Int64,
                 @published : Bool = false, @views_count : Int64 = 0,
                 @category_id : Int64? = nil, @created_at : Time? = nil,
                 @updated_at : Time? = nil)
  end

  def published?
    published
  end

  def word_count
    content.split.size
  end
end
