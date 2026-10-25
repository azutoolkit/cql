require "./spec_helper"

FindStatementDB = CQL::Schema.define(:find_statement_db, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("find_statement.db")) do
  table :fs_items do
    primary :id, Int64, auto_increment: true
    text :name
    integer :tenant_id
    timestamp :deleted_at, null: true
    text :note, null: true
  end
end

class FsItem
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: FindStatementDB, table: :fs_items

  property name : String = ""
  property tenant_id : Int32 = 0
  property deleted_at : Time? = nil
end

class FsSoftItem
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::SoftDeletable
  db_context schema: FindStatementDB, table: :fs_items

  property name : String = ""
  property tenant_id : Int32 = 0
end

# A per-call scope: the find statement must be rendered for every call, not cached.
class FsTenantItem
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: FindStatementDB, table: :fs_items

  class_property current_tenant = 1

  property name : String = ""
  property tenant_id : Int32 = 0
  property deleted_at : Time? = nil

  def self.query
    previous_def.where(tenant_id: current_tenant)
  end
end

class FsSubItem < FsItem
end

class FsTenantSubItem < FsItem
  class_property current_tenant = 1

  def self.query
    super.where(tenant_id: current_tenant)
  end
end

describe "find with a reused statement" do
  before_each { FindStatementDB.fs_items.create! }
  after_each { FindStatementDB.fs_items.drop! }

  it "runs the same SQL as the query builder and binds each id" do
    first = FsItem.create!(name: "first", tenant_id: 1)
    second = FsItem.create!(name: "second", tenant_id: 1)
    expected = FsItem.query.where(id: first.id!).query.clone.limit(1).to_sql.first

    statements = count_queries do
      FsItem.find?(first.id!).try(&.name).should eq("first")
      FsItem.find?(second.id!).try(&.name).should eq("second")
      FsItem.find?(-1_i64).should be_nil
    end

    statements.should eq([expected, expected, expected])
    FsItem.find!(second.id!).name.should eq("second")
  end

  it "keeps the soft-delete scope" do
    item = FsSoftItem.create!(name: "gone", tenant_id: 1)
    FsSoftItem.find?(item.id!).should_not be_nil

    item.delete!

    FsSoftItem.find?(item.id!).should be_nil
    FsSoftItem.with_deleted.where(id: item.id!).first.should_not be_nil
  end

  it "renders the statement per call when the model overrides query" do
    item = FsItem.create!(name: "tenant one", tenant_id: 1)

    FsTenantItem.current_tenant = 1
    FsTenantItem.find?(item.id!).should_not be_nil
    FsTenantItem.current_tenant = 2
    FsTenantItem.find?(item.id!).should be_nil
  ensure
    FsTenantItem.current_tenant = 1
  end

  it "finds through a plain subclass of the model" do
    item = FsItem.create!(name: "parent row", tenant_id: 1)

    FsSubItem.find?(item.id!).try(&.name).should eq("parent row")
  end

  it "renders per call when a subclass overrides query" do
    item = FsItem.create!(name: "tenant one", tenant_id: 1)

    FsTenantSubItem.current_tenant = 1
    FsTenantSubItem.find?(item.id!).should_not be_nil
    FsTenantSubItem.current_tenant = 2
    FsTenantSubItem.find?(item.id!).should be_nil
  ensure
    FsTenantSubItem.current_tenant = 1
  end

  it "sees rows written in the surrounding transaction" do
    FindStatementDB.transaction do |tx|
      item = FsItem.create!(name: "uncommitted", tenant_id: 1)
      FsItem.find?(item.id!).try(&.name).should eq("uncommitted")
      tx.rollback
    end
  end

  it "still accepts an array of ids" do
    items = %w[a b].map { |name| FsItem.create!(name: name, tenant_id: 1) }

    FsItem.find(items.map(&.id!)).should_not be_nil
  end

  it "renders again after the table's columns change" do
    item = FsItem.create!(name: "before alter", tenant_id: 1)
    FsItem.find?(item.id!).should_not be_nil

    FindStatementDB.alter(:fs_items) { drop_column :note }

    FsItem.find?(item.id!).try(&.name).should eq("before alter")
  ensure
    FindStatementDB.alter(:fs_items) { add_column :note, String, null: true }
  end
end
