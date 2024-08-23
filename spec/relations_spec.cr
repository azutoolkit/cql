require "./spec_helper"

AcmeDB2 = Cql::Schema.define(:acme_db, adapter: Cql::Adapter::Postgres, uri: ENV["DATABASE_URL"]) do
  table :movies do
    primary :id, Int64, auto_increment: true
    text :title
  end

  table :screenplays do
    primary :id, Int64, auto_increment: true
    bigint :movie_id
    text :content
  end

  table :actors do
    primary :id, Int64, auto_increment: true
    text :name
  end

  table :directors do
    primary :id, Int64, auto_increment: true
    bigint :movie_id
    text :name
  end

  table :movies_actors do
    primary :id, Int64, auto_increment: true
    bigint :movie_id
    bigint :actor_id
  end
end

struct Actor < Cql::Record(Int64)
  db_context AcmeDB2, :actors

  getter id : Int64?
  getter name : String

  def initialize(@name : String)
  end
end

struct Movie < Cql::Record(Int64)
  db_context AcmeDB2, :movies

  has_one :screenplay, Screenplay
  many_to_many :actors, Actor, join_through: :movies_actors
  has_many :directors, Director, foreign_key: :movie_id

  getter id : Int64?
  getter title : String

  def initialize(@title : String)
  end
end

struct Director < Cql::Record(Int64)
  db_context AcmeDB2, :directors

  getter id : Int64?
  getter name : String
  belongs_to :movie, foreign_key: :movie_id

  def initialize(@name : String)
  end
end

struct Screenplay < Cql::Record(Int64)
  db_context AcmeDB2, :screenplays

  belongs_to :movie, foreign_key: :movie_id

  getter id : Int64?
  getter content : String

  def initialize(@movie_id : Int64, @content : String)
  end
end

struct MoviesActors < Cql::Record(Int64)
  db_context AcmeDB2, :movies_actors

  getter id : Int64?
  getter movie_id : Int64
  getter actor_id : Int64

  # has_many :actors, Actor, :actor_id

  def initialize(@movie_id : Int64, @actor_id : Int64)
  end
end

describe Cql::Relations do
  before_each do
    AcmeDB2.movies.create!
    AcmeDB2.screenplays.create!
    AcmeDB2.actors.create!
    AcmeDB2.movies_actors.create!
    AcmeDB2.directors.create!
  end

  after_each do
    AcmeDB2.movies.drop!
    AcmeDB2.screenplays.drop!
    AcmeDB2.actors.drop!
    AcmeDB2.movies_actors.drop!
    AcmeDB2.directors.drop!
  end

  describe "belongs_to" do
    it "defines the belongs_to association" do
      movie_id = Movie.create(title: "The Godfather")
      screenplay_id = Screenplay.create(movie_id: movie_id, content: "The screenplay")
      screenplay = Screenplay.find!(screenplay_id)
      movie = Movie.find!(movie_id)

      screenplay.movie = movie
      screenplay.save

      screenplay.movie.title.should eq "The Godfather"
    end

    it "builds the association" do
      movie_id = Movie.create(title: "The Godfather")
      screenplay_id = Screenplay.create(movie_id: movie_id, content: "The screenplay")
      screenplay = Screenplay.find!(screenplay_id)
      movie = screenplay.build_movie(title: "The Godfather")

      movie.title.should eq "The Godfather"
    end

    it "updates the association" do
      movie_id = Movie.create(title: "The Godfather")
      screenplay_id = Screenplay.create(movie_id: movie_id, content: "The screenplay")
      screenplay = Screenplay.find!(screenplay_id)

      screenplay.movie.title.should eq "The Godfather"
      screenplay.update_movie(title: "The Godfather 10")
      screenplay.movie.title.should eq "The Godfather 10"
    end

    it "deletes the association" do
      movie_id = Movie.create(title: "The Godfather")
      screenplay_id = Screenplay.create(movie_id: movie_id, content: "The screenplay")
      screenplay = Screenplay.find!(screenplay_id)

      screenplay.movie.title.should eq "The Godfather"
      screenplay.delete_movie

      expect_raises DB::NoResultsError do
        screenplay.movie
      end
    end
  end

  describe "has_one" do
    it "defines the has_one association" do
      movie_id = Movie.create(title: "The Godfather")
      screenplay_id = Screenplay.create(movie_id: movie_id, content: "The screenplay")
      movie = Movie.find!(movie_id)
      movie.screenplay = Screenplay.find!(screenplay_id)
      movie.save

      screenplay = movie.screenplay
      screenplay.movie = movie

      screenplay.content.should eq "The screenplay"
    end

    it "builds the association" do
      movie_id = Movie.create(title: "The Godfather")
      movie = Movie.find!(movie_id)
      screenplay = movie.build_screenplay(content: "The screenplay")

      screenplay.content.should eq "The screenplay"
    end

    it "creates the association" do
      movie_id = Movie.create(title: "The Godfather")
      movie = Movie.find!(movie_id)
      screenplay = movie.create_screenplay(content: "The screenplay")

      screenplay.content.should eq "The screenplay"
    end

    it "updates the association" do
      movie_id = Movie.create(title: "The Godfather")
      screenplay_id = Screenplay.create(movie_id: movie_id, content: "The screenplay")
      movie = Movie.find!(movie_id)
      movie.screenplay = Screenplay.find!(screenplay_id)

      movie.screenplay.content.should eq "The screenplay"
      movie.update_screenplay(content: "The screenplay 2")
      movie.screenplay.content.should eq "The screenplay 2"
    end

    it "deletes the association" do
      movie_id = Movie.create(title: "The Godfather")
      screenplay_id = Screenplay.create(movie_id: movie_id, content: "The screenplay")
      movie = Movie.find!(movie_id)
      movie.screenplay = Screenplay.find!(screenplay_id)

      movie.screenplay.content.should eq "The screenplay"
      movie.delete_screenplay

      expect_raises DB::NoResultsError do
        movie.screenplay
      end
    end
  end

  describe "many_to_many" do
    it "defines the many_to_many association" do
      movie_id = Movie.create(title: "The Godfather")
      actor1 = Actor.create(name: "Marlon Brando")
      actor2 = Actor.create(name: "Al Pacino")
      movie = Movie.find!(movie_id)

      movie.actors << Actor.find!(actor1)
      movie.actors << Actor.find!(actor2)

      actors = movie.actors.all
      actors.size.should eq 2
      actors[0].name.should eq "Marlon Brando"
      actors[1].name.should eq "Al Pacino"
    end

    it "adds the association" do
      movie_id = Movie.create(title: "The Godfather")
      movie = Movie.find!(movie_id)

      movie.actors.size.should eq 0
      movie.actors << Actor.new(name: "Marlon Brando")
      movie.actors.size.should eq 1
      movie.actors.reload.size.should eq 1
    end

    it "deletes the association" do
      movie_id = Movie.create(title: "The Godfather")
      actor1 = Actor.create(name: "Marlon Brando")
      actor2 = Actor.create(name: "Al Pacino")
      movie = Movie.find!(movie_id)

      movie.actors << Actor.find!(actor1)
      movie.actors << Actor.find!(actor2)

      actors = movie.actors.all
      actors.size.should eq 2
      actors[0].name.should eq "Marlon Brando"
      actors[1].name.should eq "Al Pacino"

      movie.actors.delete(Actor.find!(actor1))
      movie.actors.reload
      actors = movie.actors.all
      actors.size.should eq 1
      actors[0].name.should eq "Al Pacino"
    end

    it "clears the association" do
      movie_id = Movie.create(title: "The Godfather")
      actor1 = Actor.create(name: "Marlon Brando")
      actor2 = Actor.create(name: "Al Pacino")
      movie = Movie.find!(movie_id)

      movie.actors << Actor.find!(actor1)
      movie.actors << Actor.find!(actor2)

      actors = movie.actors.all
      actors.size.should eq 2
      actors[0].name.should eq "Marlon Brando"
      actors[1].name.should eq "Al Pacino"

      movie.actors.clear
      movie.actors.reload
      actors = movie.actors.all
      actors.size.should eq 0
    end

    it "creates the association" do
      movie_id = Movie.create(title: "The Godfather")
      movie = Movie.find!(movie_id)
      actor = movie.actors.create(name: "Marlon Brando")

      actor.name.should eq "Marlon Brando"
    end
  end

  describe "has_many" do
    it "defines the has_many association" do
      movie_id = Movie.create(title: "The Godfather")
      Director.create(movie_id: movie_id, name: "Francis Ford Coppola")
      Director.create(movie_id: movie_id, name: "Mario Puzo")
      movie = Movie.find!(movie_id)

      directors = movie.directors.all
      directors.size.should eq 2
      directors[0].name.should eq "Francis Ford Coppola"
      directors[1].name.should eq "Mario Puzo"
    end

    it "adds the association" do
      movie_id = Movie.create(title: "The Godfather")
      movie = Movie.find!(movie_id)

      movie.directors.size.should eq 0
      movie.directors << Director.new(name: "Francis Ford Coppola")
      movie.directors.size.should eq 1
      movie.directors.reload.size.should eq 1
    end

    it "deletes the association" do
      movie_id = Movie.create(title: "The Godfather")
      director1 = Director.create(movie_id: movie_id, name: "Francis Ford Coppola")
      Director.create(movie_id: movie_id, name: "Mario Puzo")
      movie = Movie.find!(movie_id)

      directors = movie.directors.all
      directors.size.should eq 2
      directors[0].name.should eq "Francis Ford Coppola"
      directors[1].name.should eq "Mario Puzo"

      movie.directors.delete(director1)
      movie.directors.reload
      directors = movie.directors.all
      directors.size.should eq 1
      directors[0].name.should eq "Mario Puzo"
    end

    it "clears the association" do
      movie_id = Movie.create(title: "The Godfather")
      Director.create(movie_id: movie_id, name: "Francis Ford Coppola")
      Director.create(movie_id: movie_id, name: "Mario Puzo")
      movie = Movie.find!(movie_id)

      directors = movie.directors.all
      directors.size.should eq 2
      directors[0].name.should eq "Francis Ford Coppola"
      directors[1].name.should eq "Mario Puzo"

      movie.directors.clear
      movie.directors.reload
      directors = movie.directors.all
      directors.size.should eq 0
    end

    it "creates the association" do
      movie_id = Movie.create(title: "The Godfather")
      movie = Movie.find!(movie_id)
      director = movie.directors.create(name: "Francis Ford Coppola")

      director.name.should eq "Francis Ford Coppola"
    end

    it "check if the association is empty" do
      movie_id = Movie.create(title: "The Godfather")
      movie = Movie.find!(movie_id)

      movie.directors.empty?.should eq true
      movie.directors << Director.new(name: "Francis Ford Coppola")
      movie.directors.empty?.should eq false
    end
  end
end
