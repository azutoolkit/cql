require "../spec_helper"

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

      # Handle dependency (destroy)
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
      movie = TestMovie.new("The Matrix", 1999)
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

      # Remove some actors
      actors_to_remove = [actor1, actor2]
      movie.actors.remove(actors_to_remove)

      movie.actors.size.should eq(1)
      movie.actors.first.name.should eq("Carrie-Anne Moss")

      # Verify actors still exist in database
      Actor.find!(actor1.id!).should_not be_nil
      Actor.find!(actor2.id!).should_not be_nil
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
      movie = TestMovie.new("The Matrix", 1999)
      movie.create!

      actor = Actor.new("Keanu Reeves", 58)
      actor.create!

      # Try to delete non-associated record
      result = movie.actors.delete(actor)
      result.should be_nil
    end

    it "handles delete with non-existent ID" do
      movie = TestMovie.new("The Matrix", 1999)
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
      movie = TestMovie.new("The Matrix", 1999)
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
end
