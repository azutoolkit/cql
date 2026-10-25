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

  table :tickets do
    primary :ticket_no, Int32
    text :name
    lock_version :version
    timestamps
  end

  table :memos do
    primary :memo_no, Int32
    text :name
    integer :shelf_id, null: true
    timestamp :deleted_at, null: true
  end

  table :shelves do
    primary :id, Int32
    text :name
  end

  table :shelf_labels do
    primary :id, Int32
    integer :shelf_id
    integer :label_no
  end

  table :shelf_memos do
    primary :id, Int32
    integer :shelf_id
    integer :memo_no
  end

  table :stickers do
    primary :id, Int32
    text :name
    integer :label_no
  end

  table :shelf_notes do
    primary :note_no, Int32
    text :name
    integer :shelf_id, null: true
  end

  table :crates do
    primary :crate_no, Int32
    text :sku, unique: true
    text :name
  end
end

# A dirty-tracked model on the same custom-keyed table
class TrackedLabel
  include CQL::ActiveRecord::Model(Int32)
  include CQL::ActiveRecord::DirtyTracking

  db_context LabelKeyDB, :labels, primary_key: :label_no

  property name : String = ""

  def initialize
  end
end

class Label
  include CQL::ActiveRecord::Model(Int32)

  db_context LabelKeyDB, :labels, primary_key: :label_no

  property name : String = ""

  has_many :stickers, Sticker, foreign_key: :label_no

  def initialize
  end
end

# Belongs to a label through the label's custom key.
class Sticker
  include CQL::ActiveRecord::Model(Int32)

  db_context LabelKeyDB, :stickers

  property name : String = ""
  property label_no : Int32?

  belongs_to :label, Label, foreign_key: :label_no

  def initialize
  end
end

# Carries a unique column besides its custom key, so upserts can conflict on something other than the key.
class Crate
  include CQL::ActiveRecord::Model(Int32)

  db_context LabelKeyDB, :crates, primary_key: :crate_no

  property sku : String = ""
  property name : String = ""

  def initialize
  end
end

# A shelf's note, keyed on note_no.
class ShelfNote
  include CQL::ActiveRecord::Model(Int32)

  db_context LabelKeyDB, :shelf_notes, primary_key: :note_no

  property name : String = ""
  property shelf_id : Int32?

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

# A model on a custom key that touches timestamps and locks optimistically.
class Ticket
  include CQL::ActiveRecord::Model(Int32)
  include CQL::ActiveRecord::OptimisticLocking

  db_context LabelKeyDB, :tickets, primary_key: :ticket_no

  property name : String = ""
  property version : Int32 = 1
  property created_at : Time = Time.utc
  property updated_at : Time = Time.utc

  def initialize
  end

  optimistic_locking version_column: :version
end

# A soft-deletable model on a custom key.
class Memo
  include CQL::ActiveRecord::Model(Int32)
  include CQL::ActiveRecord::SoftDeletable

  db_context LabelKeyDB, :memos, primary_key: :memo_no

  property name : String = ""
  property shelf_id : Int32?

  def initialize
  end
end

class ShelfLabel
  include CQL::ActiveRecord::Model(Int32)

  db_context LabelKeyDB, :shelf_labels

  property shelf_id : Int32?
  property label_no : Int32?

  def initialize
  end
end

class ShelfMemo
  include CQL::ActiveRecord::Model(Int32)

  db_context LabelKeyDB, :shelf_memos

  property shelf_id : Int32?
  property memo_no : Int32?

  def initialize
  end
end

# Owns labels, whose key is label_no, through a join table.
class Shelf
  include CQL::ActiveRecord::Model(Int32)

  db_context LabelKeyDB, :shelves

  property name : String = ""

  many_to_many :labels, Label, join_through: ShelfLabel, foreign_key: :shelf_id, association_foreign_key: :label_no
  many_to_many :memos, Memo, join_through: ShelfMemo, foreign_key: :shelf_id, association_foreign_key: :memo_no, dependent: :delete_all
  has_many :pinned_memos, Memo, foreign_key: :shelf_id, dependent: :destroy
  has_many :notes, ShelfNote, foreign_key: :shelf_id

  def initialize
  end
end

private def insert_badge(uuid : UUID)
  LabelKeyDB.exec_query(&.exec("INSERT INTO badges (badge_uuid, name) VALUES (?, 'Gold')", uuid.to_s))
end

private def deleted_memo_numbers
  LabelKeyDB.exec_query(&.query_all("SELECT memo_no FROM memos WHERE deleted_at IS NOT NULL ORDER BY memo_no", as: Int32))
end

private def memo_numbers
  LabelKeyDB.exec_query(&.query_all("SELECT memo_no FROM memos ORDER BY memo_no", as: Int32))
end

private alias KeyRow = Hash(Symbol, DB::Any)

# INSERT statements (SQL) the block executed, in order.
private def key_insert_statements(& : ->) : Array(String)
  statements = [] of String
  subscription = "custom_primary_key_inserts_#{Random::Secure.hex(4)}"
  CQL::Telemetry.subscribe(subscription) { |event| statements << event.sql if event.operation == :insert }
  begin
    yield
  ensure
    CQL::Telemetry.unsubscribe(subscription)
  end
  statements
end

private def stored_label_names : Array({Int32, String})
  LabelKeyDB.exec_query(&.query_all("SELECT label_no, name FROM labels ORDER BY label_no", as: {Int32, String}))
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
    {% for table in %w[labels badges passes tickets memos shelves shelf_labels shelf_memos stickers shelf_notes crates] %}
      LabelKeyDB.{{table.id}}.drop! rescue nil
      LabelKeyDB.{{table.id}}.create!
    {% end %}
  end

  after_all do
    {% for table in %w[labels badges passes tickets memos shelves shelf_labels shelf_memos stickers shelf_notes crates] %}
      LabelKeyDB.{{table.id}}.drop! rescue nil
    {% end %}
  end

  before_each do
    {% for table in %w[labels badges passes tickets memos shelves shelf_labels shelf_memos stickers shelf_notes crates] %}
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

    it "fetches the new key with RETURNING the declared column on PostgreSQL" do
      statements = [] of String
      CQL::Telemetry.subscribe("custom_primary_key_returning") { |event| statements << event.sql }
      begin
        # The offline source raises once the statement is sent; the SQL is what matters here
        LabelKeyPostgresDB.insert.into(:labels).values(name: "Noir").last_insert_id(as: Int32) rescue nil
      ensure
        CQL::Telemetry.unsubscribe("custom_primary_key_returning")
      end

      statements.should eq(["INSERT INTO labels (name) VALUES ($1) RETURNING labels.label_no"])
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

    it "assigns id from the declared column when building trusted data from a hash" do
      label = Label.from_hash({:label_no => 8, :name => "Noir"} of Symbol => DB::Any, with_primary_key: true)

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

  describe "typed query DSL" do
    it "renders id on a custom key as a condition on the declared column" do
      Label.query.where { id == 7 }.query.to_sql.should eq({
        "SELECT labels.label_no, labels.name FROM labels WHERE labels.label_no = ?",
        [7] of DB::Any,
      })
    end

    it "returns the row of the declared column when run" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir'), (8, 'Blanc')")

      Label.query.where { id == 7 }.to_a.map(&.id).should eq([7])
    end

    it "reads the declared column into the id of selected rows" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir')")

      Label.query.select(:id, :name).to_a.map(&.id).should eq([7])
    end

    it "orders by id on the declared column" do
      Label.query.order_by(id: :desc).query.to_sql.first.should end_with("ORDER BY labels.label_no DESC")
    end

    it "renders id on a UUID custom key as a condition on the declared column, bound as text" do
      uuid = UUID.new("5f0c3a1e-8d2b-4c7a-9e61-2b4f8d0a7c35")

      Badge.query.where { id == uuid }.query.to_sql.should eq({
        "SELECT badges.badge_uuid, badges.name FROM badges WHERE badges.badge_uuid = ?",
        [uuid.to_s] of DB::Any,
      })
    end

    it "returns the UUID-keyed row when run" do
      uuid = UUID.new("5f0c3a1e-8d2b-4c7a-9e61-2b4f8d0a7c35")
      insert_badge(uuid)
      insert_badge(UUID.new("0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d"))

      Badge.query.where { id == uuid }.to_a.map(&.id).should eq([uuid])
    end

    it "still maps id to the id column on a model keyed on the default column" do
      Shelf.query.where { id == 1 }.query.to_sql.first.should end_with("WHERE shelves.id = ?")
    end
  end

  describe "updating a record" do
    it "saves only the changed columns of a dirty-tracked record through its key" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir'), (8, 'Rouge')")
      label = TrackedLabel.find!(7)

      label.name = "Blanc"
      label.save

      Label.find!(7).name.should eq("Blanc")
      Label.find!(8).name.should eq("Rouge")
    end

    it "leaves the key column out of a dirty-tracked record's SET" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir')")
      label = TrackedLabel.new
      label.id = 7
      label.name = "Blanc"

      updates = [] of String
      CQL::Telemetry.subscribe("custom_primary_key_tracked") { |event| updates << event.sql if event.operation == :update }
      begin
        label.save
      ensure
        CQL::Telemetry.unsubscribe("custom_primary_key_tracked")
      end

      updates.should eq(["UPDATE labels SET name = ? WHERE labels.label_no = ?"])
      Label.find!(7).name.should eq("Blanc")
    end

    stale = Time.utc(2020, 1, 1)

    it "updates the row of a key through .update! with named arguments" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir'), (8, 'Rouge')")

      Label.update!(7, name: "Blanc")

      Label.find!(7).name.should eq("Blanc")
      Label.find!(8).name.should eq("Rouge")
    end

    it "updates the row of a key through .update! with a hash" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir'), (8, 'Rouge')")

      Label.update!(7, {:name => "Blanc"} of Symbol => DB::Any)

      Label.find!(7).name.should eq("Blanc")
      Label.find!(8).name.should eq("Rouge")
    end

    it "persists an attribute change through #save" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir'), (8, 'Rouge')")
      label = Label.find!(7)

      label.name = "Blanc"
      label.save.should be_true

      Label.find!(7).name.should eq("Blanc")
      Label.find!(8).name.should eq("Rouge")
    end

    it "persists an attribute change through #update!" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir'), (8, 'Rouge')")
      label = Label.find!(7)

      label.update!(name: "Gris")

      Label.find!(7).name.should eq("Gris")
      Label.find!(8).name.should eq("Rouge")
    end

    it "updates the row of a UUID key" do
      uuid = UUID.new("5f0c3a1e-8d2b-4c7a-9e61-2b4f8d0a7c35")
      insert_badge(uuid)
      insert_badge(UUID.new("0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d"))

      Badge.update!(Badge.find!(uuid).id!, name: "Silver")

      Badge.find!(uuid).name.should eq("Silver")
      Badge.query.where_primary_key(UUID.new("0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d")).first!.name.should eq("Gold")
    end

    it "touches the updated_at of the record's row" do
      LabelKeyDB.exec("INSERT INTO tickets (ticket_no, name, version, created_at, updated_at) VALUES (5, 'Bug', 1, '2020-01-01 00:00:00', '2020-01-01 00:00:00')")
      ticket = Ticket.find!(5)

      ticket.touch.should be_true

      Ticket.find!(5).updated_at.should be > stale
    end

    it "touches the updated_at of the rows of several keys" do
      LabelKeyDB.exec("INSERT INTO tickets (ticket_no, name, version, created_at, updated_at) VALUES (5, 'Bug', 1, '2020-01-01 00:00:00', '2020-01-01 00:00:00'), (6, 'Crash', 1, '2020-01-01 00:00:00', '2020-01-01 00:00:00'), (7, 'Typo', 1, '2020-01-01 00:00:00', '2020-01-01 00:00:00')")

      Ticket.touch_all([5, 6]).should eq(2)

      Ticket.find!(5).updated_at.should be > stale
      Ticket.find!(6).updated_at.should be > stale
      Ticket.find!(7).updated_at.should eq(stale)
    end

    it "bumps the lock version of the row through a locked update" do
      LabelKeyDB.exec("INSERT INTO tickets (ticket_no, name, version, created_at, updated_at) VALUES (5, 'Bug', 1, '2020-01-01 00:00:00', '2020-01-01 00:00:00'), (6, 'Crash', 1, '2020-01-01 00:00:00', '2020-01-01 00:00:00')")
      ticket = Ticket.find!(5)

      ticket.name = "Fixed"
      ticket.update!

      ticket.version.should eq(2)
      Ticket.find!(5).name.should eq("Fixed")
      Ticket.find!(5).version.should eq(2)
      Ticket.find!(6).name.should eq("Crash")
      Ticket.find!(6).version.should eq(1)
    end

    it "rejects a locked update from a stale record" do
      LabelKeyDB.exec("INSERT INTO tickets (ticket_no, name, version, created_at, updated_at) VALUES (5, 'Bug', 1, '2020-01-01 00:00:00', '2020-01-01 00:00:00')")
      ticket = Ticket.find!(5)
      LabelKeyDB.exec("UPDATE tickets SET version = 2 WHERE ticket_no = 5")

      ticket.name = "Fixed"

      expect_raises(CQL::OptimisticLockError) { ticket.update! }
      Ticket.find!(5).name.should eq("Bug")
    end

    it "leaves the key column out of a locked update's SET and assigns the version once" do
      LabelKeyDB.exec("INSERT INTO tickets (ticket_no, name, version, created_at, updated_at) VALUES (5, 'Bug', 1, '2020-01-01 00:00:00', '2020-01-01 00:00:00')")
      ticket = Ticket.find!(5)
      ticket.name = "Fixed"

      updates = [] of String
      CQL::Telemetry.subscribe("custom_primary_key_updates") { |event| updates << event.sql if event.operation == :update }
      begin
        ticket.update!
      ensure
        CQL::Telemetry.unsubscribe("custom_primary_key_updates")
      end

      updates.size.should eq(1)
      set_clause = updates.first.split("WHERE").first
      set_clause.should_not contain("ticket_no")
      set_clause.scan("version =").size.should eq(1)
    end

    it "never writes the key through update_by" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir')")

      Label.update_by({:name => "Noir"} of Symbol => DB::Any, {:name => "Blanc", :label_no => 99} of Symbol => DB::Any)

      Label.find!(7).name.should eq("Blanc")
      Label.find?(99).should be_nil
    end

    it "persists an attribute change of a UUID-keyed record through #save" do
      uuid = UUID.new("9f8e7d6c-5b4a-4c3d-8e2f-1a0b9c8d7e6f")
      insert_badge(uuid)
      badge = Badge.find!(uuid)

      badge.name = "Silver"
      badge.save

      Badge.find!(uuid).name.should eq("Silver")
    end

    it "touches no rows for an empty list of keys" do
      Ticket.touch_all([] of Int32).should eq(0)
    end
  end

  describe "deleting a record" do
    uuid = UUID.new("5f0c3a1e-8d2b-4c7a-9e61-2b4f8d0a7c35")

    it "deletes the row of a key through .delete!" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir'), (8, 'Rouge')")

      Label.delete!(7)

      Label.find?(7).should be_nil
      Label.find!(8).name.should eq("Rouge")
    end

    it "deletes the row of a found record through #delete!" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir'), (8, 'Rouge')")
      label = Label.find!(7)

      label.delete!.should be_true

      label.destroyed?.should be_true
      Label.find?(7).should be_nil
      Label.find!(8).name.should eq("Rouge")
    end

    it "deletes the rows of several keys through .delete_ids" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir'), (8, 'Rouge'), (9, 'Gris')")

      Label.delete_ids([7, 8]).should eq(2)

      Label.query.ids(as: Int32).should eq([9])
    end

    it "deletes the row of a UUID key" do
      other = UUID.new("0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d")
      insert_badge(uuid)
      insert_badge(other)

      Badge.delete!(uuid)

      Badge.find?(uuid).should be_nil
      Badge.find?(other).should_not be_nil
    end

    it "soft deletes the row of a found record and hides it from .find?" do
      LabelKeyDB.exec("INSERT INTO memos (memo_no, name) VALUES (7, 'Note'), (8, 'Draft')")
      memo = Memo.find!(7)

      memo.delete!.should be_true

      deleted_memo_numbers.should eq([7])
      Memo.find?(7).should be_nil
      Memo.find?(8).should_not be_nil
    end

    it "soft deletes the row of a key through .delete!" do
      LabelKeyDB.exec("INSERT INTO memos (memo_no, name) VALUES (7, 'Note'), (8, 'Draft')")

      Memo.delete!(7).should be_true

      deleted_memo_numbers.should eq([7])
      Memo.find?(7).should be_nil
    end

    it "restores a soft-deleted record through #restore!" do
      LabelKeyDB.exec("INSERT INTO memos (memo_no, name) VALUES (7, 'Note'), (8, 'Draft')")
      memo = Memo.find!(7)
      memo.delete!

      memo.restore!.should be_true

      deleted_memo_numbers.should be_empty
      Memo.find?(7).should_not be_nil
    end

    it "restores the soft-deleted row of a key through .restore!" do
      LabelKeyDB.exec("INSERT INTO memos (memo_no, name, deleted_at) VALUES (7, 'Note', '2020-01-01 00:00:00'), (8, 'Draft', '2020-01-01 00:00:00')")

      Memo.restore!(7).should be_true

      deleted_memo_numbers.should eq([8])
      Memo.find?(7).should_not be_nil
    end

    it "removes the row of a key through .force_delete!" do
      LabelKeyDB.exec("INSERT INTO memos (memo_no, name) VALUES (7, 'Note'), (8, 'Draft')")

      Memo.force_delete!(7)

      memo_numbers.should eq([8])
    end

    it "removes the row of a found record through #force_delete!" do
      LabelKeyDB.exec("INSERT INTO memos (memo_no, name) VALUES (7, 'Note'), (8, 'Draft')")

      Memo.find!(7).force_delete!.should be_true

      memo_numbers.should eq([8])
    end

    it "soft deletes the rows of several keys through .delete_ids" do
      LabelKeyDB.exec("INSERT INTO memos (memo_no, name) VALUES (7, 'Note'), (8, 'Draft'), (9, 'Memo')")

      Memo.delete_ids([7, 8]).should eq(2)

      deleted_memo_numbers.should eq([7, 8])
      memo_numbers.should eq([7, 8, 9])
    end

    it "leaves already soft-deleted rows alone in a soft .delete_ids" do
      LabelKeyDB.exec("INSERT INTO memos (memo_no, name, deleted_at) VALUES (7, 'Note', '2020-01-01 00:00:00'), (8, 'Draft', NULL)")

      Memo.delete_ids([7, 8]).should eq(1)

      deleted_memo_numbers.should eq([7, 8])
      LabelKeyDB.exec_query(&.query_one("SELECT deleted_at FROM memos WHERE memo_no = 7", as: String)).should start_with("2020-01-01")
    end

    it "deletes a parent whose dependent: :destroy children include an already soft-deleted one" do
      LabelKeyDB.exec("INSERT INTO shelves (id, name) VALUES (1, 'Oak')")
      LabelKeyDB.exec("INSERT INTO memos (memo_no, name, shelf_id, deleted_at) VALUES (7, 'Old', 1, '2020-01-01 00:00:00'), (8, 'New', 1, NULL)")

      Shelf.find!(1).delete!.should be_true

      Shelf.find?(1).should be_nil
      deleted_memo_numbers.should eq([7, 8])
      LabelKeyDB.exec_query(&.query_one("SELECT deleted_at FROM memos WHERE memo_no = 7", as: String)).should start_with("2020-01-01")
    end

    it "restores only the soft-deleted rows through .restore_all" do
      LabelKeyDB.exec("INSERT INTO memos (memo_no, name, deleted_at) VALUES (7, 'Note', '2020-01-01 00:00:00'), (8, 'Draft', NULL)")

      Memo.restore_all.should eq(1)

      deleted_memo_numbers.should be_empty
      memo_numbers.should eq([7, 8])
    end

    it "deletes the rows of several UUID keys through .delete_ids" do
      kept = UUID.new("0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d")
      removed = [UUID.new("1b2c3d4e-5f6a-4b7c-8d9e-0f1a2b3c4d5e"), UUID.new("2c3d4e5f-6a7b-4c8d-9e0f-1a2b3c4d5e6f")]
      ([kept] + removed).each { |badge_uuid| insert_badge(badge_uuid) }

      Badge.delete_ids(removed).should eq(2)

      Badge.find?(kept).should_not be_nil
      removed.each { |badge_uuid| Badge.find?(badge_uuid).should be_nil }
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

    it "assigns id from the declared column when building trusted data from a hash" do
      badge = Badge.from_hash({:badge_uuid => uuid.to_s} of Symbol => DB::Any, with_primary_key: true)

      badge.id.should eq(uuid)
    end

    it "stores a hash-built id in canonical form" do
      badge = Badge.from_hash({:badge_uuid => uuid.to_s.upcase} of Symbol => DB::Any, with_primary_key: true)

      badge.attributes[:badge_uuid].should eq(uuid.to_s)
    end

    it "ignores a malformed id when building trusted data from a hash" do
      Badge.from_hash({:badge_uuid => "not-a-uuid"} of Symbol => DB::Any, with_primary_key: true).id.should be_nil
    end

    it "assigns id from :id when building trusted data for a model keyed on the default column" do
      Pass.from_hash({:id => uuid.to_s} of Symbol => DB::Any, with_primary_key: true).id.should eq(uuid)
    end
  end

  describe "mass assignment of the primary key" do
    it "ignores the key column in #attributes with a hash" do
      label = Label.from_hash({:label_no => 7, :name => "Noir"} of Symbol => DB::Any, with_primary_key: true)

      label.attributes({:label_no => 8, :name => "Blanc"} of Symbol => DB::Any)

      label.id.should eq(7)
      label.name.should eq("Blanc")
    end

    it "ignores the key column in #attributes with named arguments" do
      label = Label.from_hash({:label_no => 7, :name => "Noir"} of Symbol => DB::Any, with_primary_key: true)

      label.attributes(label_no: 8, name: "Blanc")

      label.id.should eq(7)
    end

    it "ignores :id in #attributes on a model keyed on the default column" do
      uuid = UUID.new("3e2d1c0b-9a8f-4e7d-8c6b-5a4f3e2d1c0b")
      pass = Pass.from_hash({:id => uuid.to_s} of Symbol => DB::Any, with_primary_key: true)

      pass.attributes({:id => UUID.random.to_s} of Symbol => DB::Any)

      pass.id.should eq(uuid)
    end

    it "updates the record's own row when #update! is given another key" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir'), (8, 'Rouge')")
      label = Label.find!(7)

      label.update!({:label_no => 8, :name => "Blanc"} of Symbol => DB::Any)

      label.id.should eq(7)
      Label.find!(7).name.should eq("Blanc")
      Label.find!(8).name.should eq("Rouge")
    end

    it "keeps another row intact when params carrying its id are assigned and saved" do
      LabelKeyDB.exec("INSERT INTO shelves (id, name) VALUES (1, 'Oak'), (2, 'Pine')")
      shelf = Shelf.find!(1)

      shelf.attributes({:id => 2, :name => "Birch"} of Symbol => DB::Any)
      shelf.save

      Shelf.find!(1).name.should eq("Birch")
      Shelf.find!(2).name.should eq("Pine")
    end

    it "ignores the key in from_hash by default, so saving inserts a new row" do
      LabelKeyDB.exec("INSERT INTO shelves (id, name) VALUES (2, 'Pine')")

      shelf = Shelf.from_hash({:id => 2, :name => "Birch"} of Symbol => DB::Any)
      shelf.id.should be_nil
      shelf.save

      Shelf.find!(2).name.should eq("Pine")
      Shelf.count.should eq(2)
    end

    it "guards #update! with attributes by the optimistic lock" do
      LabelKeyDB.exec("INSERT INTO tickets (ticket_no, name, version, created_at, updated_at) VALUES (5, 'Bug', 1, '2020-01-01 00:00:00', '2020-01-01 00:00:00')")
      ticket = Ticket.find!(5)
      LabelKeyDB.exec("UPDATE tickets SET version = 2 WHERE ticket_no = 5")

      expect_raises(CQL::OptimisticLockError) { ticket.update!(name: "Fixed") }
      Ticket.find!(5).name.should eq("Bug")
    end
  end

  describe "touch_all over the bind limit" do
    it "touches every row with one UPDATE per chunk of keys" do
      count = Ticket.adapter.dialect.max_bind_params
      rows = (1..count).map do |key|
        {:ticket_no => key.as(DB::Any), :name => "T#{key}".as(DB::Any), :version => 1.as(DB::Any)}
      end
      Ticket.insert_all(rows)

      updates = count_queries(:update) { Ticket.touch_all((1..count).to_a).should eq(count) }

      updates.size.should eq(2)
    end
  end

  describe "many_to_many with a custom target key" do
    it "lists the labels of the shelf with their own keys" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir'), (8, 'Blanc'), (9, 'Gris')")
      shelf = Shelf.create!(name: "Front")
      other = Shelf.create!(name: "Back")

      shelf.labels << Label.find!(7)
      shelf.labels << Label.find!(8)
      other.labels << Label.find!(9)

      shelf.reload_labels.to_a.compact_map(&.id).sort!.should eq([7, 8])
      shelf.labels.to_a.map(&.name).sort!.should eq(["Blanc", "Noir"])
      other.reload_labels.to_a.map(&.id).should eq([9])
    end

    it "keys the labels by label_no, not by the join row ids" do
      LabelKeyDB.exec("INSERT INTO shelf_labels (id, shelf_id, label_no) VALUES (1, 1, 50), (2, 2, 51), (3, 1, 52)")
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (1, 'Join one'), (2, 'Join two'), (3, 'Join three'), (50, 'Noir'), (52, 'Blanc')")
      LabelKeyDB.exec("INSERT INTO shelves (id, name) VALUES (1, 'Front')")

      Shelf.find!(1).labels.to_a.compact_map(&.id).sort!.should eq([50, 52])
    end

    it "associates a label created through the collection" do
      shelf = Shelf.create!(name: "Front")

      built = Label.new
      built.name = "Noir"

      label = shelf.labels.create(built)

      label.id.should_not be_nil
      shelf.reload_labels.to_a.map(&.id).should eq([label.id])
      Label.find!(label.id!).name.should eq("Noir")
    end

    it "finds the labels of the shelf with attributes" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir'), (8, 'Blanc')")
      shelf = Shelf.create!(name: "Front")
      other = Shelf.create!(name: "Back")
      shelf.labels << Label.find!(7)
      other.labels << Label.find!(8)

      shelf.labels.find(name: "Noir").map(&.id).should eq([7])
      shelf.labels.find(name: "Blanc").should be_empty
    end

    it "finds one label of the shelf through find_by" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir'), (8, 'Blanc')")
      shelf = Shelf.create!(name: "Front")
      shelf.labels << Label.find!(7)

      shelf.labels.find_by(name: "Noir").try(&.id).should eq(7)
      shelf.labels.find_by(name: "Blanc").should be_nil
    end

    it "checks whether a label with attributes belongs to the shelf" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir'), (8, 'Blanc')")
      shelf = Shelf.create!(name: "Front")
      shelf.labels << Label.find!(7)

      shelf.labels.exists?(name: "Noir").should be_true
      shelf.labels.exists?(name: "Blanc").should be_false
    end

    it "lists the label_no values through ids" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir'), (8, 'Blanc'), (9, 'Gris')")
      shelf = Shelf.create!(name: "Front")
      shelf.labels << Label.find!(8)
      shelf.labels << Label.find!(7)

      shelf.labels.ids.sort!.should eq([7, 8])
      shelf.labels_ids.sort!.should eq([7, 8])
    end

    it "removes only the join row when a label is deleted from the collection" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir'), (8, 'Blanc')")
      shelf = Shelf.create!(name: "Front")
      shelf.labels << Label.find!(7)
      shelf.labels << Label.find!(8)

      shelf.labels.delete(Label.find!(7)).try(&.id).should eq(7)

      LabelKeyDB.exec_query(&.query_all("SELECT label_no FROM shelf_labels", as: Int32)).should eq([8])
      Label.find?(7).should_not be_nil
      shelf.reload_labels.to_a.map(&.id).should eq([8])
    end

    it "soft deletes the linked memos, and removes the join rows, when the collection is cleared" do
      LabelKeyDB.exec("INSERT INTO memos (memo_no, name) VALUES (7, 'Note'), (8, 'Draft'), (9, 'Memo')")
      shelf = Shelf.create!(name: "Front")
      shelf.memos << Memo.find!(7)
      shelf.memos << Memo.find!(8)

      shelf.memos.clear

      deleted_memo_numbers.should eq([7, 8])
      memo_numbers.should eq([7, 8, 9])
      LabelKeyDB.exec_query(&.query_all("SELECT memo_no FROM shelf_memos", as: Int32)).should be_empty
    end
  end

  describe "belongs_to and has_many with custom keys" do
    it "preloads the labels of stickers through label_no without a query per record" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir'), (8, 'Blanc')")
      LabelKeyDB.exec("INSERT INTO stickers (id, name, label_no) VALUES (1, 'Star', 7), (2, 'Moon', 8), (3, 'Sun', 7)")

      stickers = [] of Sticker
      loading = count_queries { stickers = Sticker.order(id: :asc).preload(:label).all }
      reading = count_queries { stickers.map(&.label.try(&.name)) }

      loading.size.should eq(2)
      reading.should be_empty
      stickers.map(&.label.try(&.name)).should eq(["Noir", "Blanc", "Noir"])
    end

    it "removes only the given sticker through delete(id) on a custom-keyed parent" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir'), (8, 'Blanc')")
      LabelKeyDB.exec("INSERT INTO stickers (id, name, label_no) VALUES (1, 'Star', 7), (2, 'Moon', 7), (3, 'Sun', 8)")
      label = Label.find!(7)

      label.stickers.delete(1).should be_true

      Sticker.query.ids(as: Int32).sort.should eq([2, 3])
    end

    it "removes only the given sticker through delete(record)" do
      LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir'), (8, 'Blanc')")
      LabelKeyDB.exec("INSERT INTO stickers (id, name, label_no) VALUES (1, 'Star', 7), (2, 'Moon', 7), (3, 'Sun', 8)")
      label = Label.find!(7)

      label.stickers.delete(Sticker.find!(2))

      Sticker.query.ids(as: Int32).sort.should eq([1, 3])
    end

    it "removes only the given note through delete(id) on a custom-keyed target" do
      LabelKeyDB.exec("INSERT INTO shelf_notes (note_no, name, shelf_id) VALUES (5, 'A', 1), (6, 'B', 1), (7, 'C', 2)")
      LabelKeyDB.exec("INSERT INTO shelves (id, name) VALUES (1, 'Front'), (2, 'Back')")
      shelf = Shelf.find!(1)
      note = ShelfNote.find!(5)

      shelf.notes.delete(note.id!).should be_true

      ShelfNote.query.ids(as: Int32).sort.should eq([6, 7])
    end

    it "does not remove a note of another shelf through delete(id)" do
      LabelKeyDB.exec("INSERT INTO shelf_notes (note_no, name, shelf_id) VALUES (5, 'A', 1), (7, 'C', 2)")
      LabelKeyDB.exec("INSERT INTO shelves (id, name) VALUES (1, 'Front'), (2, 'Back')")

      Shelf.find!(1).notes.delete(7).should be_false

      ShelfNote.query.ids(as: Int32).sort.should eq([5, 7])
    end

    it "points the notes of ids= at the shelf through the target key" do
      LabelKeyDB.exec("INSERT INTO shelves (id, name) VALUES (1, 'Front'), (2, 'Back')")
      LabelKeyDB.exec("INSERT INTO shelf_notes (note_no, name, shelf_id) VALUES (5, 'A', NULL), (6, 'B', NULL), (7, 'C', 2)")
      shelf = Shelf.find!(1)

      shelf.notes.ids = [5, 6]

      LabelKeyDB.exec_query(&.query_all("SELECT note_no FROM shelf_notes WHERE shelf_id = 1 ORDER BY note_no", as: Int32)).should eq([5, 6])
      ShelfNote.find!(7).shelf_id.should eq(2)
    end

    it "joins a belongs_to on the target's custom key" do
      Sticker.query.joins(:label).query.to_sql.should eq({
        "SELECT stickers.id, stickers.name, stickers.label_no, labels.label_no, labels.name " \
        "FROM stickers INNER JOIN labels ON labels.label_no = stickers.label_no",
        [] of DB::Any,
      })
    end

    it "joins a has_many on the parent's custom key" do
      Label.query.joins(:stickers).query.to_sql.should eq({
        "SELECT labels.label_no, labels.name, stickers.id, stickers.name, stickers.label_no " \
        "FROM labels INNER JOIN stickers ON stickers.label_no = labels.label_no",
        [] of DB::Any,
      })
    end
  end

  describe "pagination and bulk insert with custom keys" do
    describe "cursor pagination" do
      before_each do
        LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (5, 'Five'), (6, 'Six'), (7, 'Seven'), (8, 'Eight')")
      end

      it "returns the labels after a cursor in key order" do
        Label.after_cursor(6, limit: 10).map(&.id).should eq([7, 8])
      end

      it "limits the labels after a cursor" do
        Label.after_cursor(5, limit: 2).map(&.id).should eq([6, 7])
      end

      it "returns the labels before a cursor in ascending key order" do
        Label.before_cursor(7, limit: 10).map(&.id).should eq([5, 6])
      end

      it "keeps the labels nearest the cursor when limiting before it" do
        Label.before_cursor(8, limit: 2).map(&.id).should eq([6, 7])
      end
    end

    describe ".insert_all" do
      it "generates a UUID for each badge row into the declared column" do
        Badge.insert_all([{name: "Gold"}, {name: "Silver"}]).should eq(2)

        ids = LabelKeyDB.exec_query(&.query_all("SELECT badge_uuid FROM badges", as: String))
        ids.size.should eq(2)
        ids.uniq.size.should eq(2)
        ids.each { |id| Badge.find(UUID.new(id)).should_not be_nil }
        Badge.query.all.map(&.name).sort!.should eq(["Gold", "Silver"])
      end

      it "keeps the badge ids given by the rows" do
        uuid = UUID.new("5f0c3a1e-8d2b-4c7a-9e61-2b4f8d0a7c35")

        Badge.insert_all([KeyRow{:badge_uuid => uuid.to_s.as(DB::Any), :name => "Gold".as(DB::Any)}, KeyRow{:name => "Silver".as(DB::Any)}])

        Badge.find!(uuid).name.should eq("Gold")
        Badge.query.all.size.should eq(2)
      end

      it "lets the database assign label_no to rows that leave it out" do
        Label.insert_all([{name: "Noir"}, {name: "Blanc"}]).should eq(2)

        labels = Label.order(name: :asc).all
        labels.map(&.name).should eq(["Blanc", "Noir"])
        labels.map(&.id).should_not contain(nil)
        labels.map(&.id).uniq!.size.should eq(2)
      end

      it "lets the database assign label_no to rows that set it to nil" do
        rows = [KeyRow{:label_no => nil, :name => "Noir".as(DB::Any)}, KeyRow{:label_no => nil, :name => "Blanc".as(DB::Any)}]

        Label.insert_all(rows).should eq(2)

        labels = Label.order(name: :asc).all
        labels.map(&.name).should eq(["Blanc", "Noir"])
        labels.map(&.id).should_not contain(nil)
        labels.map(&.id).uniq!.size.should eq(2)
      end

      it "keeps the label_no given by a row" do
        Label.insert_all([KeyRow{:label_no => 42, :name => "Noir".as(DB::Any)}])

        Label.find!(42).name.should eq("Noir")
      end
    end

    describe ".upsert_all" do
      it "updates the label with the same label_no and creates no duplicate" do
        LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir'), (8, 'Rouge')")

        Label.upsert_all([KeyRow{:label_no => 7, :name => "Blanc".as(DB::Any)}], on_conflict: :label_no)

        stored_label_names.should eq([{7, "Blanc"}, {8, "Rouge"}])
      end

      it "inserts a label whose label_no is new" do
        LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir')")

        Label.upsert_all([KeyRow{:label_no => 7, :name => "Blanc".as(DB::Any)}, KeyRow{:label_no => 9, :name => "Gris".as(DB::Any)}], on_conflict: :label_no)

        stored_label_names.should eq([{7, "Blanc"}, {9, "Gris"}])
      end

      it "leaves the key column out of the update when conflicting on the key" do
        LabelKeyDB.exec("INSERT INTO labels (label_no, name) VALUES (7, 'Noir')")

        statements = key_insert_statements do
          Label.upsert_all([KeyRow{:label_no => 7, :name => "Blanc".as(DB::Any)}], on_conflict: :label_no)
        end

        statements.size.should eq(1)
        update_clause = statements.first.split("DO UPDATE").last
        update_clause.should contain("name")
        update_clause.should_not contain("label_no")
      end

      it "never overwrites the key of an existing row when conflicting on another column" do
        LabelKeyDB.exec("INSERT INTO crates (crate_no, sku, name) VALUES (3, 'a1', 'Apples')")

        Crate.upsert_all([KeyRow{:crate_no => 99, :sku => "a1".as(DB::Any), :name => "Pears".as(DB::Any)}], on_conflict: :sku)

        crate = Crate.find_by!(sku: "a1")
        crate.id.should eq(3)
        crate.name.should eq("Pears")
        Crate.find?(99).should be_nil
      end

      it "raises ArgumentError before any statement when conflicting on a generated UUID key" do
        statements = key_insert_statements do
          expect_raises(ArgumentError, /badge_uuid.*generated id/) do
            Badge.upsert_all([{name: "Gold"}, {name: "Silver"}], on_conflict: :badge_uuid)
          end
        end

        statements.should be_empty
        Badge.query.all.should be_empty
      end

      it "upserts UUID-keyed rows that all give their key" do
        uuid = UUID.new("5f0c3a1e-8d2b-4c7a-9e61-2b4f8d0a7c35")
        insert_badge(uuid)

        Badge.upsert_all([KeyRow{:badge_uuid => uuid.to_s.as(DB::Any), :name => "Silver".as(DB::Any)}], on_conflict: :badge_uuid)

        Badge.query.all.size.should eq(1)
        Badge.find!(uuid).name.should eq("Silver")
      end
    end
  end

  describe "schema mapping validation of the primary key" do
    keyless = CQL::Schema.define(:keyless_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3:///tmp/custom_primary_key_keyless.db") do
      table :plain do
        text :name
      end

      table :legacy_tags do
        primary :tag_uuid, String, auto_increment: false
        integer :id
      end

      table :avatars do
        primary :id, Int32
        blob :image, null: true
      end
    end

    validate = ->(table : Symbol, key : Symbol, getters : Hash(String, String), schema : CQL::Schema) do
      CQL::ActiveRecord::SchemaValidator.validate_model!("Model", schema, table, getters, primary_key: key)
    end

    it "accepts a Bytes getter on a blob column" do
      validate.call(:avatars, :id, {"id" => "Int32 | ::Nil", "image" => "Bytes | ::Nil"}, keyless)
    end

    it "does not check a plain id column against the key getter on a table keyed on another column" do
      validate.call(:legacy_tags, :tag_uuid, {"id" => "UUID | ::Nil"}, keyless)
    end

    it "raises naming both columns when the model keeps :id on a table keyed on another column" do
      error = expect_raises(CQL::ActiveRecord::SchemaMappingError) do
        CQL::ActiveRecord::SchemaValidator.validate_model!("Label", LabelKeyDB, :labels, {"id" => "Int32 | ::Nil"})
      end

      message = error.message.to_s
      message.should contain("`labels`")
      message.should contain("declares primary key `label_no`")
      message.should contain("maps `id` to `id`")
      message.should contain("primary_key: :label_no")
    end

    it "does not raise when the model's key matches the table's" do
      validate.call(:labels, :label_no, {"id" => "Int32 | ::Nil"}, LabelKeyDB)
    end

    it "does not raise on a table keyed on id when the model keeps :id" do
      validate.call(:shelves, :id, {"id" => "Int32 | ::Nil"}, LabelKeyDB)
    end

    it "does not raise when the table declares no primary key" do
      validate.call(:plain, :id, {} of String => String, keyless)
    end

    it "raises the type mismatch when the key getter's type differs from the key column" do
      error = expect_raises(CQL::ActiveRecord::SchemaMappingError, /type String does not match/) do
        validate.call(:badges, :badge_uuid, {"id" => "Int32 | ::Nil"}, LabelKeyDB)
      end

      error.message.to_s.should contain("badges.badge_uuid")
      error.message.to_s.should contain("Int32")
    end

    it "accepts a UUID key getter on a text key column" do
      validate.call(:badges, :badge_uuid, {"id" => "UUID | ::Nil"}, LabelKeyDB)
    end
  end
end
