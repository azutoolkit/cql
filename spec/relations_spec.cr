require "./spec_helper"
AcmeDB2 = Cql::Schema.build(
  :acme_db,
  adapter: Cql::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]) do
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

  table :movies_actors do
    primary :id, Int64, auto_increment: true
    bigint :movie_id
    bigint :actor_id
  end
end

struct Actor
  include Cql::Record(Actor, Int64)
  include Cql::Relations

  define AcmeDB2, :actors

  getter id : Int64?
  getter name : String

  def initialize(@name : String)
  end
end

struct Movie
  include Cql::Record(Movie, Int64)
  include Cql::Relations

  define AcmeDB2, :movies

  has_one :screenplay, Screenplay
  many_to_many :actors, Actor, join_through: :movies_actors

  getter id : Int64?
  getter title : String

  def initialize(@title : String)
  end
end

struct Screenplay
  include Cql::Record(Screenplay, Int64)
  include Cql::Relations

  define AcmeDB2, :screenplays

  belongs_to :movie, foreign_key: :movie_id

  getter id : Int64?
  getter content : String

  def initialize(@movie_id : Int64, @content : String)
  end
end

struct MoviesActors
  include Cql::Record(MoviesActors, Int64)

  define AcmeDB2, :movies_actors

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
  end

  after_each do
    AcmeDB2.movies.drop!
    AcmeDB2.screenplays.drop!
    AcmeDB2.actors.drop!
    AcmeDB2.movies_actors.drop!
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

      actors = movie.actors << Actor.find!(actor1)
      actors = movie.actors << Actor.find!(actor2)
      actors = movie.actors.all
      actors.size.should eq 2
      actors[0].name.should eq "Marlon Brando"
      actors[1].name.should eq "Al Pacino"
    end

    # it "adds the association" do
    #   movie_id = Movie.create(title: "The Godfather")
    #   movie = Movie.find!(movie_id)
    #   actor = movie.actors << Actor.new(name: "Marlon Brando")

    #   actor.name.should eq "Marlon Brando"
    # end

    # it "deletes the association" do
    #   movie_id = Movie.create(title: "The Godfather")
    #   actor1 = Actor.create(name: "Marlon Brando")
    #   actor2 = Actor.create(name: "Al Pacino")
    #   movie = Movie.find!(movie_id)

    #   movie << Actor.find!(actor1)
    #   movie << Actor.find!(actor2)

    #   actors = movie.actors

    #   actors.size.should eq 2
    #   actors.first.name.should eq "Marlon Brando"
    #   actors.last.name.should eq "Al Pacino"

    #   movie.delete(actors.first)

    #   actors = movie.actors

    #   actors.size.should eq 1
    #   actors.last.name.should eq "Al Pacino"
    # end
  end
end
