require "./spec_helper"

# Tracks changes, to check that a rolled-back insert leaves the record as unsaved as it was before.
private class RollbackTrackedUser
  include CQL::ActiveRecord::Model(Int32)
  include CQL::ActiveRecord::DirtyTracking
  db_context TestDBTransactional, :test_users_transactional

  property name : String = "" # a default: DirtyTracking's DB::Serializable initializer sets no field itself
  property email : String? = nil

  def initialize(@name : String)
  end
end

describe "A record inserted in a transaction that rolls back" do
  db = TestDBTransactional.tap(&.build)
  before_each { db.exec("DELETE FROM test_users_transactional") }

  it "is new again after the transaction raises, so the next save! inserts it" do
    user = TestUserTransactional.new("Ann")
    expect_raises(Exception, "boom") { db.transaction { user.save!; raise "boom" } }
    {user.new_record?, user.id}.should eq({true, nil})
    user.save!.should be_true
    {TestUserTransactional.count, TestUserTransactional.find_by_name!("Ann").id}.should eq({1, user.id})
  end

  it "is new again after a DB::Rollback, which the transaction swallows" do
    user = TestUserTransactional.new("Ann")
    db.transaction { user.save!; raise DB::Rollback.new("undo") }
    {user.new_record?, user.id}.should eq({true, nil})
  end

  it "is new again when its savepoint rolls back, while the enclosing transaction keeps its own insert" do
    kept, undone = TestUserTransactional.new("Kept"), TestUserTransactional.new("Undone")
    db.transaction do
      kept.save!
      db.transaction { undone.save!; raise "boom" } rescue nil
    end
    {kept.new_record?, undone.new_record?, undone.id}.should eq({false, true, nil})
    TestUserTransactional.find_by_name!("Kept").id.should eq kept.id
  end

  it "is new again when the enclosing transaction rolls back after its savepoint committed" do
    user = TestUserTransactional.new("Ann")
    db.transaction { db.transaction { user.save! }; raise DB::Rollback.new("undo") }
    {user.new_record?, user.id, TestUserTransactional.count}.should eq({true, nil, 0})
  end

  it "keeps its id once the outermost transaction commits, through a later rollback too" do
    user = TestUserTransactional.new("Ann")
    db.transaction { db.transaction { user.save! } }
    db.transaction { raise DB::Rollback.new("unrelated") }
    user.id.should eq TestUserTransactional.find_by_name!("Ann").id
  end

  it "reports its attributes as unsaved again, as before the insert" do
    user = RollbackTrackedUser.new("Ann")
    expect_raises(Exception, "boom") { db.transaction { user.save!; raise "boom" } }
    user.changes[:name]?.should eq({nil, "Ann"})
  end
end

describe "A record deleted in a transaction that rolls back" do
  db = TestDBTransactional.tap(&.build)
  before_each { db.exec("DELETE FROM test_users_transactional") }

  it "gets its id back, so the next save! updates its row instead of inserting a second one" do
    user = TestUserTransactional.create!(name: "Ann")
    id = user.id
    expect_raises(Exception, "boom") { db.transaction { user.delete!; raise "boom" } }
    {user.id, user.destroyed?}.should eq({id, false})
    user.update!(name: "Bea")
    TestUserTransactional.all.map { |row| {row.id, row.name} }.should eq [{id, "Bea"}]
  end

  it "stays deleted when the block committed the delete before raising" do
    user = TestUserTransactional.create!(name: "Ann")
    expect_raises(Exception, "boom") { db.transaction { |tx| user.delete!; tx.commit; raise "boom" } }
    {user.id, user.destroyed?, TestUserTransactional.count}.should eq({nil, true, 0})
  end
end
