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
end
