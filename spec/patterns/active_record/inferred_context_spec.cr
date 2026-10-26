require "./spec_helper"

InferredContextDB = CQL::Schema.define(:inferred_context, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("inferred_context.db")) do
  table :inferred_gadgets do
    primary :id, Int64
    column :name, String
    column :inferred_category_id, Int64, null: true
  end

  table :inferred_categories do
    primary :id, Int64
    column :name, String
  end

  table :inferred_crates do
    primary :id, Int64
    column :name, String
  end

  table :inferred_twins do
    primary :id, Int64
    column :name, String
  end

  table :custom_widgets do
    primary :id, Int64
    column :name, String
  end
end

InferredMirrorDB = CQL::Schema.define(:inferred_mirror, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("inferred_mirror.db")) do
  table :inferred_twins do
    primary :id, Int64
    column :name, String
  end
end

module InferredShop
  ShopDB = CQL::Schema.define(:inferred_shop, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("inferred_shop.db")) do
    table :shop_orders do
      primary :id, Int64
      column :name, String
    end
  end
end

struct InferredGadget
  include CQL::ActiveRecord::Model(Int64)

  property id : Int64?
  property name : String
  property inferred_category_id : Int64?

  belongs_to :category, InferredCategory, :inferred_category_id

  def initialize(@name : String, @inferred_category_id : Int64? = nil); end
end

struct InferredCategory
  include CQL::ActiveRecord::Model(Int64)

  property id : Int64?
  property name : String

  has_many :gadgets, InferredGadget, foreign_key: :inferred_category_id

  def initialize(@name : String); end
end

struct InferredDay
  include CQL::ActiveRecord::Model(Int64)

  property id : Int64?
  property name : String

  def initialize(@name : String); end
end

struct InferredBox
  include CQL::ActiveRecord::Model(Int64)

  property id : Int64?
  property name : String

  def initialize(@name : String); end
end

struct InferredAddress
  include CQL::ActiveRecord::Model(Int64)

  property id : Int64?
  property name : String

  def initialize(@name : String); end
end

struct InferredBuzz
  include CQL::ActiveRecord::Model(Int64)

  property id : Int64?
  property name : String

  def initialize(@name : String); end
end

struct InferredBranch
  include CQL::ActiveRecord::Model(Int64)

  property id : Int64?
  property name : String

  def initialize(@name : String); end
end

struct InferredDish
  include CQL::ActiveRecord::Model(Int64)

  property id : Int64?
  property name : String

  def initialize(@name : String); end
end

struct InferredOrphan
  include CQL::ActiveRecord::Model(Int64)

  property id : Int64?
  property name : String

  def initialize(@name : String); end
end

struct InferredTwin
  include CQL::ActiveRecord::Model(Int64)

  property id : Int64?
  property name : String

  def initialize(@name : String); end
end

struct InferredCustomWidget
  include CQL::ActiveRecord::Model(Int64)

  db_context table: :custom_widgets

  property id : Int64?
  property name : String

  def initialize(@name : String); end
end

struct InferredSprocket
  include CQL::ActiveRecord::Model(Int64)

  db_context schema: InferredMirrorDB

  property id : Int64?
  property name : String

  def initialize(@name : String); end
end

module InferredWarehouse
  struct InferredCrate
    include CQL::ActiveRecord::Model(Int64)

    property id : Int64?
    property name : String

    def initialize(@name : String); end
  end
end

module InferredShop
  struct ShopOrder
    include CQL::ActiveRecord::Model(Int64)

    property id : Int64?
    property name : String

    def initialize(@name : String); end
  end
end

describe "Model without db_context" do
  describe ".table" do
    it "pluralizes and underscores the type name" do
      InferredGadget.table.should eq(:inferred_gadgets)
    end

    it "turns a trailing consonant-y into ies" do
      InferredCategory.table.should eq(:inferred_categories)
    end

    it "keeps a trailing vowel-y and adds s" do
      InferredDay.table.should eq(:inferred_days)
    end

    it "adds es after an x ending" do
      InferredBox.table.should eq(:inferred_boxes)
    end

    it "adds es after an s ending" do
      InferredAddress.table.should eq(:inferred_addresses)
    end

    it "adds es after a z ending" do
      InferredBuzz.table.should eq(:inferred_buzzes)
    end

    it "adds es after a ch ending" do
      InferredBranch.table.should eq(:inferred_branches)
    end

    it "adds es after an sh ending" do
      InferredDish.table.should eq(:inferred_dishes)
    end

    it "uses only the last namespace segment" do
      InferredShop::ShopOrder.table.should eq(:shop_orders)
    end

    it "still honours an explicit db_context table" do
      TestUser.table.should eq(:users)
    end
  end

  describe ".schema" do
    before_each { InferredContextDB.inferred_gadgets.create! }
    after_each { InferredContextDB.inferred_gadgets.drop! }

    it "uses the top-level schema that declares the inferred table" do
      InferredGadget.schema.should eq(InferredContextDB)
    end

    it "finds a schema declared inside the model's namespace" do
      InferredShop::ShopOrder.schema.should eq(InferredShop::ShopDB)
    end

    it "falls back to a top-level schema for a namespaced model" do
      InferredWarehouse::InferredCrate.schema.should eq(InferredContextDB)
    end

    it "round-trips a record through the inferred schema" do
      gadget = InferredGadget.create!(name: "Widget")

      InferredGadget.find!(gadget.id!).name.should eq("Widget")
    end
  end

  describe "unresolvable schema" do
    it "still infers the table of a model no schema declares" do
      InferredOrphan.table.should eq(:inferred_orphans)
    end

    it "names the model, the table and db_context when no schema declares the table" do
      expect_raises(CQL::ActiveRecord::SchemaMappingError, /InferredOrphan.*inferred_orphans.*db_context/m) do
        InferredOrphan.schema
      end
    end

    it "names the model, every declaring schema and db_context when several declare the table" do
      error = expect_raises(CQL::ActiveRecord::SchemaMappingError, /InferredTwin.*db_context/m) do
        InferredTwin.schema
      end

      error.message.to_s.should contain("InferredContextDB")
      error.message.to_s.should contain("InferredMirrorDB")
    end
  end

  describe "typed DSL" do
    before_each do
      InferredContextDB.inferred_gadgets.create!
      InferredContextDB.inferred_categories.create!
    end
    after_each do
      InferredContextDB.inferred_gadgets.drop!
      InferredContextDB.inferred_categories.drop!
    end

    it "filters with a where block on bare column names" do
      InferredGadget.create!(name: "Widget")
      InferredGadget.create!(name: "Gizmo")

      InferredGadget.where { name == "Widget" }.to_a.map(&.name).should eq(["Widget"])
    end

    it "joins a belongs_to association on the inferred table names" do
      InferredGadget.query.joins(:category).query.to_sql.first
        .should contain("INNER JOIN inferred_categories ON inferred_categories.id = inferred_gadgets.inferred_category_id")
    end

    it "joins a has_many association on the inferred table names" do
      InferredCategory.query.joins(:gadgets).query.to_sql.first
        .should contain("INNER JOIN inferred_gadgets ON inferred_gadgets.inferred_category_id = inferred_categories.id")
    end
  end

  describe "partial db_context" do
    it "keeps the given table and infers the schema that declares it" do
      InferredCustomWidget.table.should eq(:custom_widgets)
      InferredCustomWidget.schema.should eq(InferredContextDB)
    end

    it "keeps the given schema and infers the table from the type name" do
      InferredSprocket.schema.should eq(InferredMirrorDB)
      InferredSprocket.table.should eq(:inferred_sprockets)
    end
  end
end
