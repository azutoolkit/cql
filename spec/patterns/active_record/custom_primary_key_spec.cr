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

# Lends no connection: lets a PostgreSQL-adapter schema exist, and generate SQL, without a server.
private class OfflineSource < CQL::ConnectionSource
  def using_connection(& : DB::Connection -> _)
    raise "no database in this spec"
  end

  def transaction(& : DB::Transaction -> _)
    raise "no database in this spec"
  end

  def pool_stats : CQL::PoolStats
    CQL::PoolStats.new(0, 0, 0, 0)
  end

  def close : Nil
  end
end

LabelKeyPostgresDB = CQL::Schema.define(
  :label_key_postgres_db,
  adapter: CQL::Adapter::Postgres,
  uri: "postgres://localhost/label_key_postgres_db",
  source: OfflineSource.new
) do
  table :labels do
    primary :label_no, Int32
    text :name
  end

  table :tags do
    primary :id, Int32
    text :name
  end
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

  describe "creating a record" do
    it "reads back the generated key through the declared column" do
      label = Label.create!(name: "Noir")

      label.id.should_not be_nil
      Label.find(label.id!).try(&.name).should eq("Noir")
    end

    it "reads back the generated key when created from a hash" do
      label = Label.create!({:name => "Noir"} of Symbol => DB::Any)

      label.id.should_not be_nil
      Label.find(label.id!).try(&.name).should eq("Noir")
    end

    it "sets the generated key on an instance saved through #save" do
      label = Label.new
      label.name = "Noir"

      label.save.should be_true

      label.id.should_not be_nil
      label.persisted?.should be_true
      Label.find(label.id!).try(&.name).should eq("Noir")
    end

    it "generates a UUID key stored in the declared column" do
      badge = Badge.create!(name: "Gold")

      badge.id.should be_a(UUID)
      Badge.find(badge.id!).try(&.name).should eq("Gold")
      LabelKeyDB.exec_query(&.scalar("SELECT badge_uuid FROM badges")).should eq(badge.id!.to_s)
    end

    it "returns the declared key column when PostgreSQL fetches the new key" do
      insert = LabelKeyPostgresDB.insert.into(:labels).values(name: "Noir")

      insert.returning_primary_key_sql.should eq(
        {"INSERT INTO labels (name) VALUES ($1) RETURNING labels.label_no", ["Noir"] of DB::Any}
      )
    end

    it "returns id on PostgreSQL for a table keyed on id" do
      insert = LabelKeyPostgresDB.insert.into(:tags).values(name: "Noir")

      insert.returning_primary_key_sql.should eq(
        {"INSERT INTO tags (name) VALUES ($1) RETURNING tags.id", ["Noir"] of DB::Any}
      )
    end

    it "leaves the insert's own SQL without RETURNING" do
      insert = LabelKeyPostgresDB.insert.into(:labels).values(name: "Noir")

      insert.returning_primary_key_sql
      insert.to_sql.should eq({"INSERT INTO labels (name) VALUES ($1)", ["Noir"] of DB::Any})
    end
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

  describe "finding by primary key" do
    it "finds a row through .find, .find? and .find!" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir')")

      Label.find(7).try(&.name).should eq("Noir")
      Label.find?(7).try(&.name).should eq("Noir")
      Label.find!(7).name.should eq("Noir")
    end

    it "reports a missing key as nil or DB::NoResultsError naming the key column" do
      Label.find?(99).should be_nil
      Label.query.find(99).should be_nil
      expect_raises(DB::NoResultsError, "No records found with label_no=99") { Label.find!(99) }
      expect_raises(DB::NoResultsError, "No records found with label_no=99") { Label.query.find!(99) }
    end

    it "finds a row through the query builder" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir')")

      Label.query.find(7).try(&.name).should eq("Noir")
    end

    it "finds the rows of an array of keys" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir'), (8, 'Blanc'), (9, 'Gris')")

      Label.query.where_primary_key([7, 8]).all.compact_map(&.id).sort!.should eq([7, 8])
    end

    it "matches one key with = and an array of keys with IN" do
      Label.query.where_primary_key(7).to_sql_with_params.should eq(
        {"SELECT labels.label_no, labels.name FROM labels WHERE labels.label_no = ?", [7]}
      )
      Label.query.where_primary_key([7, 8]).to_sql_with_params.should eq(
        {"SELECT labels.label_no, labels.name FROM labels WHERE labels.label_no IN (?, ?)", [7, 8]}
      )
    end

    it "matches no rows for an empty array of keys" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir')")

      Label.query.where_primary_key([] of Int32).all.should be_empty
    end

    it "lists key values through ids" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (8, 'Blanc')")
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir')")

      Label.query.ids(as: Int32).sort.should eq([7, 8])
      Label.ids(as: Int32).sort.should eq([7, 8])
    end

    it "returns no rows from none" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir')")

      Label.query.none.all.should be_empty
    end

    it "makes none's condition independent of the key type" do
      insert_badge(UUID.new("5f0c3a1e-8d2b-4c7a-9e61-2b4f8d0a7c35"))

      Badge.query.none.to_sql_with_params.should eq(
        {"SELECT badges.badge_uuid, badges.name FROM badges WHERE 1 = 0", [] of DB::Any}
      )
      Badge.none.all.should be_empty
    end

    it "finds a UUID-keyed row" do
      uuid = UUID.new("5f0c3a1e-8d2b-4c7a-9e61-2b4f8d0a7c35")
      insert_badge(uuid)

      Badge.find(uuid).try(&.id).should eq(uuid)
      Badge.query.find(uuid).try(&.id).should eq(uuid)
    end

    it "binds UUID keys as text" do
      uuid = UUID.new("5f0c3a1e-8d2b-4c7a-9e61-2b4f8d0a7c35")
      insert_badge(uuid)

      Badge.query.where_primary_key(uuid).to_sql_with_params[1].should eq([uuid.to_s])
      Badge.query.where_primary_key([uuid]).all.map(&.id).should eq([uuid])
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
