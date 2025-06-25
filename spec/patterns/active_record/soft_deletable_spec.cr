require "../../spec_helper"
require "../../support/schemas/soft_deletable_schema"

# Create a test model with soft deletes
class SoftDeletableUser
  include CQL::ActiveRecord::Model(Int32)
  include CQL::ActiveRecord::SoftDeletable

  db_context schema: SoftDeletableDB, table: :users

  property name : String
  property email : String
  property age : Int32 = 0

  def initialize(@name, @email, @age = 0)
  end
end

describe CQL::ActiveRecord::SoftDeletable do
  before_each do
    SoftDeletableDB.users.drop! rescue nil
    SoftDeletableDB.users.create!
  end

  after_each do
    SoftDeletableDB.users.drop!
  end

  describe "basic soft delete functionality" do
    it "marks records as deleted instead of removing them" do
      user = SoftDeletableUser.new("John Doe", "john@example.com", 30)
      user.create!
      user.id.should be_a(Int32)

      # User should not be deleted initially
      user.deleted?.should be_false

      # Soft delete the user
      result = user.delete!
      result.should be_true

      # User should be marked as deleted
      user.deleted?.should be_true
      user.deleted_at.should be_a(Time)

      # User should not appear in normal queries
      SoftDeletableUser.all.should be_empty
      SoftDeletableUser.count.should eq(0)
    end

    it "allows accessing soft-deleted records with with_deleted scope" do
      user = SoftDeletableUser.new("Jane Doe", "jane@example.com", 25)
      user.create!
      user.delete!

      # Normal query should be empty
      SoftDeletableUser.all.should be_empty

      # with_deleted should include soft-deleted records
      all_users = SoftDeletableUser.with_deleted.all
      all_users.size.should eq(1)
      all_users.first.name.should eq("Jane Doe")
    end

    it "allows accessing only soft-deleted records with only_deleted scope" do
      # Create two users
      user1 = SoftDeletableUser.new("Alice", "alice@example.com", 20)
      user2 = SoftDeletableUser.new("Bob", "bob@example.com", 22)
      user1.create!
      user2.create!

      # Delete only one user
      user1.delete!

      query, params = SoftDeletableUser.only_deleted.to_sql_with_params
      puts "\n\nquery: #{query}"
      puts "params: #{params}"

      # only_deleted should return only the soft-deleted user
      deleted_users = SoftDeletableUser.only_deleted.all
      puts "deleted_users: #{deleted_users.size}"

      deleted_users.size.should eq(1)
      deleted_users.first.name.should eq("Alice")

      # Normal query should return only the non-deleted user
      active_users = SoftDeletableUser.all
      active_users.size.should eq(1)
      active_users.first.name.should eq("Bob")
    end
  end

  describe "restore functionality" do
    it "allows restoring soft-deleted records" do
      user = SoftDeletableUser.new("Restored User", "restore@example.com", 35)
      user.create!
      user.delete!

      # User should be soft-deleted
      user.deleted?.should be_true
      SoftDeletableUser.all.should be_empty

      # Restore the user
      result = user.restore!
      result.should be_true

      # User should no longer be deleted
      user.deleted?.should be_false
      user.deleted_at.should be_nil

      # User should appear in normal queries
      SoftDeletableUser.all.size.should eq(1)
      SoftDeletableUser.first.try(&.name).should eq("Restored User")
    end

    it "allows restoring records by ID using class method" do
      user = SoftDeletableUser.new("Class Restore", "class_restore@example.com", 40)
      user.create!
      user_id = user.id!
      user.delete!

      # User should be soft-deleted
      SoftDeletableUser.all.should be_empty

      # Restore using class method
      result = SoftDeletableUser.restore!(user_id)
      result.should be_true

      # User should be restored
      SoftDeletableUser.all.size.should eq(1)
      SoftDeletableUser.first.try(&.name).should eq("Class Restore")
    end

    it "returns false when trying to restore a non-deleted record" do
      user = SoftDeletableUser.new("Not Deleted", "not_deleted@example.com", 30)
      user.create!

      # User is not deleted
      user.deleted?.should be_false

      # restore! should return false
      result = user.restore!
      result.should be_false
    end
  end

  describe "force delete functionality" do
    it "permanently deletes records with force_delete!" do
      user = SoftDeletableUser.new("Force Delete", "force@example.com", 28)
      user.create!
      user_id = user.id!

      # Force delete the user
      result = user.force_delete!
      result.should be_true

      # User should be completely gone
      user.id.should be_nil
      SoftDeletableUser.with_deleted.find(user_id).should be_nil
    end

    it "permanently deletes records by ID using class method" do
      user = SoftDeletableUser.new("Force Delete Class", "force_class@example.com", 32)
      user.create!
      user_id = user.id!

      # Force delete using class method
      result = SoftDeletableUser.force_delete!(user_id)
      result.rows_affected.should eq(1)

      # User should be completely gone
      SoftDeletableUser.with_deleted.find(user_id).should be_nil
    end
  end

  describe "class methods" do
    it "provides acts_as_paranoid? to check if model uses soft deletes" do
      SoftDeletableUser.acts_as_paranoid?.should be_true
    end

    it "soft deletes records by ID using delete!" do
      user = SoftDeletableUser.new("Delete By ID", "delete_id@example.com", 26)
      user.create!
      user_id = user.id!

      # Delete using class method
      result = SoftDeletableUser.delete!(user_id)
      result.rows_affected.should eq(1)

      # User should be soft-deleted
      SoftDeletableUser.all.should be_empty
      SoftDeletableUser.with_deleted.find(user_id).try(&.deleted?).should be_true
    end

    it "soft deletes records by attributes using delete_by!" do
      user1 = SoftDeletableUser.new("Delete By Email 1", "delete_by@example.com", 25)
      user2 = SoftDeletableUser.new("Delete By Email 2", "delete_by@example.com", 30)
      user1.create!
      user2.create!

      # Delete by email
      result = SoftDeletableUser.delete_by!(email: "delete_by@example.com")
      result.rows_affected.should eq(2)

      # Users should be soft-deleted
      SoftDeletableUser.all.should be_empty
      SoftDeletableUser.only_deleted.count.should eq(2)
    end

    it "provides count methods for different states" do
      # Create some users
      user1 = SoftDeletableUser.new("Count 1", "count1@example.com", 25)
      user2 = SoftDeletableUser.new("Count 2", "count2@example.com", 30)
      user3 = SoftDeletableUser.new("Count 3", "count3@example.com", 35)

      user1.create!
      user2.create!
      user3.create!

      # Delete one user
      user1.delete!

      # Test count methods
      SoftDeletableUser.count.should eq(2)              # Active users
      SoftDeletableUser.count_with_deleted.should eq(3) # All users
      SoftDeletableUser.count_only_deleted.should eq(1) # Deleted users
    end

    it "restores all soft-deleted records with restore_all" do
      # Create and delete some users
      user1 = SoftDeletableUser.new("Restore All 1", "restore_all1@example.com", 25)
      user2 = SoftDeletableUser.new("Restore All 2", "restore_all2@example.com", 30)

      user1.create!
      user2.create!
      user1.delete!
      user2.delete!

      # All users should be soft-deleted
      SoftDeletableUser.count.should eq(0)
      SoftDeletableUser.count_only_deleted.should eq(2)

      # Restore all
      SoftDeletableUser.restore_all

      # All users should be restored
      SoftDeletableUser.count.should eq(2)
      SoftDeletableUser.count_only_deleted.should eq(0)
    end

    it "soft deletes all records with delete_all" do
      # Create some users
      user1 = SoftDeletableUser.new("Delete All 1", "delete_all1@example.com", 25)
      user2 = SoftDeletableUser.new("Delete All 2", "delete_all2@example.com", 30)

      user1.create!
      user2.create!

      # Delete all
      SoftDeletableUser.delete_all

      # All users should be soft-deleted
      SoftDeletableUser.count.should eq(0)
      SoftDeletableUser.count_only_deleted.should eq(2)
    end

    it "force deletes all records with force_delete_all" do
      # Create some users
      user1 = SoftDeletableUser.new("Force Delete All 1", "force_delete_all1@example.com", 25)
      user2 = SoftDeletableUser.new("Force Delete All 2", "force_delete_all2@example.com", 30)

      user1.create!
      user2.create!

      # Force delete all
      result = SoftDeletableUser.force_delete_all
      result.rows_affected.should eq(2)

      # All users should be gone
      SoftDeletableUser.count_with_deleted.should eq(0)
    end
  end

  describe "query integration" do
    it "automatically filters soft-deleted records from all query methods" do
      user1 = SoftDeletableUser.new("Query Test 1", "query1@example.com", 25)
      user2 = SoftDeletableUser.new("Query Test 2", "query2@example.com", 30)

      user1.create!
      user2.create!
      user1.delete!

      # Test various query methods
      SoftDeletableUser.all.size.should eq(1)
      SoftDeletableUser.first.try(&.name).should eq("Query Test 2")
      SoftDeletableUser.find_by(name: "Query Test 1").should be_nil
      SoftDeletableUser.find_by(name: "Query Test 2").should_not be_nil
      SoftDeletableUser.where(age: 25).all.should be_empty
      SoftDeletableUser.where(age: 30).all.size.should eq(1)
    end

    it "works with chained scopes" do
      user1 = SoftDeletableUser.new("Chain 1", "chain1@example.com", 25)
      user2 = SoftDeletableUser.new("Chain 2", "chain2@example.com", 30)
      user3 = SoftDeletableUser.new("Chain 3", "chain3@example.com", 25)

      user1.create!
      user2.create!
      user3.create!
      user1.delete!

      # Chain with_deleted and where
      results = SoftDeletableUser.with_deleted.where(age: 25).all
      results.size.should eq(2)
      results.map(&.name).sort!.should eq(["Chain 1", "Chain 3"])

      # Chain only_deleted and where
      deleted_results = SoftDeletableUser.only_deleted.where(age: 25).all
      deleted_results.size.should eq(1)
      deleted_results.first.name.should eq("Chain 1")
    end
  end

  describe "edge cases" do
    it "handles nil deleted_at properly" do
      user = SoftDeletableUser.new("Nil Test", "nil@example.com", 25)
      user.create!

      # User should not be deleted
      user.deleted?.should be_false
      user.deleted_at.should be_nil

      # User should appear in normal queries
      SoftDeletableUser.all.size.should eq(1)
    end

    it "returns false when trying to delete without ID" do
      user = SoftDeletableUser.new("No ID", "no_id@example.com", 25)

      # delete! should return false for unsaved records
      result = user.delete!
      result.should be_false
    end

    it "returns false when trying to force delete without ID" do
      user = SoftDeletableUser.new("No ID Force", "no_id_force@example.com", 25)

      # force_delete! should return false for unsaved records
      result = user.force_delete!
      result.should be_false
    end
  end
end
