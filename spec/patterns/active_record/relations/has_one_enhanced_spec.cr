require "../spec_helper"

describe "CQL::ActiveRecord::Relations::HasOne Enhanced Tests" do
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

  describe "dependency strategies" do
    it "destroys associated record when dependent: :destroy" do
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

      profile_id = profile.id!

      # Delete the profile using dependent strategy
      user.delete_profile.should be_true

      # Verify the profile record is deleted from database
      expect_raises(DB::NoResultsError) do
        UserProfile.find!(profile_id)
      end
    end

    it "nullifies foreign key when dependent: :nullify" do
      # Create a test model with nullify dependency
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

      # Clear the association (which should nullify)
      user.clear_profile.should be_true

      # Verify the profile still exists but foreign key is null
      profile.reload!
      profile.profile_owner_id.should be_nil
    end

    it "handles dependency when parent is destroyed" do
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

      profile_id = profile.id!

      # Destroy the parent (this should handle the dependency)
      user.handle_profile_dependency

      # Verify the profile record is deleted from database
      expect_raises(DB::NoResultsError) do
        UserProfile.find!(profile_id)
      end
    end
  end

  describe "caching behavior" do
    it "caches the associated record after first access" do
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

      # First access should load from database
      associated_profile = user.profile
      associated_profile.should_not be_nil

      # Check if cached
      user.profile_loaded?.should be_true

      # Second access should use cache (same object reference)
      cached_profile = user.profile
      cached_profile.should be(associated_profile)
    end

    it "reloads the association when requested" do
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

      # Load the association
      original_profile = user.profile
      original_profile.should_not be_nil

      # Update the profile outside the association
      profile.bio = "Senior Software Developer"
      profile.save!

      # Reload the association
      reloaded_profile = user.reload_profile
      reloaded_profile.should_not be_nil
      reloaded_profile.not_nil!.bio.should eq("Senior Software Developer")
    end

    it "invalidates cache when association is set" do
      user = ProfileOwner.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      profile1 = UserProfile.new(
        bio: "Software developer",
        avatar_url: "https://example.com/avatar1.jpg",
        profile_owner_id: user.id
      )
      profile1.create!

      profile2 = UserProfile.new(
        bio: "Senior Software developer",
        avatar_url: "https://example.com/avatar2.jpg"
      )

      # Load the association to cache it
      user.profile.should_not be_nil
      user.profile_loaded?.should be_true

      # Change the association
      user.profile = profile2

      # Verify the cached value is updated
      user.profile.should_not be_nil
      user.profile.not_nil!.bio.should eq("Senior Software developer")
    end
  end

  describe "error handling" do
    it "raises error when trying to update non-existent association" do
      user = ProfileOwner.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      expect_raises(CQL::ActiveRecord::Relations::BaseRelation::AssociationNotFound) do
        user.update_profile(bio: "New Bio")
      end
    end

    it "returns false when trying to delete non-existent association" do
      user = ProfileOwner.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      user.delete_profile.should be_false
    end

    it "returns false when trying to clear non-existent association" do
      user = ProfileOwner.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      user.clear_profile.should be_false
    end

    it "handles unsaved record when setting association" do
      user = ProfileOwner.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      unsaved_profile = UserProfile.new(
        bio: "Software developer",
        avatar_url: "https://example.com/avatar.jpg"
      )

      # This should work as has_one doesn't require persisted records
      user.profile = unsaved_profile
      user.profile.should_not be_nil
      user.profile.not_nil!.bio.should eq("Software developer")
    end

    it "raises error for invalid parent record" do
      user = ProfileOwner.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      # Don't save the user

      expect_raises(CQL::ActiveRecord::Relations::BaseRelation::UnsavedRecord) do
        user.build_profile(
          bio: "Software developer",
          avatar_url: "https://example.com/avatar.jpg"
        )
      end
    end
  end

  describe "edge cases" do
    it "handles replacing existing association" do
      user = ProfileOwner.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      # Create first profile
      profile1 = user.create_profile(
        bio: "Software developer",
        avatar_url: "https://example.com/avatar1.jpg"
      )

      profile1_id = profile1.id!

      # Create second profile (should replace the first)
      profile2 = user.create_profile(
        bio: "Senior Software developer",
        avatar_url: "https://example.com/avatar2.jpg"
      )

      # Verify the first profile is destroyed
      expect_raises(DB::NoResultsError) do
        UserProfile.find!(profile1_id)
      end

      # Verify the second profile is associated
      user.profile.should_not be_nil
      user.profile.not_nil!.id.should eq(profile2.id)
    end

    it "can set association to nil" do
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

      # Verify association exists
      user.profile.should_not be_nil

      # Set to nil
      user.profile = nil
      user.profile.should be_nil

      # Verify the profile's foreign key is nil
      profile.reload!
      profile.profile_owner_id.should be_nil
    end

    it "handles build without persisting parent" do
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
      profile.id.should be_nil # Not persisted yet
    end

    it "handles create with invalid attributes" do
      user = ProfileOwner.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user.create!

      # This should still work as UserProfile doesn't have validations
      profile = user.create_profile(
        bio: "",       # Empty bio
        avatar_url: "" # Empty URL
      )

      profile.should be_a(UserProfile)
      profile.bio.should eq("")
      profile.avatar_url.should eq("")
    end
  end

  describe "foreign key management" do
    it "properly sets foreign key when building" do
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

      profile.profile_owner_id.should eq(user.id)
    end

    it "properly updates foreign keys when setting association" do
      user1 = ProfileOwner.new(
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        password: "password123",
        password_confirmation: "password123"
      )
      user1.create!

      user2 = ProfileOwner.new(
        name: "Jane Doe",
        email: "jane@example.com",
        age: 25,
        password: "password123",
        password_confirmation: "password123"
      )
      user2.create!

      # Create profile for user1
      profile = user1.create_profile(
        bio: "Software developer",
        avatar_url: "https://example.com/avatar.jpg"
      )

      # Move profile to user2
      user2.profile = profile

      # Verify foreign key is updated
      profile.reload!
      profile.profile_owner_id.should eq(user2.id)

      # Verify user1 no longer has the profile
      user1.reload_profile.should be_nil
    end
  end
end
