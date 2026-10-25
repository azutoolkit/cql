require "../spec_helper"

DependentDB = CQL::Schema.define(
  :dependent_on_delete,
  adapter: CQL::Adapter::SQLite,
  uri: spec_sqlite_uri("dependent_on_delete.db")
) do
  table :dep_owners do
    primary :id, Int64, auto_increment: true
    text :name
  end

  table :dep_keepers do
    primary :id, Int64, auto_increment: true
    text :name
  end

  table :dep_soft_owners do
    primary :id, Int64, auto_increment: true
    text :name
    column :deleted_at, Time, null: true
  end

  table :dep_children do
    primary :id, Int64, auto_increment: true
    text :name
    column :destroy_owner_id, Int64, null: true
    column :delete_owner_id, Int64, null: true
    column :nullify_owner_id, Int64, null: true
    column :keep_owner_id, Int64, null: true
    column :restrict_owner_id, Int64, null: true
    column :profile_owner_id, Int64, null: true
    column :uncached_owner_id, Int64, null: true
    column :soft_owner_id, Int64, null: true
  end

  table :dep_tags do
    primary :id, Int64, auto_increment: true
    text :name
  end

  table :dep_owner_tag do
    primary :id, Int64, auto_increment: true
    column :dep_owner_id, Int64
    column :dep_tag_id, Int64
  end

  table :dep_keeper_tag do
    primary :id, Int64, auto_increment: true
    column :dep_keeper_id, Int64
    column :dep_tag_id, Int64
  end
end

class DepChild
  include CQL::ActiveRecord::Model(Int64)
  db_context DependentDB, :dep_children

  DESTROYED_IDS = [] of Int64

  property name : String
  property destroy_owner_id : Int64?
  property delete_owner_id : Int64?
  property nullify_owner_id : Int64?
  property keep_owner_id : Int64?
  property restrict_owner_id : Int64?
  property profile_owner_id : Int64?
  property uncached_owner_id : Int64?
  property soft_owner_id : Int64?

  before_destroy :record_destroy

  def initialize(@name, @destroy_owner_id = nil, @delete_owner_id = nil, @nullify_owner_id = nil,
                 @keep_owner_id = nil, @restrict_owner_id = nil, @profile_owner_id = nil, @soft_owner_id = nil,
                 @uncached_owner_id = nil)
  end

  def record_destroy
    DESTROYED_IDS << id!
    true
  end
end

class DepTag
  include CQL::ActiveRecord::Model(Int64)
  db_context DependentDB, :dep_tags

  property name : String

  def initialize(@name)
  end
end

class DepOwnerTag
  include CQL::ActiveRecord::Model(Int64)
  db_context DependentDB, :dep_owner_tag

  property dep_owner_id : Int64
  property dep_tag_id : Int64

  def initialize(@dep_owner_id, @dep_tag_id)
  end
end

class DepKeeperTag
  include CQL::ActiveRecord::Model(Int64)
  db_context DependentDB, :dep_keeper_tag

  property dep_keeper_id : Int64
  property dep_tag_id : Int64

  def initialize(@dep_keeper_id, @dep_tag_id)
  end
end

class DepOwner
  include CQL::ActiveRecord::Model(Int64)
  db_context DependentDB, :dep_owners

  property name : String
  @[DB::Field(ignore: true)]
  property halt_destroy : Bool = false

  before_destroy :check_halt_destroy

  has_many :destroyed_children, DepChild, foreign_key: :destroy_owner_id, dependent: :destroy
  has_many :deleted_children, DepChild, foreign_key: :delete_owner_id, dependent: :delete_all
  has_many :nullified_children, DepChild, foreign_key: :nullify_owner_id, dependent: :nullify
  has_many :kept_children, DepChild, foreign_key: :keep_owner_id
  has_one :profile, DepChild, foreign_key: :profile_owner_id, dependent: :destroy
  has_one :uncached_profile, DepChild, foreign_key: :uncached_owner_id, dependent: :destroy, cache: false
  many_to_many :dep_tags, DepTag, join_through: DepOwnerTag,
    foreign_key: :dep_owner_id, association_foreign_key: :dep_tag_id, dependent: :destroy
  has_many :restricting_children, DepChild, foreign_key: :restrict_owner_id, dependent: :restrict_with_error

  def initialize(@name)
  end

  def check_halt_destroy
    !halt_destroy
  end
end

class DepKeeper
  include CQL::ActiveRecord::Model(Int64)
  db_context DependentDB, :dep_keepers

  property name : String

  many_to_many :dep_tags, DepTag, join_through: DepKeeperTag,
    foreign_key: :dep_keeper_id, association_foreign_key: :dep_tag_id, dependent: :nullify

  def initialize(@name)
  end
end

class DepSoftOwner
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::SoftDeletable
  db_context DependentDB, :dep_soft_owners

  property name : String

  has_many :children, DepChild, foreign_key: :soft_owner_id, dependent: :destroy

  def initialize(@name)
  end
end

private def create_dep_owner : DepOwner
  DepOwner.new("owner").tap(&.create!)
end

private def create_dep_child(**fks) : DepChild
  DepChild.new("child", **fks).tap(&.create!)
end

describe "dependent: on parent delete!" do
  before_each do
    DependentDB.dep_keeper_tag.drop! rescue nil
    DependentDB.dep_owner_tag.drop! rescue nil
    DependentDB.dep_tags.drop! rescue nil
    DependentDB.dep_children.drop! rescue nil
    DependentDB.dep_soft_owners.drop! rescue nil
    DependentDB.dep_keepers.drop! rescue nil
    DependentDB.dep_owners.drop! rescue nil
    DependentDB.dep_owners.create!
    DependentDB.dep_keepers.create!
    DependentDB.dep_soft_owners.create!
    DependentDB.dep_children.create!
    DependentDB.dep_tags.create!
    DependentDB.dep_owner_tag.create!
    DependentDB.dep_keeper_tag.create!
    DepChild::DESTROYED_IDS.clear
  end

  it "registers each declared dependent once, restricting handlers first" do
    DepOwner::DESTROY_DEPENDENTS.should eq([
      :handle_restricting_children_dependency,
      :handle_destroyed_children_dependency,
      :handle_deleted_children_dependency,
      :handle_nullified_children_dependency,
      :handle_profile_dependency,
      :handle_uncached_profile_dependency,
      :handle_dep_tags_dependency,
    ])
  end

  it "destroys has_many children with dependent: :destroy, running each child's callbacks once" do
    owner = create_dep_owner
    first = create_dep_child(destroy_owner_id: owner.id!)
    second = create_dep_child(destroy_owner_id: owner.id!)

    owner.delete!.should be_true

    DepChild.find?(first.id!).should be_nil
    DepChild.find?(second.id!).should be_nil
    DepChild::DESTROYED_IDS.sort.should eq([first.id!, second.id!].sort)
  end

  it "destroys children added after the association was loaded" do
    owner = create_dep_owner
    loaded = create_dep_child(destroy_owner_id: owner.id!)
    owner.destroyed_children.size.should eq(1)
    added_later = create_dep_child(destroy_owner_id: owner.id!)

    owner.delete!.should be_true

    DepChild.find?(loaded.id!).should be_nil
    DepChild.find?(added_later.id!).should be_nil
  end

  it "leaves dependents untouched when a before_destroy callback halts the delete" do
    owner = create_dep_owner
    child = create_dep_child(destroy_owner_id: owner.id!)
    owner.halt_destroy = true

    owner.delete!.should be_false

    DepOwner.find?(owner.id!).should_not be_nil
    DepChild.find?(child.id!).should_not be_nil
  end

  it "deletes has_many children with dependent: :delete_all without their callbacks" do
    owner = create_dep_owner
    child = create_dep_child(delete_owner_id: owner.id!)

    owner.delete!.should be_true

    DepChild.find?(child.id!).should be_nil
    DepChild::DESTROYED_IDS.should be_empty
  end

  it "nullifies has_many children with dependent: :nullify" do
    owner = create_dep_owner
    child = create_dep_child(nullify_owner_id: owner.id!)

    owner.delete!.should be_true

    DepChild.find!(child.id!).nullify_owner_id.should be_nil
  end

  it "leaves children of an association without dependent: untouched" do
    owner = create_dep_owner
    owner_id = owner.id!
    child = create_dep_child(keep_owner_id: owner_id)

    owner.delete!.should be_true

    DepChild.find!(child.id!).keep_owner_id.should eq(owner_id)
  end

  it "destroys the has_one record with dependent: :destroy" do
    owner = create_dep_owner
    profile = create_dep_child(profile_owner_id: owner.id!)

    owner.delete!.should be_true

    DepChild.find?(profile.id!).should be_nil
    DepChild::DESTROYED_IDS.should eq([profile.id!])
  end

  it "destroys the has_one record of an uncached association" do
    owner = create_dep_owner
    profile = create_dep_child(uncached_owner_id: owner.id!)

    owner.delete!.should be_true

    DepChild.find?(profile.id!).should be_nil
  end

  it "removes only the join rows of a many_to_many with dependent: :nullify" do
    keeper = DepKeeper.new("keeper").tap(&.create!)
    tag = DepTag.new("crystal").tap(&.create!)
    DepKeeperTag.new(keeper.id!, tag.id!).create!

    keeper.delete!.should be_true

    DepTag.find?(tag.id!).should_not be_nil
    DepKeeperTag.count.should eq(0)
  end

  it "destroys a many_to_many target with dependent: :destroy even when another parent links to it" do
    owner = create_dep_owner
    keeper = DepKeeper.new("keeper").tap(&.create!)
    tag = DepTag.new("shared").tap(&.create!)
    DepOwnerTag.new(owner.id!, tag.id!).create!
    DepKeeperTag.new(keeper.id!, tag.id!).create!

    owner.delete!.should be_true

    DepTag.find?(tag.id!).should be_nil
    DepKeeperTag.count.should eq(1)
  end

  it "destroys many_to_many join rows and targets with dependent: :destroy" do
    owner = create_dep_owner
    tag = DepTag.new("crystal").tap(&.create!)
    DepOwnerTag.new(owner.id!, tag.id!).create!

    owner.delete!.should be_true

    DepTag.find?(tag.id!).should be_nil
    DepOwnerTag.count.should eq(0)
  end

  it "raises with dependent: :restrict_with_error before any other dependent runs" do
    owner = create_dep_owner
    destroyable = create_dep_child(destroy_owner_id: owner.id!)
    create_dep_child(restrict_owner_id: owner.id!)

    expect_raises(CQL::ActiveRecord::Relations::BaseRelation::RelationError, /restricting_children/) do
      owner.delete!
    end

    DepOwner.find?(owner.id!).should_not be_nil
    DepChild.find?(destroyable.id!).should_not be_nil
  end

  it "leaves dependents alone on a soft delete and destroys them on force_delete!" do
    owner = DepSoftOwner.new("soft").tap(&.create!)
    child = create_dep_child(soft_owner_id: owner.id!)

    owner.delete!.should be_true
    DepChild.find?(child.id!).should_not be_nil

    owner.force_delete!.should be_true
    DepChild.find?(child.id!).should be_nil
  end
end
