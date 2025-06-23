require "../spec_helper"

describe CQL::ActiveRecord::Relations::ManyToMany do
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

  it "returns the associated actors" do
    movie = Movie.new("The Matrix", 1999)
    movie.create!

    actor1 = Actor.new(
      name: "Keanu Reeves",
      age: 58
    )
    actor1.create!

    actor2 = Actor.new(
      name: "Laurence Fishburne",
      age: 62
    )
    actor2.create!

    # Create associations
    MoviesActor.new(
      movie_id: movie.id!,
      actor_id: actor1.id!
    ).create!

    MoviesActor.new(
      movie_id: movie.id!,
      actor_id: actor2.id!
    ).create!

    movie_actors = movie.actors
    movie_actors.should be_a(CQL::ActiveRecord::Relations::ManyCollection(Actor, MoviesActor, Int32))
    movie_actors.size.should eq(2)
    movie_actors.all.any? { |actor| actor.name == "Keanu Reeves" }.should be_true
    movie_actors.all.any? { |actor| actor.name == "Laurence Fishburne" }.should be_true
  end

  it "creates a new associated actor" do
    movie = Movie.new("The Matrix", 1999)
    movie.create!

    actor = movie.actors.create(
      name: "Carrie-Anne Moss",
      age: 55
    )

    actor.should be_a(Actor)
    actor.name.should eq("Carrie-Anne Moss")
    actor.age.should eq(55)
    actor.id.should_not be_nil

    movie.actors.reload

    # Verify association was created
    movie.actors.size.should eq(1)
    movie.actors.first.name.should eq("Carrie-Anne Moss")
  end

  it "creates multiple associated actors" do
    movie = Movie.new("The Matrix", 1999)
    movie.create!

    movie.actors.create(
      name: "Keanu Reeves",
      age: 58
    )

    movie.actors.create(
      name: "Laurence Fishburne",
      age: 62
    )

    movie.actors.reload

    movie.actors.size.should eq(2)
    movie.actors.all.any? { |actor| actor.name == "Keanu Reeves" }.should be_true
    movie.actors.all.any? { |actor| actor.name == "Laurence Fishburne" }.should be_true
  end

  it "returns empty array when no associated actors exist" do
    movie = Movie.new("The Matrix", 1999)
    movie.create!
    movie.actors.reload
    movie.actors.should be_a(CQL::ActiveRecord::Relations::ManyCollection(Actor, MoviesActor, Int32))
    movie.actors.size.should eq(0)
  end

  it "deletes all associated actors" do
    movie = Movie.new("The Matrix", 1999)
    movie.create!

    actor1 = Actor.new(
      name: "Keanu Reeves",
      age: 58
    )
    actor1.create!

    actor2 = Actor.new(
      name: "Laurence Fishburne",
      age: 62
    )
    actor2.create!

    # Create associations
    MoviesActor.new(
      movie_id: movie.id!,
      actor_id: actor1.id!
    ).create!

    MoviesActor.new(
      movie_id: movie.id!,
      actor_id: actor2.id!
    ).create!

    movie.actors.clear
    movie.actors.should be_empty
  end

  it "counts associated actors" do
    movie = Movie.new("The Matrix", 1999)
    movie.create!

    actor1 = Actor.new(
      name: "Keanu Reeves",
      age: 58
    )
    actor1.create!

    actor2 = Actor.new(
      name: "Laurence Fishburne",
      age: 62
    )
    actor2.create!

    # Create associations
    MoviesActor.new(
      movie_id: movie.id!,
      actor_id: actor1.id!
    ).create!

    MoviesActor.new(
      movie_id: movie.id!,
      actor_id: actor2.id!
    ).create!

    movie.actors.reload
    movie.actors.size.should eq(2)
  end

  it "finds actors by attributes" do
    movie = Movie.new("The Matrix", 1999)
    movie.create!

    actor1 = Actor.new(
      name: "Keanu Reeves",
      age: 58
    )
    actor1.create!

    actor2 = Actor.new(
      name: "Laurence Fishburne",
      age: 62
    )
    actor2.create!

    # Create associations
    MoviesActor.new(
      movie_id: movie.id!,
      actor_id: actor1.id!
    ).create!

    MoviesActor.new(
      movie_id: movie.id!,
      actor_id: actor2.id!
    ).create!

    found_actors = movie.actors.find(name: "Keanu Reeves")
    found_actors.size.should eq(1)
    found_actors.first.name.should eq("Keanu Reeves")
  end

  it "checks if actor exists by attributes" do
    movie = Movie.new("The Matrix", 1999)
    movie.create!

    actor = Actor.new(
      name: "Keanu Reeves",
      age: 58
    )
    actor.create!

    # Create association
    MoviesActor.new(
      movie_id: movie.id!,
      actor_id: actor.id!
    ).create!

    movie.actors.reload
    movie.actors.exists?(name: "Keanu Reeves").should be_true
    movie.actors.exists?(name: "Non-existent Actor").should be_false
  end

  it "deletes a specific actor" do
    movie = Movie.new("The Matrix", 1999)
    movie.create!

    actor = Actor.new(
      name: "Keanu Reeves",
      age: 58
    )
    actor.create!

    # Create association
    MoviesActor.new(
      movie_id: movie.id!,
      actor_id: actor.id!
    ).create!

    movie.actors.delete(actor)
    movie.actors.size.should eq(0)
  end

  it "deletes an actor by id" do
    movie = Movie.new("The Matrix", 1999)
    movie.create!

    actor = Actor.new(
      name: "Keanu Reeves",
      age: 58
    )
    actor.create!

    # Create association
    MoviesActor.new(
      movie_id: movie.id!,
      actor_id: actor.id!
    ).create!

    movie.actors.delete(actor.id.not_nil!)
    movie.actors.size.should eq(0)
  end

  it "sets actors by ids" do
    movie = Movie.new("The Matrix", 1999)
    movie.create!

    actor1 = Actor.new(
      name: "Keanu Reeves",
      age: 58
    )
    actor1.create!

    actor2 = Actor.new(
      name: "Laurence Fishburne",
      age: 62
    )
    actor2.create!

    movie.actors.ids = [actor1.id!, actor2.id!]
    movie.actors.reload

    movie.actors.size.should eq(2)
    movie.actors.all.map(&.id!).sort!.should eq([actor1.id!, actor2.id!].sort)
  end

  it "reloads actors after changes" do
    movie = Movie.new("The Matrix", 1999)
    movie.create!

    actor = Actor.new(
      name: "Keanu Reeves",
      age: 58
    )
    actor.create!

    # Create association
    MoviesActor.new(
      movie_id: movie.id!,
      actor_id: actor.id!
    ).create!

    movie.actors.reload
    movie.actors.size.should eq(1)

    # Update the actor name, save it, and reload the movie
    actor.name = "Keanu Charles Reeves"
    actor.save!
    movie.actors.reload

    movie.actors.size.should eq(1)
    movie.actors.first.name.should eq("Keanu Charles Reeves")
  end

  it "returns actor ids" do
    movie = Movie.new("The Matrix", 1999)
    movie.create!

    actor1 = Actor.new(
      name: "Keanu Reeves",
      age: 58
    )
    actor1.create!

    actor2 = Actor.new(
      name: "Laurence Fishburne",
      age: 62
    )
    actor2.create!

    # Create associations
    MoviesActor.new(
      movie_id: movie.id!,
      actor_id: actor1.id!
    ).create!

    MoviesActor.new(
      movie_id: movie.id!,
      actor_id: actor2.id!
    ).create!

    movie.actors.ids.sort.should eq([actor1.id!, actor2.id!].sort)
  end

  it "cascades deletion when cascade option is true" do
    movie = Movie.new("The Matrix", 1999)
    movie.create!

    actor = Actor.new(
      name: "Keanu Reeves",
      age: 58
    )
    actor.create!

    # Create association
    MoviesActor.new(
      movie_id: movie.id!,
      actor_id: actor.id!
    ).create!

    # Delete the actor and verify it's gone from the database
    movie.actors.delete(actor)

    movie.actors.reload

    Actor.count.as(Int64).should eq(0)
    MoviesActor.count.as(Int64).should eq(0)
    movie.actors.size.should eq(0)
  end
end
