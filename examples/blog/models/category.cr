struct Category
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :categories

  getter id : Int64?
  getter name : String
  getter slug : String
  getter created_at : Time?
  getter updated_at : Time?

  has_many :posts, Post, foreign_key: :category_id

  def initialize(@name : String, @slug : String,
                 @created_at : Time? = nil, @updated_at : Time? = nil)
  end
end
