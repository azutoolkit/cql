require "../spec_helper"

ManyLookupDB = CQL::Schema.define(:many_lookup_db, adapter: CQL::Adapter::SQLite, uri: spec_sqlite_uri("many_lookup.db")) do
  table :lookup_teams do
    primary :id, Int64, auto_increment: true
    text :name
  end

  table :lookup_players do
    primary :id, Int64, auto_increment: true
    text :name
    timestamp :deleted_at, null: true
  end

  table :lookup_rosters do
    primary :id, Int64, auto_increment: true
    bigint :lookup_team_id
    bigint :lookup_player_id
  end
end

class LookupPlayer
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::SoftDeletable
  db_context schema: ManyLookupDB, table: :lookup_players

  property name : String = ""
end

class LookupRoster
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: ManyLookupDB, table: :lookup_rosters

  property lookup_team_id : Int64?
  property lookup_player_id : Int64?
end

class LookupTeam
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: ManyLookupDB, table: :lookup_teams

  property name : String = ""

  many_to_many :players, LookupPlayer, join_through: :lookup_roster
end

# Deletes its players (soft-deletable) without callbacks when the team is deleted.
class ReleasingLookupTeam
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: ManyLookupDB, table: :lookup_teams

  property name : String = ""

  many_to_many :players, LookupPlayer, join_through: LookupRoster, foreign_key: :lookup_team_id,
    association_foreign_key: :lookup_player_id, dependent: :delete_all
end

# A soft-deletable player that records whose destroy callbacks ran.
class AuditedLookupPlayer
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::SoftDeletable
  db_context schema: ManyLookupDB, table: :lookup_players

  class_property destroyed_names = [] of String

  property name : String = ""

  before_destroy :audit

  def audit
    self.class.destroyed_names << name
    true
  end
end

class AuditedReleasingLookupTeam
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: ManyLookupDB, table: :lookup_teams

  property name : String = ""

  many_to_many :players, AuditedLookupPlayer, join_through: LookupRoster, foreign_key: :lookup_team_id,
    association_foreign_key: :lookup_player_id, dependent: :delete_all
end

describe "many_to_many lookups" do
  before_each do
    ManyLookupDB.lookup_teams.create!
    ManyLookupDB.lookup_players.create!
    ManyLookupDB.lookup_rosters.create!
  end

  after_each do
    ManyLookupDB.lookup_rosters.drop!
    ManyLookupDB.lookup_players.drop!
    ManyLookupDB.lookup_teams.drop!
  end

  it "skips soft-deleted targets in find, find_by and exists?" do
    team = LookupTeam.create!(name: "Reds")
    gone = LookupPlayer.create!(name: "Gone")
    team.players << gone
    gone.delete!

    team.players.find(name: "Gone").should be_empty
    team.players.find_by(name: "Gone").should be_nil
    team.players.exists?(name: "Gone").should be_false
  end

  it "returns a target once when it is associated twice" do
    team = LookupTeam.create!(name: "Blues")
    player = LookupPlayer.create!(name: "Twice")
    team.players.ids = [player.id!, player.id!]

    team.players.find(name: "Twice").map(&.id).should eq([player.id])
  end

  it "accepts array values" do
    team = LookupTeam.create!(name: "Greens")
    players = %w[A B C].map { |name| LookupPlayer.create!(name: name) }
    players.first(2).each { |player| team.players << player }

    team.players.find(id: players.map(&.id!)).map(&.name).sort!.should eq(["A", "B"])
  end

  it "soft deletes only the players not yet soft deleted with dependent: :delete_all" do
    team = LookupTeam.create!(name: "Golds")
    active = LookupPlayer.create!(name: "Active")
    gone = LookupPlayer.create!(name: "Gone")
    team.players << active
    team.players << gone
    long_ago = Time.utc(2020, 1, 1)
    LookupPlayer.update_by({:id => gone.id!.as(DB::Any)}, {:deleted_at => long_ago.as(DB::Any)})

    ReleasingLookupTeam.find!(team.id!).delete!.should be_true

    LookupPlayer.with_deleted.find!(active.id!).deleted?.should be_true
    LookupPlayer.with_deleted.find!(gone.id!).deleted_at.should eq(long_ago)
    LookupRoster.count.should eq(0)
  end

  it "runs destroy callbacks only for the players not yet soft deleted with dependent: :delete_all" do
    team = LookupTeam.create!(name: "Silvers")
    active = LookupPlayer.create!(name: "Active")
    gone = LookupPlayer.create!(name: "Gone")
    team.players << active
    team.players << gone
    gone.delete!
    AuditedLookupPlayer.destroyed_names.clear

    AuditedReleasingLookupTeam.find!(team.id!).delete!.should be_true

    AuditedLookupPlayer.destroyed_names.should eq(["Active"])
    LookupPlayer.with_deleted.find!(active.id!).deleted?.should be_true
  end
end
