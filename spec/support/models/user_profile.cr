class UserProfile
  include CQL::ActiveRecord::Model(Int32)

  db_context schema: UserDB, table: :profiles

  property bio : String
  property avatar_url : String
  property profile_owner_id : Int32?

  belongs_to :profile_owner, ProfileOwner, :profile_owner_id

  def initialize(@bio, @avatar_url, @profile_owner_id = nil)
  end
end
