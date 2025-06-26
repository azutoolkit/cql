struct Comment
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :comments

  getter id : Int64?
  getter content : String
  getter post_id : Int64
  getter user_id : Int64?
  getter created_at : Time?
  getter updated_at : Time?

  belongs_to :post, Post, foreign_key: :post_id
  belongs_to :user, User, foreign_key: :user_id, optional: true

  def initialize(@content : String, @post_id : Int64, @user_id : Int64? = nil,
                 @created_at : Time? = nil, @updated_at : Time? = nil)
  end
end
