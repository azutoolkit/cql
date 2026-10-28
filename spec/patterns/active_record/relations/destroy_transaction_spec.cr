require "../spec_helper"

DESTROY_TX_DB = CQL::Schema.define(:destroy_tx_spec, adapter: CQL::Adapter::SQLite, uri: "sqlite3::memory:") do
  table :tx_shelves do
    primary :id, Int32, auto_increment: true
    text :name
  end

  table :tx_volumes do
    primary :id, Int32, auto_increment: true
    integer :tx_shelf_id, null: true
    text :title
    lock_version :version
  end

  table :tx_shelf_volumes do
    primary :id, Int32, auto_increment: true
    integer :tx_shelf_id
    integer :tx_volume_id
  end
end

class TxVolume
  include CQL::ActiveRecord::Model(Int32)
  include CQL::ActiveRecord::OptimisticLocking
  db_context DESTROY_TX_DB, :tx_volumes

  property tx_shelf_id : Int32?
  property title : String = ""
  property version : Int32 = 1

  def initialize(@title = "", @tx_shelf_id = nil)
  end

  optimistic_locking version_column: :version
end

class TxShelfVolume
  include CQL::ActiveRecord::Model(Int32)
  db_context DESTROY_TX_DB, :tx_shelf_volumes

  property tx_shelf_id : Int32?
  property tx_volume_id : Int32?

  def initialize(@tx_shelf_id = nil, @tx_volume_id = nil)
  end
end

class TxShelf
  include CQL::ActiveRecord::Model(Int32)
  db_context DESTROY_TX_DB, :tx_shelves

  property name : String = ""

  has_many :held_volumes, TxVolume, foreign_key: :tx_shelf_id, dependent: :destroy
  many_to_many :linked_volumes, TxVolume, join_through: TxShelfVolume, foreign_key: :tx_shelf_id,
    association_foreign_key: :tx_volume_id, dependent: :destroy
  many_to_many :wiped_volumes, TxVolume, join_through: TxShelfVolume, foreign_key: :tx_shelf_id,
    association_foreign_key: :tx_volume_id, dependent: :delete_all

  def initialize(@name = "")
  end
end

SPLIT_TX_FILE    = File.tempname("cql_split_tx", ".db")
Spec.after_suite { File.delete?(SPLIT_TX_FILE) } # the schemas create it when the spec program loads
SPLIT_TARGETS_DB = CQL::Schema.define(:split_tx_targets, adapter: CQL::Adapter::SQLite, uri: "sqlite3://#{SPLIT_TX_FILE}") do
  table :split_volumes do
    primary :id, Int32, auto_increment: true
    text :name
  end
end
SPLIT_LINKS_DB = CQL::Schema.define(:split_tx_links, adapter: CQL::Adapter::SQLite, uri: "sqlite3://#{SPLIT_TX_FILE}") do
  table :split_shelves do
    primary :id, Int32, auto_increment: true
    text :name
  end
  table :split_links do
    primary :id, Int32, auto_increment: true
    integer :split_shelf_id
    integer :split_volume_id
  end
end

class SplitVolume
  include CQL::ActiveRecord::Model(Int32)
  db_context SPLIT_TARGETS_DB, :split_volumes

  property name : String = ""

  def initialize
  end
end

class SplitLink
  include CQL::ActiveRecord::Model(Int32)
  db_context SPLIT_LINKS_DB, :split_links

  property split_shelf_id : Int32?
  property split_volume_id : Int32?

  def initialize(@split_shelf_id = nil, @split_volume_id = nil)
  end
end

class SplitShelf
  include CQL::ActiveRecord::Model(Int32)
  db_context SPLIT_LINKS_DB, :split_shelves

  property name : String = ""

  many_to_many :volumes, SplitVolume, join_through: SplitLink, foreign_key: :split_shelf_id,
    association_foreign_key: :split_volume_id, dependent: :destroy

  def initialize
  end
end

# A shelf with two volumes, linked through the join table too; the last one goes stale once loaded.
private def shelf_with_stale_last_volume(& : TxShelf, TxVolume -> Nil) : Nil
  shelf = TxShelf.new("Shelf").tap(&.save!)
  volumes = {TxVolume.new("One", shelf.id), TxVolume.new("Two", shelf.id)}.map(&.tap(&.save!))
  volumes.each { |volume| TxShelfVolume.new(shelf.id, volume.id).save! }
  yield shelf, volumes.last
end

describe "Association destroy paths" do
  before_each do
    DESTROY_TX_DB.build
    {"tx_shelf_volumes", "tx_volumes", "tx_shelves"}.each { |table| DESTROY_TX_DB.exec("DELETE FROM #{table}") }
  end

  it "rolls back has_many clear with dependent: :destroy when a target's delete! raises" do
    shelf_with_stale_last_volume do |shelf, stale|
      volumes = shelf.held_volumes.tap(&.all)
      TxVolume.update!(stale.id!, version: 2)
      expect_raises(CQL::OptimisticLockError) { volumes.clear }
    end
    TxVolume.count.should eq 2
  end

  it "rolls back many_to_many clear with dependent: :destroy, join rows included, and loads them again for a retry" do
    shelf_with_stale_last_volume do |shelf, stale|
      links = shelf.linked_volumes.tap(&.all)
      TxVolume.update!(stale.id!, version: 2)
      expect_raises(CQL::OptimisticLockError) { links.clear }
      {TxShelfVolume.count, TxVolume.count, links.size}.should eq({2, 2, 2})
      links.clear
    end
    {TxShelfVolume.count, TxVolume.count}.should eq({0, 0})
  end

  it "keeps the join row when many_to_many delete with dependent: :destroy cannot delete its target" do
    shelf_with_stale_last_volume do |shelf, stale|
      links = shelf.linked_volumes.tap(&.all)
      TxVolume.update!(stale.id!, version: 2)
      expect_raises(CQL::OptimisticLockError) { links.delete(stale.id!) }
    end
    {TxShelfVolume.count, TxVolume.count}.should eq({2, 2})
  end

  it "loads the collection again when an enclosing transaction rolls back a clear that succeeded" do
    shelf_with_stale_last_volume do |shelf, _|
      links = shelf.linked_volumes.tap(&.all)
      DESTROY_TX_DB.transaction { links.clear; raise DB::Rollback.new }
      {TxShelfVolume.count, TxVolume.count, links.size}.should eq({2, 2, 2})
    end
  end

  it "keeps the join rows when many_to_many delete or clear with dependent: :delete_all cannot delete the targets" do
    DESTROY_TX_DB.exec("CREATE TRIGGER keep_volumes BEFORE DELETE ON tx_volumes BEGIN SELECT RAISE(ABORT, 'kept'); END")
    shelf_with_stale_last_volume do |shelf, volume|
      expect_raises(SQLite3::Exception, "kept") { shelf.wiped_volumes.delete(volume.id!) }
      expect_raises(SQLite3::Exception, "kept") { shelf.wiped_volumes.clear }
    end
    {TxShelfVolume.count, TxVolume.count}.should eq({2, 2})
  ensure
    DESTROY_TX_DB.exec("DROP TRIGGER IF EXISTS keep_volumes")
  end

  it "destroys through a join model on another schema of the same SQLite file" do
    {SPLIT_TARGETS_DB, SPLIT_LINKS_DB}.each(&.build)
    shelf = SplitShelf.new.tap(&.save!)
    volumes = Array.new(3) { SplitVolume.new.tap(&.save!) }
    volumes.each { |volume| SplitLink.new(shelf.id, volume.id).save! }
    shelf.volumes.delete(volumes.first.id!)
    shelf.volumes.clear
    {SplitLink.count, SplitVolume.count}.should eq({0, 0})
  end
end
