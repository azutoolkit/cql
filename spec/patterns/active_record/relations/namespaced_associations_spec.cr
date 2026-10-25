require "../spec_helper"

NamespacedFkDB = CQL::Schema.define(:namespaced_fk_db, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("namespaced_fk.db")) do
  table :nsfk_owners do
    primary :id, Int64, auto_increment: true
    text :name
  end

  table :nsfk_pets do
    primary :id, Int64, auto_increment: true
    text :name
    bigint :owner_id, null: true
  end

  table :nsfk_badges do
    primary :id, Int64, auto_increment: true
    text :label
    bigint :owner_id, null: true
  end

  table :nsfk_tags do
    primary :id, Int64, auto_increment: true
    text :name
  end

  table :nsfk_owner_tags do
    primary :id, Int64, auto_increment: true
    bigint :owner_id
    bigint :tag_id
  end
end

# Owner comes first, so its relative targets are forward references. The many_to_many target is
# qualified to exercise the default target key of a namespaced target.
module NamespacedFk
  class Owner
    include CQL::ActiveRecord::Model(Int64)
    db_context schema: NamespacedFkDB, table: :nsfk_owners

    property name : String = ""

    has_many :pets, Pet
    has_one :badge, Badge
    many_to_many :tags, NamespacedFk::Tag, join_through: OwnerTag
  end

  class Pet
    include CQL::ActiveRecord::Model(Int64)
    db_context schema: NamespacedFkDB, table: :nsfk_pets

    property name : String = ""
    property owner_id : Int64?

    belongs_to :owner, Owner, foreign_key: :owner_id

    def initialize(@name = "", @owner_id = nil); end
  end

  class Badge
    include CQL::ActiveRecord::Model(Int64)
    db_context schema: NamespacedFkDB, table: :nsfk_badges

    property label : String = ""
    property owner_id : Int64?

    def initialize(@label = "", @owner_id = nil); end
  end

  class Tag
    include CQL::ActiveRecord::Model(Int64)
    db_context schema: NamespacedFkDB, table: :nsfk_tags

    property name : String = ""
  end

  class OwnerTag
    include CQL::ActiveRecord::Model(Int64)
    db_context schema: NamespacedFkDB, table: :nsfk_owner_tags

    property owner_id : Int64?
    property tag_id : Int64?
  end
end

# A top-level target named like a CQL type (CQL::PoolStats), defined after its owner.
class PoolStatsOwner
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: NamespacedFkDB, table: :nsfk_owners

  property name : String = ""

  has_many :pool_stats, PoolStats, foreign_key: :owner_id
end

class PoolStats
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: NamespacedFkDB, table: :nsfk_pets

  property name : String = ""
  property owner_id : Int64?

  def initialize(@name = "", @owner_id = nil); end
end

describe "associations of namespaced models" do
  before_each do
    NamespacedFkDB.nsfk_owners.create!
    NamespacedFkDB.nsfk_pets.create!
    NamespacedFkDB.nsfk_badges.create!
    NamespacedFkDB.nsfk_tags.create!
    NamespacedFkDB.nsfk_owner_tags.create!
  end

  after_each do
    NamespacedFkDB.nsfk_owner_tags.drop!
    NamespacedFkDB.nsfk_tags.drop!
    NamespacedFkDB.nsfk_badges.drop!
    NamespacedFkDB.nsfk_pets.drop!
    NamespacedFkDB.nsfk_owners.drop!
  end

  it "registers the demodulized owner name plus _id as the default foreign key" do
    CQL::ActiveRecord::AssociationRegistry::NamespacedFk__Owner__has_many__pets::FOREIGN_KEY.should eq(:owner_id)
    CQL::ActiveRecord::AssociationRegistry::NamespacedFk__Owner__has_one__badge::FOREIGN_KEY.should eq(:owner_id)
  end

  it "links has_many children through owner_id" do
    owner = NamespacedFk::Owner.create!(name: "Ada")
    pet = owner.pets.create(name: "Rex")

    pet.owner_id.should eq(owner.id)
    owner.pets.all.map(&.name).should eq(["Rex"])
    owner.pets_count.should eq(1)
  end

  it "preloads has_many children of a relative target" do
    owner = NamespacedFk::Owner.create!(name: "Ada")
    owner.pets.create(name: "Rex")

    NamespacedFk::Owner.preload(:pets).all.first.pets.all.map(&.name).should eq(["Rex"])
  end

  it "links the has_one record through owner_id" do
    owner = NamespacedFk::Owner.create!(name: "Ada")
    badge = owner.create_badge(label: "Gold")

    badge.owner_id.should eq(owner.id)
    owner.reload_badge.try(&.label).should eq("Gold")
  end

  it "reads a belongs_to parent of a relative target" do
    owner = NamespacedFk::Owner.create!(name: "Ada")
    pet = owner.pets.create(name: "Rex")

    pet.owner.try(&.name).should eq("Ada")
  end

  it "joins many_to_many targets through owner_id and the demodulized target name plus _id" do
    owner = NamespacedFk::Owner.create!(name: "Ada")
    tag = NamespacedFk::Tag.create!(name: "crystal")
    owner.tags << tag

    join_row = NamespacedFk::OwnerTag.all.first
    join_row.owner_id.should eq(owner.id)
    join_row.tag_id.should eq(tag.id)
    owner.tags.all.map(&.name).should eq(["crystal"])
  end

  it "resolves a relative target to the top-level model, not a CQL type of the same name" do
    owner = PoolStatsOwner.create!(name: "Ada")
    owner.pool_stats.create(name: "pool")

    owner.pool_stats.all.map(&.class).should eq([PoolStats])
  end
end
