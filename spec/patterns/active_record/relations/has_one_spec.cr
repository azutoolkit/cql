require "../spec_helper"

describe CQL::ActiveRecord::Relations::HasOne do
  before_each do
    UserDB.users.create!
    UserDB.posts.create!
    UserDB.profiles.create!
    UserDB.profile_owners.create!
  end

  after_each do
    UserDB.profile_owners.drop!
    UserDB.profiles.drop!
    UserDB.posts.drop!
    UserDB.users.drop!
  end

  describe "has_one association" do
    it "returns the associated profile" do
      user = ProfileOwner.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      profile = UserProfile.new(
        bio: "Software developer",
        avatar_url: "https://example.com/avatar.jpg",
        profile_owner_id: user.id
      )
      profile.create!

      user_profile = user.profile
      user_profile.should_not be_nil
      user_profile = user_profile.not_nil!
      user_profile.should be_a(UserProfile)
      user_profile.bio.should eq("Software developer")
      user_profile.avatar_url.should eq("https://example.com/avatar.jpg")
      user_profile.profile_owner_id.should eq(user.id)
    end

    it "sets the associated profile" do
      user = ProfileOwner.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      profile = UserProfile.new(
        bio: "Software developer",
        avatar_url: "https://example.com/avatar.jpg"
      )

      user.profile = profile
      profile.profile_owner_id.should eq(user.id)
    end

    it "builds a new associated profile" do
      user = ProfileOwner.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      profile = user.build_profile(
        bio: "Software developer",
        avatar_url: "https://example.com/avatar.jpg"
      )

      profile.should be_a(UserProfile)
      profile.bio.should eq("Software developer")
      profile.avatar_url.should eq("https://example.com/avatar.jpg")
      profile.profile_owner_id.should eq(user.id)
      profile.id.should be_nil
    end

    it "creates a new associated profile" do
      user = ProfileOwner.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      profile = user.create_profile(
        bio: "Software developer",
        avatar_url: "https://example.com/avatar.jpg"
      )

      profile.should be_a(UserProfile)
      profile.bio.should eq("Software developer")
      profile.avatar_url.should eq("https://example.com/avatar.jpg")
      profile.profile_owner_id.should eq(user.id)
      profile.id.should_not be_nil
    end

    it "updates the associated profile" do
      user = ProfileOwner.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      profile = UserProfile.new(
        bio: "Software developer",
        avatar_url: "https://example.com/avatar.jpg",
        profile_owner_id: user.id
      )
      profile.create!

      updated_profile = user.update_profile(bio: "Senior Software Developer")
      updated_profile.bio.should eq("Senior Software Developer")
      updated_profile.avatar_url.should eq("https://example.com/avatar.jpg")
      updated_profile.profile_owner_id.should eq(user.id)
    end

    it "deletes the associated profile" do
      user = ProfileOwner.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      profile = UserProfile.new(
        bio: "Software developer",
        avatar_url: "https://example.com/avatar.jpg",
        profile_owner_id: user.id
      )
      profile.create!

      user.delete_profile.should be_true
      expect_raises(DB::NoResultsError) do
        UserProfile.find!(profile.id.not_nil!)
      end
    end

    it "returns nil when no associated profile exists" do
      user = ProfileOwner.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      user.profile.should be_nil
    end
  end
end
