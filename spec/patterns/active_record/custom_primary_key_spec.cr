require "../../spec_helper"

LabelKeyDB = CQL::Schema.define(
  :label_key_db,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3:///tmp/custom_primary_key_spec.db"
) do
  table :labels do
    primary :label_no, Int32
    text :name
  end

  table :badges do
    primary :badge_uuid, String, auto_increment: false # UUID stored as TEXT in SQLite
    text :name
  end

  table :passes do
    primary :id, String, auto_increment: false
    text :name
  end
end

class Label
  include CQL::ActiveRecord::Model(Int32)

  db_context LabelKeyDB, :labels, primary_key: :label_no

  property name : String = ""

  def initialize
  end
end

class Badge
  include CQL::ActiveRecord::Model(UUID)

  db_context LabelKeyDB, :badges, primary_key: :badge_uuid

  property name : String = ""

  def initialize
  end
end

# A UUID model on the default key, whose id storage is mapped to the `id` column.
class Pass
  include CQL::ActiveRecord::Model(UUID)

  db_context LabelKeyDB, :passes

  property name : String = ""

  def initialize
  end
end

private def insert_badge(uuid : UUID)
  LabelKeyDB.exec_query(&.exec("INSERT INTO badges (badge_uuid, name) VALUES (?, 'Gold')", uuid.to_s))
end

describe "Custom primary key column" do
  before_all do
    {% for table in %w[labels badges passes] %}
      LabelKeyDB.{{table.id}}.drop! rescue nil
      LabelKeyDB.{{table.id}}.create!
    {% end %}
  end

  after_all do
    {% for table in %w[labels badges passes] %}
      LabelKeyDB.{{table.id}}.drop! rescue nil
    {% end %}
  end

  before_each do
    {% for table in %w[labels badges passes] %}
      LabelKeyDB.exec("DELETE FROM {{table.id}}")
    {% end %}
  end

  describe ".primary_key_column" do
    it "returns the column declared through db_context" do
      Label.primary_key_column.should eq(:label_no)
    end

    it "defaults to :id when db_context declares no primary key" do
      Actor.primary_key_column.should eq(:id)
    end
  end

  describe "loading a row" do
    it "reads the declared column into id" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir')")

      label = Label.query.first!

      label.id.should eq(7)
      label.name.should eq("Noir")
    end
  end

  describe "#attributes" do
    it "keys the primary key by the declared column and omits :id" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir')")

      attributes = Label.query.first!.attributes

      attributes[:label_no].should eq(7)
      attributes.has_key?(:id).should be_false
    end

    it "assigns id from the declared column" do
      label = Label.new

      label.attributes({:label_no => 8} of Symbol => DB::Any)

      label.id.should eq(8)
    end
  end

  describe "with a UUID primary key" do
    uuid = UUID.new("5f0c3a1e-8d2b-4c7a-9e61-2b4f8d0a7c35")

    it "returns the declared column" do
      Badge.primary_key_column.should eq(:badge_uuid)
    end

    it "reads the declared column into id" do
      insert_badge(uuid)

      Badge.query.first!.id.should eq(uuid)
    end

    it "keys the primary key by the declared column and omits the id storage" do
      insert_badge(uuid)

      attributes = Badge.query.first!.attributes

      attributes[:badge_uuid].should eq(uuid.to_s)
      attributes.has_key?(:id).should be_false
      attributes.has_key?(:_id_storage).should be_false
    end

    it "assigns id from the declared column" do
      badge = Badge.new

      badge.attributes({:badge_uuid => uuid.to_s} of Symbol => DB::Any)

      badge.id.should eq(uuid)
    end

    it "stores an assigned id in canonical form" do
      badge = Badge.new

      badge.attributes({:badge_uuid => uuid.to_s.upcase} of Symbol => DB::Any)

      badge.attributes[:badge_uuid].should eq(uuid.to_s)
    end

    it "ignores a malformed id" do
      badge = Badge.new
      badge.id = uuid

      badge.attributes({:badge_uuid => "not-a-uuid"} of Symbol => DB::Any)

      badge.id.should eq(uuid)
    end

    it "assigns id through named arguments" do
      badge = Badge.new

      badge.attributes(badge_uuid: uuid.to_s)

      badge.id.should eq(uuid)
    end

    it "assigns id from :id on a model keyed on the default column" do
      pass = Pass.new

      pass.attributes({:id => uuid.to_s} of Symbol => DB::Any)

      pass.id.should eq(uuid)
    end
  end
end
