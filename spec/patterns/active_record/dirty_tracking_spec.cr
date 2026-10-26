require "./spec_helper"

DirtyTrackingDB = CQL::Schema.define(:dirty_tracking_db, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("dirty_tracking.db")) do
  table :dt_people do
    primary :id, Int64, auto_increment: true
    text :name
    text :email
    integer :age
    text :note, null: true
    blob :avatar, null: true
    timestamps
  end

  table :dt_tokens do
    primary :id, String, auto_increment: false
    text :label
  end

  table :dt_soft_people do
    primary :id, Int64, auto_increment: true
    text :name
    timestamp :deleted_at, null: true
  end

  table :dt_locked_people do
    primary :id, Int32, auto_increment: true
    integer :age
    lock_version :version
    timestamp :updated_at, null: true
  end
end

class DtPerson
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::DirtyTracking
  db_context schema: DirtyTrackingDB, table: :dt_people

  property name : String = ""
  property email : String = ""
  property age : Int32 = 0
  property note : String? = nil
  property avatar : Bytes? = nil
  property created_at : Time? = nil
  property updated_at : Time? = nil

  def initialize
  end

  def rename_directly(name : String)
    @name = name
  end
end

class DtLockedPerson
  include CQL::ActiveRecord::Model(Int32)
  include CQL::ActiveRecord::OptimisticLocking
  include CQL::ActiveRecord::DirtyTracking
  db_context schema: DirtyTrackingDB, table: :dt_locked_people

  property age : Int32 = 0
  property version : Int32 = 1
  property updated_at : Time? = nil

  class_property before_save_age : Int32? = nil

  before_save :adjust_age

  optimistic_locking version_column: :version

  private def adjust_age
    DtLockedPerson.before_save_age.try { |age| @age = age }
    true
  end
end

# Callbacks that change the record after `save` has decided what to send.
class DtCallbackPerson
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::DirtyTracking
  db_context schema: DirtyTrackingDB, table: :dt_people

  property name : String = ""
  property email : String = ""
  property age : Int32 = 0
  property note : String? = nil
  property created_at : Time? = nil
  property updated_at : Time? = nil

  class_property after_save_note : String? = nil
  class_property before_save_email : String? = nil

  before_save :adjust_email
  after_save :leave_note

  def initialize
  end

  private def adjust_email
    DtCallbackPerson.before_save_email.try { |email| @email = email }
    true
  end

  private def leave_note
    DtCallbackPerson.after_save_note.try { |note| @note = note }
    true
  end
end

class DtToken
  include CQL::ActiveRecord::Model(UUID)
  include CQL::ActiveRecord::DirtyTracking
  db_context schema: DirtyTrackingDB, table: :dt_tokens

  property label : String = ""
end

class DtSoftPerson
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::SoftDeletable
  include CQL::ActiveRecord::DirtyTracking
  db_context schema: DirtyTrackingDB, table: :dt_soft_people

  property name : String = ""
end

private def updates(&) : Array(String)
  count_queries(:update) { yield }
end

describe CQL::ActiveRecord::DirtyTracking do
  before_each do
    {% for table in %w[dt_people dt_locked_people dt_tokens dt_soft_people] %}
      DirtyTrackingDB.{{table.id}}.create!
    {% end %}
  end

  after_each do
    {% for table in %w[dt_people dt_locked_people dt_tokens dt_soft_people] %}
      DirtyTrackingDB.{{table.id}}.drop!
    {% end %}
    DtCallbackPerson.after_save_note = nil
    DtCallbackPerson.before_save_email = nil
    DtLockedPerson.before_save_age = nil
  end

  it "starts clean when loaded and reports what changed since" do
    DtPerson.create!(name: "Ada", email: "ada@example.com", age: 36)
    person = DtPerson.find_by!(name: "Ada")

    person.changed?.should be_false
    person.changes.should be_empty

    person.name = "Ada Lovelace"
    person.rename_directly("Ada King")

    person.changed?.should be_true
    person.attribute_changed?(:name).should be_true
    person.attribute_changed?(:email).should be_false
    person.changes.should eq({:name => {"Ada".as(DB::Any), "Ada King".as(DB::Any)}})
  end

  it "updates only the changed columns" do
    person = DtPerson.create!(name: "Ada", email: "ada@example.com", age: 36)
    person.age = 37

    statements = updates { person.update!.should be_truthy }

    statements.size.should eq(1)
    statements.first.should contain("age = ?")
    statements.first.should_not contain("email")
    statements.first.should_not contain("name")
    person.changed?.should be_false
    DtPerson.find!(person.id!).age.should eq(37)
  end

  it "keeps a column another writer changed when this record did not change it" do
    person = DtPerson.create!(name: "Ada", email: "ada@example.com", age: 36)
    DtPerson.update!(person.id!, {:email => "ada@new.example".as(DB::Any)})

    person.update!(age: 37)

    DtPerson.find!(person.id!).email.should eq("ada@new.example")
  end

  it "sends no UPDATE and leaves updated_at alone when nothing changed" do
    person = DtPerson.create!(name: "Ada", email: "ada@example.com", age: 36)
    stamped = person.updated_at

    updates { person.save.should be_true }.should be_empty
    updates { person.update!.should be_truthy }.should be_empty
    person.updated_at.should eq(stamped)
  end

  it "saves a changed record with its updated_at refreshed" do
    person = DtPerson.create!(name: "Ada", email: "ada@example.com", age: 36)
    person.name = "Ada Lovelace"

    statements = updates { person.save.should be_true }

    statements.size.should eq(1)
    statements.first.should contain("name = ?")
    statements.first.should contain("updated_at = ?")
    person.changed?.should be_false
  end

  it "is clean after create, save of a new record and reload" do
    created = DtPerson.create!(name: "Ada", email: "ada@example.com", age: 36)
    created.changed?.should be_false

    fresh = DtPerson.new
    fresh.name = "Grace"
    fresh.changed?.should be_true
    fresh.save.should be_true
    fresh.changed?.should be_false

    fresh.name = "Grace Hopper"
    fresh.reload!
    fresh.changed?.should be_false
    fresh.name.should eq("Grace")
  end

  it "is clean after an optimistically locked update" do
    created = DtLockedPerson.create!(age: 36)
    person = DtLockedPerson.find!(created.id!)
    person.age = 37

    person.update!

    person.changed?.should be_false
    person.version.should eq(2)
    DtLockedPerson.find!(person.id!).age.should eq(37)
  end

  it "sends no UPDATE for an unchanged optimistically locked record" do
    person = DtLockedPerson.find!(DtLockedPerson.create!(age: 36).id!)

    updates { person.save.should be_true }.should be_empty
    person.version.should eq(1)
  end

  it "keeps what an after_save callback changes, on create and on update, for the next save" do
    DtCallbackPerson.after_save_note = "noted on create"
    person = DtCallbackPerson.new
    person.name = "Ada"
    person.save.should be_true

    person.attribute_changed?(:note).should be_true
    DtCallbackPerson.after_save_note = "noted on update"
    person.save.should be_true
    person.attribute_changed?(:note).should be_true
    DtCallbackPerson.after_save_note = nil
    person.save.should be_true

    DtCallbackPerson.find!(person.id!).note.should eq("noted on update")
  end

  it "stamps updated_at when a before_save callback changes an otherwise unchanged record" do
    person = DtCallbackPerson.new
    person.name = "Ada"
    person.save.should be_true
    person = DtCallbackPerson.find!(person.id!)
    stamped = person.updated_at

    sleep 1.millisecond
    DtCallbackPerson.before_save_email = "ada@example.com"
    statements = updates { person.save.should be_true }

    statements.first.should contain("updated_at = ?")
    DtCallbackPerson.find!(person.id!).email.should eq("ada@example.com")
    person.updated_at.should_not eq(stamped)
  end

  it "counts a byte slice changed in place" do
    person = DtPerson.create!(name: "Ada", email: "ada@example.com", age: 36, avatar: Bytes[1, 2, 3])
    person = DtPerson.find!(person.id!)

    person.avatar.not_nil![0] = 9_u8

    person.attribute_changed?(:avatar).should be_true
  end

  it "tracks records with a UUID primary key" do
    token = DtToken.create!(label: "first")
    token = DtToken.find!(token.id!)
    token.changed?.should be_false

    token.label = "second"
    token.changed_columns.should eq({:label => "second".as(DB::Any)})
    token.save.should be_true

    token.changed?.should be_false
    DtToken.find!(token.id!).label.should eq("second")
  end

  it "works together with soft deletes" do
    person = DtSoftPerson.create!(name: "Ada")
    person.name = "Ada Lovelace"

    updates { person.save.should be_true }.first.should_not contain("deleted_at")
    person.delete!.should be_true

    DtSoftPerson.find?(person.id!).should be_nil
    DtSoftPerson.with_deleted.find_by!(name: "Ada Lovelace").deleted_at.should_not be_nil
  end

  it "stamps updated_at on a locked update when a before_save callback changes an unchanged record" do
    person = DtLockedPerson.find!(DtLockedPerson.create!(age: 36).id!)
    person.updated_at.should be_nil

    DtLockedPerson.before_save_age = 40
    person.save.should be_true

    stored = DtLockedPerson.find!(person.id!)
    {stored.age, stored.version}.should eq({40, 2})
    stored.updated_at.should_not be_nil
  end

  it "does not stamp a plain update! after a save that had nothing to send" do
    person = DtPerson.create!(name: "Ada", email: "ada@example.com", age: 36)
    stamped = person.updated_at
    person.save.should be_true

    person.name = "Ada Lovelace"
    statements = updates { person.update! }

    statements.first.should_not contain("updated_at")
    person.updated_at.should eq(stamped)
  end
end
