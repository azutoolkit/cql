require "./spec_helper"

private UPDATE_ROWS_DB = CQL::Schema.define(:update_rows, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("update_rows.db")) do
  table(:gizmos) { primary :id, Int64, auto_increment: true; text :name; timestamp :deleted_at, null: true }
end
private LOCKING_DB = CQL::Schema.define(:update_rows_locking, adapter: postgres_available? ? CQL::Adapter::Postgres : CQL::Adapter::SQLite,
  uri: postgres_available? ? postgres_database_url : spec_sqlite_uri("update_rows.db")) do
  table(:locking_gizmos) { primary :id, Int64, auto_increment: true; text :name }
end

private class Gizmo
  include CQL::ActiveRecord::Model(Int64)
  db_context UPDATE_ROWS_DB, :gizmos
  property name : String = ""
end

private class SoftGizmo
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::SoftDeletable
  db_context UPDATE_ROWS_DB, :gizmos
  property name : String = ""
end

private class LockingGizmo
  include CQL::ActiveRecord::Model(Int64)
  db_context LOCKING_DB, :locking_gizmos
  property name : String = ""
end

describe "Updating a saved record" do
  id = 987_654_i64
  UPDATE_ROWS_DB.build
  # The UPDATE reports 0 rows for a row it leaves as it was, as MySQL does.
  UPDATE_ROWS_DB.exec("CREATE TRIGGER IF NOT EXISTS unchanged BEFORE UPDATE ON gizmos WHEN NEW.name IS OLD.name BEGIN SELECT RAISE(IGNORE); END")
  before_each { UPDATE_ROWS_DB.exec("INSERT OR REPLACE INTO gizmos (id, name) VALUES (#{id}, 'Ann')") }

  it "raises RecordNotFound naming the model, never the id, once another statement deleted the row" do
    gizmo = Gizmo.find!(id).tap(&.name=("Bob"))
    UPDATE_ROWS_DB.exec("DELETE FROM gizmos")
    {-> { gizmo.update! }, -> { gizmo.save! }, -> { Gizmo.update!(gizmo) }, -> { Gizmo.update!(id, name: "Bob") },
     -> { Gizmo.update!(id, {:name => "Bob"} of Symbol => DB::Any) }}.each do |write|
      message = expect_raises(CQL::RecordNotFound) { write.call }.message.to_s
      {message.includes?("Gizmo"), message.includes?(id.to_s)}.should eq({true, false})
    end
  end

  it "returns the record when the UPDATE reports 0 rows for a row that is still there" do
    UPDATE_ROWS_DB.exec("UPDATE gizmos SET name = 'Ann'").rows_affected.should eq(0)
    gizmo = Gizmo.find!(id)
    {gizmo.update!.same?(gizmo), gizmo.save!}.should eq({true, true})
  end

  it "finds a soft-deleted row, which the model's queries hide" do
    gizmo = SoftGizmo.find!(id)
    UPDATE_ROWS_DB.exec("REPLACE INTO gizmos (id, name, deleted_at) VALUES (#{id}, 'Ann', CURRENT_TIMESTAMP)")
    gizmo.update!.same?(gizmo).should be_true
  end

  it "locks the row it looks up where the database can" do
    require_postgres!
    LOCKING_DB.locking_gizmos.tap(&.drop!).create!
    gizmo = LockingGizmo.create!(name: "Ann").tap(&.name=("Bob"))
    LOCKING_DB.exec("DELETE FROM locking_gizmos")
    lookups = count_queries { expect_raises(CQL::RecordNotFound) { gizmo.update! } }
    lookups.should eq(["SELECT locking_gizmos.id FROM locking_gizmos WHERE locking_gizmos.id = $1 LIMIT $2 FOR UPDATE"])
    LOCKING_DB.locking_gizmos.drop!
  end
end
