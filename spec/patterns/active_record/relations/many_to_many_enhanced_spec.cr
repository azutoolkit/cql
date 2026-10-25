require "../spec_helper"

# A target whose primary key is not named `id`; only generated SQL is checked
LabelNoPkDB = CQL::Schema.define(
  :label_no_pk_db,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3:///tmp/many_to_many_label_no_pk_spec.db"
) do
  table :labels do
    primary :label_no, Int32
    text :name
  end

  table :movie_labels do
    primary :id, Int32
    integer :movie_id
    integer :label_no
  end
end

class NumberedLabel
  include CQL::ActiveRecord::Model(Int32)
  db_context schema: LabelNoPkDB, table: :labels

  property name : String = ""

  def initialize
  end
end

class MovieLabel
  include CQL::ActiveRecord::Model(Int32)
  db_context schema: LabelNoPkDB, table: :movie_labels

  property movie_id : Int32?
  property label_no : Int32?

  def initialize
  end
end

# The Matrix (Keanu, Laurence) and Speed (Keanu)
def seed_matrix_and_speed : {Movie, Movie}
  movie = Movie.new("The Matrix", 1999)
  movie.create!
  other_movie = Movie.new("Speed", 1994)
  other_movie.create!

  keanu = Actor.new("Keanu Reeves", 58)
  keanu.create!
  laurence = Actor.new("Laurence Fishburne", 62)
  laurence.create!
  MoviesActor.new(movie.id!, keanu.id!).create!
  MoviesActor.new(movie.id!, laurence.id!).create!
  MoviesActor.new(other_movie.id!, keanu.id!).create!

  {movie, other_movie}
end

def many_to_many_isolation_selects(& : ->) : Array(String)
  statements = [] of String
  CQL::Telemetry.subscribe("many_to_many_isolation") do |event|
    statements << event.sql if event.operation == :select
  end
  begin
    yield
  ensure
    CQL::Telemetry.unsubscribe("many_to_many_isolation")
  end
  statements
end

# A movies owner that deletes its actors' rows without callbacks.
class ActorDeletingMovie
  include CQL::ActiveRecord::Model(Int32)
  db_context schema: UserDB, table: :movies

  property title : String

  many_to_many :actors, Actor, join_through: MoviesActor, foreign_key: :movie_id,
    association_foreign_key: :actor_id, dependent: :delete_all
end

describe "CQL::ActiveRecord::Relations::ManyToMany Enhanced Tests" do
  before_each do
    UserDB.actors.drop! rescue nil
    UserDB.movies.drop! rescue nil
    UserDB.movies_actor.drop! rescue nil

    UserDB.movies.create!
    UserDB.actors.create!
    UserDB.movies_actor.create!
  end

  after_each do
    UserDB.movies_actor.drop!
    UserDB.actors.drop!
    UserDB.movies.drop!
  end

  describe "dependency strategies" do
    it "destroys both join records and target records when dependent: :destroy" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      actor1 = Actor.new("Keanu Reeves", 58)
      actor1.create!
      actor2 = Actor.new("Laurence Fishburne", 62)
      actor2.create!

      # Create associations
      movie.actors << actor1
      movie.actors << actor2

      movie.actors.size.should eq(2)

      actor1_id = actor1.id!
      actor2_id = actor2.id!

      # Handle dependency (destroy) - this should destroy both join records and target records
      movie.handle_actors_dependency

      # Verify actors are deleted from database
      expect_raises(DB::NoResultsError) do
        Actor.find!(actor1_id)
      end

      expect_raises(DB::NoResultsError) do
        Actor.find!(actor2_id)
      end

      # Verify join records are also deleted
      MoviesActor.count.should eq(0)
    end

    it "deletes only join records when dependent: :delete_all" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      actor1 = Actor.new("Keanu Reeves", 58)
      actor1.create!
      actor2 = Actor.new("Laurence Fishburne", 62)
      actor2.create!

      # Create associations
      movie.actors << actor1
      movie.actors << actor2

      movie.actors.size.should eq(2)

      # Clear with delete (should only delete join records)
      movie.actors.clear_with_delete

      # Verify actors still exist
      Actor.find!(actor1.id!).should_not be_nil
      Actor.find!(actor2.id!).should_not be_nil

      # Verify join records are deleted
      MoviesActor.count.should eq(0)
      movie.actors.size.should eq(0)
    end

    it "deletes the targets of a delete_all collection in one statement" do
      movie = Movie.new("Heat", 1995)
      movie.create!
      actors = (1..3).map { |i| Actor.new("Actor #{i}", 30 + i).tap(&.create!) }
      actors.each { |actor| movie.actors << actor }
      bystander = Actor.new("Bystander", 40)
      bystander.create!
      collection = CQL::ActiveRecord::Relations::ManyCollection(Actor, MoviesActor, Int32).new(
        key: :movie_id, id: movie.id!, target_key: :actor_id, dependent: :delete_all
      )

      deletes = count_queries(:delete) { collection.clear_with_delete }

      deletes.size.should eq(2) # the join rows, then the three actors
      Actor.all.map(&.id!).should eq([bystander.id!])
      MoviesActor.count.should eq(0)
    end

    it "only clears join records when dependent: :nullify" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      actor1 = Actor.new("Keanu Reeves", 58)
      actor1.create!
      actor2 = Actor.new("Laurence Fishburne", 62)
      actor2.create!

      # Create associations
      movie.actors << actor1
      movie.actors << actor2

      movie.actors.size.should eq(2)

      # Clear join records only
      movie.actors.clear_join_records

      # Verify actors still exist
      Actor.find!(actor1.id!).should_not be_nil
      Actor.find!(actor2.id!).should_not be_nil

      # Verify join records are deleted
      MoviesActor.count.should eq(0)
      movie.actors.size.should eq(0)
    end
  end

  describe "dependent strategies when the parent is deleted" do
    it "loads the targets with their own ids, not the join rows' ids, and destroys only those" do
      other = Movie.new("Other", 2000)
      other.create!
      actors = %w[First Second Third].map { |name| Actor.new(name, 40).tap(&.create!) }
      actors.each { |actor| other.actors << actor }
      movie = Movie.new("The Matrix", 1999)
      movie.create!
      movie.actors << actors.first

      Movie.find!(movie.id!).actors.all.map(&.id).should eq([actors.first.id])

      Movie.find!(movie.id!).delete!.should be_true

      Actor.find?(actors.first.id!).should be_nil
      actors[1..].each { |actor| Actor.find?(actor.id!).should_not be_nil }
    end

    it "removes the join rows and keeps the movies when an actor is deleted" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!
      actor = Actor.new("Keanu Reeves", 58)
      actor.create!
      other_actor = Actor.new("Carrie-Anne Moss", 55)
      other_actor.create!
      movie.actors << actor
      movie.actors << other_actor

      Actor.find!(actor.id!).delete!.should be_true

      MoviesActor.where(actor_id: actor.id!).count.should eq(0)
      MoviesActor.where(actor_id: other_actor.id!).count.should eq(1)
      Movie.find?(movie.id!).should_not be_nil
    end

    it "removes the join rows and the actors with dependent: :destroy when a movie is deleted" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!
      actor = Actor.new("Keanu Reeves", 58)
      actor.create!
      movie.actors << actor

      Movie.find!(movie.id!).delete!.should be_true

      MoviesActor.count.should eq(0)
      Actor.find?(actor.id!).should be_nil
      Movie.find?(movie.id!).should be_nil
    end

    it "removes the join rows and the actors' rows with dependent: :delete_all when a movie is deleted" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!
      actor = Actor.new("Keanu Reeves", 58)
      actor.create!
      movie.actors << actor

      ActorDeletingMovie.find!(movie.id!).delete!.should be_true

      MoviesActor.count.should eq(0)
      Actor.find?(actor.id!).should be_nil
      Movie.find?(movie.id!).should be_nil
    end
  end

  describe "collection operations" do
    it "adds existing records to association" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      actor1 = Actor.new("Keanu Reeves", 58)
      actor1.create!
      actor2 = Actor.new("Laurence Fishburne", 62)
      actor2.create!

      # Add actors using <<
      movie.actors << actor1
      movie.actors << actor2

      movie.actors.size.should eq(2)

      # Verify join records exist
      MoviesActor.count.should eq(2)

      # Verify actors are properly associated
      movie.actors.all.map(&.name).sort!.should eq(["Keanu Reeves", "Laurence Fishburne"])
    end

    it "concatenates multiple records" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      actor1 = Actor.new("Keanu Reeves", 58)
      actor1.create!
      actor2 = Actor.new("Laurence Fishburne", 62)
      actor2.create!
      actor3 = Actor.new("Carrie-Anne Moss", 55)
      actor3.create!

      # Concatenate actors
      actors_to_add = [actor1, actor2, actor3]
      movie.actors.concat(actors_to_add)

      movie.actors.size.should eq(3)
      movie.actors.all.map(&.name).sort!.should eq(["Carrie-Anne Moss", "Keanu Reeves", "Laurence Fishburne"])
    end

    it "removes multiple records from association" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      actor1 = Actor.new("Keanu Reeves", 58)
      actor1.create!
      actor2 = Actor.new("Laurence Fishburne", 62)
      actor2.create!
      actor3 = Actor.new("Carrie-Anne Moss", 55)
      actor3.create!

      # Add all actors
      movie.actors << actor1
      movie.actors << actor2
      movie.actors << actor3

      movie.actors.size.should eq(3)

      # Remove some actors (they will be destroyed due to dependent: :destroy)
      actors_to_remove = [actor1, actor2]
      movie.actors.remove(actors_to_remove)

      movie.actors.size.should eq(1)
      movie.actors.first.name.should eq("Carrie-Anne Moss")

      # Verify removed actors are deleted from database (due to dependent: :destroy)
      expect_raises(DB::NoResultsError) do
        Actor.find!(actor1.id!)
      end

      expect_raises(DB::NoResultsError) do
        Actor.find!(actor2.id!)
      end

      # Verify remaining actor still exists
      Actor.find!(actor3.id!).should_not be_nil
    end

    it "checks if association includes specific records" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      actor1 = Actor.new("Keanu Reeves", 58)
      actor1.create!
      actor2 = Actor.new("Laurence Fishburne", 62)
      actor2.create!
      actor3 = Actor.new("Carrie-Anne Moss", 55)
      actor3.create!

      # Add only some actors
      movie.actors << actor1
      movie.actors << actor2

      movie.actors.includes?(actor1).should be_true
      movie.actors.includes?(actor2).should be_true
      movie.actors.includes?(actor3).should be_false
    end

    it "checks includes without loading collection" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      actor1 = Actor.new("Keanu Reeves", 58)
      actor1.create!
      actor2 = Actor.new("Laurence Fishburne", 62)
      actor2.create!

      # Create association directly in database
      MoviesActor.new(movie.id!, actor1.id!).create!

      # Check includes without loading the collection
      movie.actors.includes?(actor1).should be_true
      movie.actors.includes?(actor2).should be_false
    end
  end

  describe "join table operations" do
    it "manages join table records correctly" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      actor1 = Actor.new("Keanu Reeves", 58)
      actor1.create!
      actor2 = Actor.new("Laurence Fishburne", 62)
      actor2.create!

      # Initially no join records
      MoviesActor.count.should eq(0)

      # Add actors
      movie.actors << actor1
      movie.actors << actor2

      # Should have 2 join records
      MoviesActor.count.should eq(2)

      # Remove one actor
      movie.actors.delete(actor1)

      # Should have 1 join record
      MoviesActor.count.should eq(1)

      # Clear all
      movie.actors.clear

      # Should have no join records
      MoviesActor.count.should eq(0)
    end

    it "prevents duplicate associations" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      actor = Actor.new("Keanu Reeves", 58)
      actor.create!

      # Add actor twice
      movie.actors << actor
      movie.actors << actor

      # Should only have one association
      movie.actors.size.should eq(1)
      MoviesActor.count.should eq(1)
    end

    it "handles setting IDs correctly" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      actor1 = Actor.new("Keanu Reeves", 58)
      actor1.create!
      actor2 = Actor.new("Laurence Fishburne", 62)
      actor2.create!
      actor3 = Actor.new("Carrie-Anne Moss", 55)
      actor3.create!

      # Add one actor first
      movie.actors << actor1
      movie.actors.size.should eq(1)

      # Set IDs (should replace existing associations)
      movie.actors.ids = [actor2.id!, actor3.id!]

      movie.actors.size.should eq(2)
      movie.actors.all.map(&.name).sort!.should eq(["Carrie-Anne Moss", "Laurence Fishburne"])

      # Verify join records are correct
      MoviesActor.count.should eq(2)
    end

    it "gets IDs without loading full records" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      actor1 = Actor.new("Keanu Reeves", 58)
      actor1.create!
      actor2 = Actor.new("Laurence Fishburne", 62)
      actor2.create!

      # Create associations directly in database
      MoviesActor.new(movie.id!, actor1.id!).create!
      MoviesActor.new(movie.id!, actor2.id!).create!

      # Get IDs without loading collection
      ids = movie.actors.ids.sort
      ids.should eq([actor1.id!, actor2.id!].sort)
    end
  end

  describe "count and existence checks" do
    it "counts associations without loading them" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      actor1 = Actor.new("Keanu Reeves", 58)
      actor1.create!
      actor2 = Actor.new("Laurence Fishburne", 62)
      actor2.create!

      # Create associations directly in database
      MoviesActor.new(movie.id!, actor1.id!).create!
      MoviesActor.new(movie.id!, actor2.id!).create!

      # Count should work without loading
      movie.actors_count.should eq(2)
    end

    it "checks if any associations exist without loading them" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      # No associations yet
      movie.actors_any?.should be_false

      # Create association
      actor = Actor.new("Keanu Reeves", 58)
      actor.create!
      MoviesActor.new(movie.id!, actor.id!).create!

      # Now should have associations
      movie.actors_any?.should be_true
    end

    it "checks if specific record is included" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      actor1 = Actor.new("Keanu Reeves", 58)
      actor1.create!
      actor2 = Actor.new("Laurence Fishburne", 62)
      actor2.create!

      # Create association for actor1 only
      MoviesActor.new(movie.id!, actor1.id!).create!

      # Check inclusion
      movie.actors_include?(actor1).should be_true
      movie.actors_include?(actor2).should be_false
    end

    it "answers empty? on an unloaded collection with one LIMIT select through the join table" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!
      other_movie = Movie.new("Speed", 1994)
      other_movie.create!
      actor = Actor.new("Keanu Reeves", 58)
      actor.create!
      MoviesActor.new(other_movie.id!, actor.id!).create!

      statements = many_to_many_isolation_selects { movie.actors.empty?.should be_true }
      statements.size.should eq(1)
      statements.first.should contain("movies_actor")
      statements.first.should contain("LIMIT ?")
      statements.first.should_not contain("COUNT(")

      MoviesActor.new(movie.id!, actor.id!).create!
      movie.actors.empty?.should be_false
    end
  end

  describe "single-query lookups" do
    it "answers exists?, find and find_by with one query each" do
      movie = Movie.new("Ronin", 1998)
      movie.create!
      other = Movie.new("Leon", 1994)
      other.create!
      deniro = Actor.new("De Niro", 55).tap(&.create!)
      reno = Actor.new("Reno", 50).tap(&.create!)
      movie.actors << deniro
      other.actors << reno
      actors = movie.actors

      count_queries { actors.exists?(name: "De Niro").should be_true }.size.should eq(1)
      count_queries { actors.exists?(name: "Reno").should be_false }.size.should eq(1)
      count_queries { actors.find(name: "De Niro").map(&.id).should eq([deniro.id]) }.size.should eq(1)
      count_queries { actors.find_by(name: "Reno").should be_nil }.size.should eq(1)
      actors.find_by(id: deniro.id!).try(&.name).should eq("De Niro")
      actors.find(id: reno.id!).should be_empty
      actors.find.map(&.id).should eq([deniro.id])
      actors.find_by.try(&.id).should eq(deniro.id)
    end
  end

  describe "query operations" do
    it "finds associated records with attributes" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      actor1 = Actor.new("Keanu Reeves", 58)
      actor1.create!
      actor2 = Actor.new("Laurence Fishburne", 62)
      actor2.create!

      # Create associations
      movie.actors << actor1
      movie.actors << actor2

      # Find by name
      found_actors = movie.actors.find(name: "Keanu Reeves")
      found_actors.size.should eq(1)
      found_actors.first.name.should eq("Keanu Reeves")

      # Find by age
      found_actors = movie.actors.find(age: 62)
      found_actors.size.should eq(1)
      found_actors.first.name.should eq("Laurence Fishburne")
    end

    it "finds first associated record with attributes" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      actor1 = Actor.new("Keanu Reeves", 58)
      actor1.create!
      actor2 = Actor.new("Laurence Fishburne", 62)
      actor2.create!

      # Create associations
      movie.actors << actor1
      movie.actors << actor2

      # Find by name
      found_actor = movie.actors.find_by(name: "Keanu Reeves")
      found_actor.should_not be_nil
      found_actor.not_nil!.name.should eq("Keanu Reeves")

      # Find non-existent
      found_actor = movie.actors.find_by(name: "Non-existent Actor")
      found_actor.should be_nil
    end

    it "checks existence with attributes" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      actor1 = Actor.new("Keanu Reeves", 58)
      actor1.create!
      actor2 = Actor.new("Laurence Fishburne", 62)
      actor2.create!

      # Create associations
      movie.actors << actor1

      # Check existence
      movie.actors.exists?(name: "Keanu Reeves").should be_true
      movie.actors.exists?(name: "Laurence Fishburne").should be_false
    end
  end

  describe "error handling" do
    it "raises error for unsaved record when adding to association" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      unsaved_actor = Actor.new("Keanu Reeves", 58)
      # Don't save the actor

      expect_raises(CQL::ActiveRecord::Relations::BaseRelation::UnsavedRecord) do
        movie.actors << unsaved_actor
      end
    end

    it "handles empty collection gracefully" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      movie.actors.should be_empty
      movie.actors.size.should eq(0)
      movie.actors.ids.should be_empty
    end

    it "handles delete with non-existent record" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      actor = Actor.new("Keanu Reeves", 58)
      actor.create!

      # Try to delete non-associated record
      result = movie.actors.delete(actor)
      result.should be_nil
    end

    it "handles delete with non-existent ID" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      # Try to delete non-existent ID
      result = movie.actors.delete(999999)
      result.should be_nil
    end

    it "raises error for unsaved parent record" do
      movie = Movie.new("The Matrix", 1999)
      # Don't save the movie

      actor = Actor.new("Keanu Reeves", 58)
      actor.create!

      expect_raises(CQL::ActiveRecord::Relations::BaseRelation::UnsavedRecord) do
        movie.actors << actor
      end
    end
  end

  describe "build operations" do
    it "builds new records without saving" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      actor = movie.actors.build(name: "Keanu Reeves", age: 58)

      actor.should be_a(Actor)
      actor.name.should eq("Keanu Reeves")
      actor.age.should eq(58)
      actor.id.should be_nil # Not persisted yet

      # Should not be associated yet
      movie.actors.size.should eq(0)
    end

    it "creates and associates new records" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      actor = movie.actors.create(name: "Keanu Reeves", age: 58)

      actor.should be_a(Actor)
      actor.name.should eq("Keanu Reeves")
      actor.age.should eq(58)
      actor.id.should_not be_nil # Persisted

      # Should be associated
      movie.actors.size.should eq(1)
      movie.actors.first.id.should eq(actor.id)
    end

    it "creates and associates existing records" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      actor = Actor.new("Keanu Reeves", 58)
      # Don't save the actor yet

      created_actor = movie.actors.create(actor)

      created_actor.should be_a(Actor)
      created_actor.id.should_not be_nil # Should be persisted now
      created_actor.name.should eq("Keanu Reeves")

      # Should be associated
      movie.actors.size.should eq(1)
      movie.actors.first.id.should eq(created_actor.id)
    end
  end

  describe "convenience methods" do
    it "provides add and remove methods" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      actor1 = Actor.new("Keanu Reeves", 58)
      actor1.create!
      actor2 = Actor.new("Laurence Fishburne", 62)
      actor2.create!

      # Add using convenience method
      movie.add_actor(actor1).should be_true
      movie.add_actor(actor2).should be_true

      movie.actors.size.should eq(2)

      # Remove using convenience method
      movie.remove_actor(actor1).should be_true
      movie.actors.size.should eq(1)
      movie.actors.first.name.should eq("Laurence Fishburne")
    end

    it "provides find methods" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      actor1 = Actor.new("Keanu Reeves", 58)
      actor1.create!
      actor2 = Actor.new("Laurence Fishburne", 62)
      actor2.create!

      # Create associations
      movie.actors << actor1
      movie.actors << actor2

      # Find actors
      found_actors = movie.find_actors(age: 58)
      found_actors.size.should eq(1)
      found_actors.first.name.should eq("Keanu Reeves")

      # Find first actor
      found_actor = movie.find_actors_by(name: "Laurence Fishburne")
      found_actor.should_not be_nil
      found_actor.not_nil!.name.should eq("Laurence Fishburne")
    end
  end

  describe "cache behavior" do
    it "reloads association when requested" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      actor = Actor.new("Keanu Reeves", 58)
      actor.create!

      # Load empty collection
      movie.actors.size.should eq(0)
      movie.actors_loaded?.should be_true

      # Create association outside of collection
      MoviesActor.new(movie.id!, actor.id!).create!

      # Should still show empty until reloaded
      movie.actors.size.should eq(0)

      # Reload
      movie.reload_actors

      # Now should show the association
      movie.actors.size.should eq(1)
    end

    it "clears cache when requested" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!

      # Load collection
      movie.actors.size.should eq(0)
      movie.actors_loaded?.should be_true

      # Clear cache
      movie.clear_actors_cache

      # Should no longer be loaded
      movie.actors_loaded?.should be_false
    end
  end

  describe "shared query isolation" do
    it "keeps the join table parent predicate single across count, reload and chained queries" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!
      other_movie = Movie.new("Speed", 1994)
      other_movie.create!

      keanu = Actor.new("Keanu Reeves", 58)
      keanu.create!
      laurence = Actor.new("Laurence Fishburne", 62)
      laurence.create!
      sandra = Actor.new("Sandra Bullock", 60)
      sandra.create!
      MoviesActor.new(movie.id!, keanu.id!).create!
      MoviesActor.new(movie.id!, laurence.id!).create!
      MoviesActor.new(other_movie.id!, keanu.id!).create!
      MoviesActor.new(other_movie.id!, sandra.id!).create!

      actors = movie.actors
      statements = many_to_many_isolation_selects do
        actors.count.should eq(2)
        actors.reload.size.should eq(2)
        actors.limit(1).all(Actor).size.should eq(1)
        actors.reload.map(&.name).sort!.should eq(["Keanu Reeves", "Laurence Fishburne"])
      end

      statements.size.should eq(4)
      statements.first.should contain("COUNT(")
      statements[1..].each(&.should_not contain("COUNT("))
      statements.map(&.scan("movies_actor.movie_id = ?").size).should eq([1, 1, 1, 1])
    end

    it "scopes reload and count to the parent even when given an unscoped query" do
      movie = Movie.new("The Matrix", 1999)
      movie.create!
      other_movie = Movie.new("Speed", 1994)
      other_movie.create!

      keanu = Actor.new("Keanu Reeves", 58)
      keanu.create!
      sandra = Actor.new("Sandra Bullock", 60)
      sandra.create!
      MoviesActor.new(movie.id!, keanu.id!).create!
      MoviesActor.new(other_movie.id!, sandra.id!).create!

      actors = CQL::ActiveRecord::Relations::ManyCollection(Actor, MoviesActor, Int32).new(
        key: :movie_id,
        id: movie.id!,
        target_key: :actor_id,
        query: CQL::Query.new(Actor.schema).from(Actor.table)
      )

      actors.reload.map(&.name).should eq(["Keanu Reeves"])
      actors.count.should eq(1)
    end

    it "numbers the join table subquery's parent predicate before the caller's conditions on Postgres" do
      actors = CQL::ActiveRecord::Relations::ManyCollection(Actor, MoviesActor, Int32).new(
        key: :movie_id, id: 7, target_key: :actor_id
      )

      actors.where(name: "Keanu Reeves").to_sql(Expression::Generator.new(CQL::Adapter::Postgres))
        .should eq({
          "SELECT actors.id, actors.name, actors.age, actors.created_at, actors.updated_at FROM actors " \
          "WHERE (actors.id IN (SELECT movies_actor.actor_id FROM movies_actor WHERE movies_actor.movie_id = $1)) " \
          "AND (actors.name = $2)",
          [7, "Keanu Reeves"] of DB::Any,
        })
    end

    it "matches the join rows on the target table's declared primary key" do
      labels = CQL::ActiveRecord::Relations::ManyCollection(NumberedLabel, MovieLabel, Int32).new(
        key: :movie_id, id: 7, target_key: :label_no
      )

      labels.where(name: "Noir").to_sql(Expression::Generator.new(CQL::Adapter::Postgres))
        .should eq({
          "SELECT labels.label_no, labels.name FROM labels " \
          "WHERE (labels.label_no IN (SELECT movie_labels.label_no FROM movie_labels WHERE movie_labels.movie_id = $1)) " \
          "AND (labels.name = $2)",
          [7, "Noir"] of DB::Any,
        })
    end
  end

  describe "bulk unlinking" do
    it "delete_all removes only this movie's join rows and keeps the actors" do
      movie, other_movie = seed_matrix_and_speed

      movie.actors.delete_all.should eq(2)

      MoviesActor.count.should eq(1)
      Actor.count.should eq(2)
      movie.actors.reload.should be_empty
      other_movie.actors.reload.map(&.name).should eq(["Keanu Reeves"])
    end

    it "nullify_all removes only this movie's join rows and keeps the actors" do
      movie, other_movie = seed_matrix_and_speed

      movie.actors.nullify_all.should eq(2)

      MoviesActor.count.should eq(1)
      Actor.count.should eq(2)
      movie.actors.reload.should be_empty
      other_movie.actors.reload.map(&.name).should eq(["Keanu Reeves"])
    end

    it "clear_with_destroy destroys the actors of a collection that was never loaded" do
      seeded, _ = seed_matrix_and_speed
      movie = Movie.find!(seeded.id!)

      movie.actors.clear_with_destroy

      Actor.count.should eq(0)
    end

    it "delete_all empties an already loaded collection" do
      movie, _ = seed_matrix_and_speed
      movie.actors.all.size.should eq(2)

      movie.actors.delete_all

      movie.actors.loaded?.should be_true
      movie.actors.size.should eq(0)
    end
  end
end
