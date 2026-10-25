require "../spec_helper"

HasManyDefaultFkDB = CQL::Schema.define(:has_many_default_fk_db, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("has_many_default_fk.db")) do
  table :hm_default_owners do
    primary :id, Int64, auto_increment: true
    text :name
  end

  table :hm_default_kids do
    primary :id, Int64, auto_increment: true
    text :name
    bigint :hm_default_owner_id, null: true
  end
end

class HmDefaultKid
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: HasManyDefaultFkDB, table: :hm_default_kids

  property name : String = ""
  property hm_default_owner_id : Int64? = nil

  def initialize(@name : String = "", @hm_default_owner_id : Int64? = nil)
  end
end

# Declares has_many without foreign_key:, so the key defaults to hm_default_owner_id.
class HmDefaultOwner
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: HasManyDefaultFkDB, table: :hm_default_owners

  property name : String = ""

  has_many :kids, HmDefaultKid
end

describe "has_many without foreign_key:" do
  before_each do
    HasManyDefaultFkDB.hm_default_owners.create!
    HasManyDefaultFkDB.hm_default_kids.create!
  end

  after_each do
    HasManyDefaultFkDB.hm_default_kids.drop!
    HasManyDefaultFkDB.hm_default_owners.drop!
  end

  it "registers the owner name plus _id as the foreign key" do
    CQL::ActiveRecord::AssociationRegistry::HmDefaultOwner__has_many__kids::FOREIGN_KEY.should eq(:hm_default_owner_id)
  end

  it "reads only the owner's records" do
    owner = HmDefaultOwner.create!(name: "Ann")
    other = HmDefaultOwner.create!(name: "Bob")
    HmDefaultKid.create!(name: "Kim", hm_default_owner_id: owner.id!)
    HmDefaultKid.create!(name: "Lee", hm_default_owner_id: other.id!)

    owner.kids.all.map(&.name).should eq(["Kim"])
  end

  it "counts the owner's records" do
    owner = HmDefaultOwner.create!(name: "Ann")
    HmDefaultKid.create!(name: "Kim", hm_default_owner_id: owner.id!)
    HmDefaultKid.create!(name: "Lee", hm_default_owner_id: owner.id!)
    HmDefaultKid.create!(name: "Max")

    owner.kids_count.should eq(2)
  end

  it "sets the foreign key on created records" do
    owner = HmDefaultOwner.create!(name: "Ann")

    created = owner.create_kids([HmDefaultKid.new(name: "Kim")])
    added = owner.kids.create(name: "Lee")

    created.first.hm_default_owner_id.should eq(owner.id)
    added.hm_default_owner_id.should eq(owner.id)
    owner.kids_count.should eq(2)
  end

  it "sets the foreign key on bulk-inserted rows" do
    owner = HmDefaultOwner.create!(name: "Ann")

    owner.insert_kids_all([{name: "Kim"}, {name: "Lee"}]).should eq(2)

    HmDefaultKid.where(hm_default_owner_id: owner.id!).count.should eq(2)
  end

  it "preloads each owner's records" do
    ann = HmDefaultOwner.create!(name: "Ann")
    bob = HmDefaultOwner.create!(name: "Bob")
    HmDefaultKid.create!(name: "Kim", hm_default_owner_id: ann.id!)
    HmDefaultKid.create!(name: "Lee", hm_default_owner_id: bob.id!)

    owners = HmDefaultOwner.preload(:kids).order(:id).all

    owners.all?(&.kids_loaded?).should be_true
    owners.map { |owner| owner.kids.all.map(&.name) }.should eq([["Kim"], ["Lee"]])
  end
end
