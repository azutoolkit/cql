class ProfileOwner
  include CQL::ActiveRecord::Model(Int32)

  db_context schema: UserDB, table: :profile_owners

  property name : String
  property email : String
  property age : Int32
  property password : String
  property password_confirmation : String

  has_one :profile, UserProfile

  def initialize(@name, @email, @age, @password, @password_confirmation)
  end
end
