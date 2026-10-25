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

  table :uuid_session_events do
    primary :id, Int64, auto_increment: true
    text :session_id, null: true
  end

  table :uuid_tags do
    primary :id, Int64, auto_increment: true
    text :name
  end

  table :uuid_session_tags do
    primary :id, Int64, auto_increment: true
    text :session_id
    bigint :uuid_tag_id
  end
end

# belongs_to a UUID-keyed model, so its generated preload must bind UUIDs as strings.
class UuidSessionEvent
  include CQL::ActiveRecord::Model(Int64)

  db_context schema: UuidTestDB, table: :uuid_session_events

  property session_id : UUID?

  belongs_to :session, UuidSession, :session_id
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

# An event read back with its UUID foreign key, which SQLite stores as TEXT. Models cannot write a
# UUID column other than the primary key yet, so the specs insert these rows directly.
class UuidSessionNote
  include CQL::ActiveRecord::Model(Int64)

  db_context schema: UuidTestDB, table: :uuid_session_events

  @[DB::Field(converter: CQL::UUIDConverter)]
  property session_id : UUID
end

# UUID-keyed owners of the `uuid_sessions` rows, one per `dependent:` strategy; create the rows
# with UuidSession and load them through these models.
class NoteDestroyingSession
  include CQL::ActiveRecord::Model(UUID)

  db_context schema: UuidTestDB, table: :uuid_sessions

  property token : String = ""

  has_many :notes, UuidSessionNote, foreign_key: :session_id, dependent: :destroy
end

class NoteDeletingSession
  include CQL::ActiveRecord::Model(UUID)

  db_context schema: UuidTestDB, table: :uuid_sessions

  property token : String = ""

  has_many :notes, UuidSessionNote, foreign_key: :session_id, dependent: :delete_all
end

class UuidTag
  include CQL::ActiveRecord::Model(Int64)

  db_context schema: UuidTestDB, table: :uuid_tags

  property name : String = ""
end

class UuidSessionTag
  include CQL::ActiveRecord::Model(Int64)

  db_context schema: UuidTestDB, table: :uuid_session_tags
end

# UUID-keyed owners of tags through `uuid_session_tags`: the default strategy and :destroy.
class TaggedSession
  include CQL::ActiveRecord::Model(UUID)

  db_context schema: UuidTestDB, table: :uuid_sessions

  property token : String = ""

  many_to_many :tags, UuidTag, join_through: UuidSessionTag, foreign_key: :session_id, association_foreign_key: :uuid_tag_id
end

class TagDestroyingSession
  include CQL::ActiveRecord::Model(UUID)

  db_context schema: UuidTestDB, table: :uuid_sessions

  property token : String = ""

  many_to_many :tags, UuidTag, join_through: UuidSessionTag, foreign_key: :session_id,
    association_foreign_key: :uuid_tag_id, dependent: :destroy
end

def uuid_session_with_tag : {UuidSession, UuidTag}
  session = UuidSession.create!(token: "tagged", user_id: 1_i64, created_at: Time.utc, updated_at: Time.utc)
  tag = UuidTag.create!(name: "crystal")
  UuidTestDB.insert.into(:uuid_session_tags).values(session_id: session.id!.to_s, uuid_tag_id: tag.id!).commit
  {session, tag}
end

class NoteNullifyingSession
  include CQL::ActiveRecord::Model(UUID)

  db_context schema: UuidTestDB, table: :uuid_sessions

  property token : String = ""

  has_many :notes, UuidSessionNote, foreign_key: :session_id, dependent: :nullify
end

class NoteRestrictedSession
  include CQL::ActiveRecord::Model(UUID)

  db_context schema: UuidTestDB, table: :uuid_sessions

  property token : String = ""

  has_many :notes, UuidSessionNote, foreign_key: :session_id, dependent: :restrict_with_error
end

class NoteOwningSession
  include CQL::ActiveRecord::Model(UUID)

  db_context schema: UuidTestDB, table: :uuid_sessions

  property token : String = ""

  has_one :note, UuidSessionNote, foreign_key: :session_id, dependent: :destroy
end

def uuid_session_with_note : {UuidSession, Int64}
  session = UuidSession.create!(token: "owner", user_id: 1_i64, created_at: Time.utc, updated_at: Time.utc)
  inserted = UuidTestDB.insert.into(:uuid_session_events).values(session_id: session.id!.to_s).commit
  {session, inserted.last_insert_id}
end

def uuid_session_note_count(session : UuidSession)
  UuidSessionEvent.where(session_id: session.id!.to_s).count
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

  describe "typed query DSL" do
    it "filters on the UUID primary key" do
      session = UuidSession.create!(token: "typed", user_id: 1_i64, created_at: Time.utc, updated_at: Time.utc)
      uuid = session.id.not_nil!

      UuidSession.query.where { id == uuid }.to_a.map(&.token).should eq(["typed"])
    end
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

  describe "query delete_all" do
    it "deletes the matching UUID rows in bulk" do
      gone = UuidSession.create!(token: "gone", user_id: 1_i64, created_at: Time.utc, updated_at: Time.utc)
      kept = UuidSession.create!(token: "kept", user_id: 2_i64, created_at: Time.utc, updated_at: Time.utc)

      UuidSession.where(token: "gone").delete_all.should eq(1)

      UuidSession.find(gone.id!).should be_nil
      UuidSession.find!(kept.id!).token.should eq("kept")
    end
  end

  describe "belongs_to preload" do
    it "compiles for a UUID-keyed target" do
      typeof(UuidSessionEvent.preload(:session).all).should eq(Array(UuidSessionEvent))
    end
  end

  describe ".insert_all" do
    it "generates a UUID for each row without an id" do
      UuidSession.insert_all([{token: "bulk a", user_id: 1_i64}, {token: "bulk b", user_id: 2_i64}]).should eq(2)

      ids = UuidSession.all.map(&.id.not_nil!)
      ids.size.should eq(2)
      ids.uniq.size.should eq(2)
    end

    it "generates a UUID for a nil id and keeps a given one" do
      given = UUID.random
      rows = [
        {:id => nil.as(DB::Any), :token => "nil id".as(DB::Any), :user_id => 1_i64.as(DB::Any)},
        {:id => given.to_s.as(DB::Any), :token => "given id".as(DB::Any), :user_id => 2_i64.as(DB::Any)},
      ]

      UuidSession.insert_all(rows).should eq(2)

      UuidSession.find_by!(token: "given id").id.should eq(given)
      UuidSession.find_by!(token: "nil id").id.should_not be_nil
    end

    it "rejects upsert_all on: :id when ids are generated, since they never match" do
      expect_raises(ArgumentError, /never matches a generated id/) do
        UuidSession.upsert_all([{token: "t", user_id: 1_i64}], on_conflict: :id)
      end
    end
  end

  describe "dependent strategies on a UUID-keyed parent" do
    before_each do
      UuidTestDB.uuid_session_events.drop! rescue nil
      UuidTestDB.uuid_tags.drop! rescue nil
      UuidTestDB.uuid_session_tags.drop! rescue nil
      UuidTestDB.uuid_session_events.create!
      UuidTestDB.uuid_tags.create!
      UuidTestDB.uuid_session_tags.create!
    end

    after_each do
      UuidTestDB.uuid_session_tags.drop!
      UuidTestDB.uuid_tags.drop!
      UuidTestDB.uuid_session_events.drop!
    end

    it "destroys the has_many records with dependent: :destroy" do
      session, note_id = uuid_session_with_note
      owner = NoteDestroyingSession.find!(session.id!)
      owner.notes_count.should eq(1)

      owner.delete!.should be_true

      UuidSessionNote.find?(note_id).should be_nil
    end

    it "deletes the has_many rows with dependent: :delete_all" do
      session, note_id = uuid_session_with_note

      NoteDeletingSession.find!(session.id!).delete!.should be_true

      UuidSessionEvent.where(id: note_id).count.should eq(0)
    end

    it "removes the many_to_many join rows and keeps the tags by default" do
      session, tag = uuid_session_with_tag

      TaggedSession.find!(session.id!).delete!.should be_true

      UuidSessionTag.count.should eq(0)
      UuidTag.find?(tag.id!).should_not be_nil
    end

    it "destroys the many_to_many tags with dependent: :destroy" do
      session, tag = uuid_session_with_tag

      TagDestroyingSession.find!(session.id!).delete!.should be_true

      UuidSessionTag.count.should eq(0)
      UuidTag.find?(tag.id!).should be_nil
    end

    it "clears the foreign key with dependent: :nullify" do
      session, note_id = uuid_session_with_note

      NoteNullifyingSession.find!(session.id!).delete!.should be_true

      uuid_session_note_count(session).should eq(0)
      UuidSessionEvent.where(id: note_id).count.should eq(1)
    end

    it "raises and deletes nothing with dependent: :restrict_with_error" do
      session, _note_id = uuid_session_with_note

      expect_raises(CQL::ActiveRecord::Relations::BaseRelation::RelationError) do
        NoteRestrictedSession.find!(session.id!).delete!
      end

      UuidSession.find!(session.id!).token.should eq("owner")
      uuid_session_note_count(session).should eq(1)
    end

    it "destroys the has_one record with dependent: :destroy" do
      session, note_id = uuid_session_with_note

      NoteOwningSession.find!(session.id!).delete!.should be_true

      UuidSessionNote.find?(note_id).should be_nil
      UuidSession.find(session.id!).should be_nil
    end
  end

  describe "multiple record creation" do
    it "generates unique UUIDs for 10 records" do
      sessions = Array.new(10) do |i|
        UuidSession.create!(
          token: "token#{i}",
          user_id: i.to_i64,
          created_at: Time.utc,
          updated_at: Time.utc
        )
      end

      ids = sessions.map(&.id!)
      ids.uniq.size.should eq(10)
    end
  end
end
