class Post
  include CQL::ActiveRecord::Model(Int32)

  db_context schema: UserDB, table: :posts

  property title : String
  property body : String
  property user_id : Int32?

  belongs_to :user, TestUser, :user_id, optional: true, cache: true

  def initialize(@title, @body, @user_id = 0)
  end
end
