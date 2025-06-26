struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :users

  getter id : Int64?
  getter username : String
  getter email : String
  getter first_name : String?
  getter last_name : String?
  getter? active : Bool = true
  getter created_at : Time?
  getter updated_at : Time?

  has_many :posts, Post, foreign_key: :user_id
  has_many :comments, Comment, foreign_key: :user_id

  def initialize(@username : String, @email : String,
                 @first_name : String? = nil, @last_name : String? = nil,
                 @active : Bool = true, @created_at : Time? = nil,
                 @updated_at : Time? = nil)
  end

  def full_name
    if first_name && last_name
      "#{first_name} #{last_name}"
    elsif first_name
      first_name.not_nil!
    else
      username
    end
  end
end
