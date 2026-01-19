require "../../spec_helper"

# Schema for UUID primary key tests
UuidTestDB = CQL::Schema.define(
  :uuid_test_db,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3:///tmp/uuid_pk_spec.db"
) do
  table :uuid_sessions do
    primary :id, String, auto_increment: false # UUID stored as TEXT in SQLite
    text :token
    bigint :user_id
    timestamps
  end
end

# Model with UUID primary key
# The id is stored as String in the database but exposed as UUID for type safety
class UuidSession
  include CQL::ActiveRecord::Model(UUID)

  db_context schema: UuidTestDB, table: :uuid_sessions

  property token : String = ""
  property user_id : Int64 = 0_i64
  property created_at : Time?
  property updated_at : Time?

  def initialize
  end

  def initialize(@token : String, @user_id : Int64)
  end
end

describe "UUID Primary Key Support" do
  before_all do
    UuidTestDB.uuid_sessions.drop! rescue nil
    UuidTestDB.uuid_sessions.create!
  end

  after_all do
    UuidTestDB.uuid_sessions.drop! rescue nil
  end

  # Clean up data between tests
  before_each do
    UuidTestDB.exec("DELETE FROM uuid_sessions")
  end

  describe ".create!" do
    context "with named arguments" do
      it "creates a record with a UUID primary key" do
        session = UuidSession.create!(
          token: "abc123",
          user_id: 1_i64,
          created_at: Time.utc,
          updated_at: Time.utc
        )

        session.id.should_not be_nil
        session.id.should be_a(UUID)
        session.token.should eq("abc123")
        session.user_id.should eq(1_i64)
      end

      it "generates unique UUIDs for each record" do
        session1 = UuidSession.create!(
          token: "token1",
          user_id: 1_i64,
          created_at: Time.utc,
          updated_at: Time.utc
        )
        session2 = UuidSession.create!(
          token: "token2",
          user_id: 2_i64,
          created_at: Time.utc,
          updated_at: Time.utc
        )

        session1.id.should_not eq(session2.id)
      end
    end

    context "with hash attributes" do
      it "creates a record with a UUID primary key" do
        attrs = {
          :token      => "def456",
          :user_id    => 2_i64,
          :created_at => Time.utc,
          :updated_at => Time.utc,
        } of Symbol => DB::Any

        session = UuidSession.create!(attrs)

        session.id.should_not be_nil
        session.id.should be_a(UUID)
        session.token.should eq("def456")
      end
    end

    context "with model instance" do
      it "creates a record and sets the UUID on the instance" do
        session = UuidSession.new("ghi789", 3_i64)
        session.created_at = Time.utc
        session.updated_at = Time.utc

        created = UuidSession.create!(session)

        created.id.should_not be_nil
        session.id.should eq(created.id) # Same instance should have ID set
        session.id.should be_a(UUID)
      end
    end
  end

  describe "#create!" do
    it "creates a record using instance method" do
      session = UuidSession.new("jkl012", 4_i64)
      session.created_at = Time.utc
      session.updated_at = Time.utc

      session.create!

      session.id.should_not be_nil
      session.id.should be_a(UUID)
      session.persisted?.should be_true
    end
  end

  describe ".find" do
    it "finds a record by UUID" do
      session = UuidSession.create!(
        token: "findme",
        user_id: 5_i64,
        created_at: Time.utc,
        updated_at: Time.utc
      )

      found = UuidSession.find!(session.id!)

      found.id.should eq(session.id)
      found.token.should eq("findme")
    end
  end

  describe ".find_or_create_by" do
    it "creates a new record if not found" do
      session = UuidSession.find_or_create_by(
        token: "unique_token",
        user_id: 6_i64,
        created_at: Time.utc,
        updated_at: Time.utc
      )

      session.id.should_not be_nil
      session.id.should be_a(UUID)
      session.token.should eq("unique_token")
    end

    it "returns existing record if found" do
      existing = UuidSession.create!(
        token: "existing_token",
        user_id: 7_i64,
        created_at: Time.utc,
        updated_at: Time.utc
      )

      found = UuidSession.find_or_create_by(token: "existing_token")

      found.id.should eq(existing.id)
    end
  end

  describe "UUID format validation" do
    it "generates valid UUID format" do
      session = UuidSession.create!(
        token: "format_test",
        user_id: 8_i64,
        created_at: Time.utc,
        updated_at: Time.utc
      )

      # UUID should be valid format (8-4-4-4-12 hex characters)
      uuid_string = session.id!.to_s
      uuid_string.should match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
    end
  end

  describe "multiple record creation" do
    it "generates unique UUIDs for 10 records" do
      sessions = 10.times.map do |i|
        UuidSession.create!(
          token: "token#{i}",
          user_id: i.to_i64,
          created_at: Time.utc,
          updated_at: Time.utc
        )
      end.to_a

      ids = sessions.map(&.id!)
      ids.uniq.size.should eq(10)
    end
  end
end
