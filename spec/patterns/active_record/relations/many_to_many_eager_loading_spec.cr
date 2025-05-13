require "../../../spec_helper"

module CQL::ActiveRecord::Relations
  describe "Many-to-Many Eager Loading" do
    # Setup test data
    before_each do
      TestDB.movies.drop!
      TestDB.actors.drop!
      TestDB.movies_actors.drop!

      TestDB.movies.create!
      TestDB.actors.create!
      TestDB.movies_actors.create!

      # Create test data
      movie1 = Movie.create(title: "The Matrix")
      movie2 = Movie.create(title: "Inception")

      actor1 = Actor.create(name: "Keanu Reeves")
      actor2 = Actor.create(name: "Leonardo DiCaprio")
      actor3 = Actor.create(name: "Carrie-Anne Moss")

      # Create associations
      movie1.actors << actor1
      movie1.actors << actor3
      movie2.actors << actor2
    end

    describe "#preload" do
      it "loads many-to-many associations in separate queries" do
        movies = Movie.all
        query_count = 0

        # Mock the query execution to count queries
        allow(TestDB).to receive(:query) do |sql|
          query_count += 1
          [] of DB::Any
        end

        # Preload actors
        movies.each do |movie|
          movie.actors.preload([:movies])
        end

        # Verify associations are loaded
        movies.each do |movie|
          expect(movie.actors.eager_loaded?(:movies)).to be_true
        end

        # Should be 1 query per movie for actors + 1 query per movie for movies
        expect(query_count).to eq(movies.size * 2)
      end

      it "handles empty collections" do
        movies = [] of Movie
        movies.each do |movie|
          movie.actors.preload([:movies])
        end
        expect(movies).to be_empty
      end

      it "handles non-existent associations" do
        movies = Movie.all
        expect {
          movies.each do |movie|
            movie.actors.preload([:non_existent])
          end
        }.to raise_error(KeyError)
      end
    end

    describe "#includes" do
      it "loads many-to-many associations using JOIN queries" do
        movies = Movie.all
        query_count = 0

        # Mock the query execution to count queries
        allow(TestDB).to receive(:query) do |sql|
          query_count += 1
          [] of DB::Any
        end

        # Include actors
        movies.each do |movie|
          movie.actors.includes([:movies])
        end

        # Verify associations are loaded
        movies.each do |movie|
          expect(movie.actors.eager_loaded?(:movies)).to be_true
        end

        # Should be 1 query per movie for actors with movies
        expect(query_count).to eq(movies.size)
      end

      it "handles empty collections" do
        movies = [] of Movie
        movies.each do |movie|
          movie.actors.includes([:movies])
        end
        expect(movies).to be_empty
      end

      it "handles non-existent associations" do
        movies = Movie.all
        expect {
          movies.each do |movie|
            movie.actors.includes([:non_existent])
          end
        }.to raise_error(KeyError)
      end
    end

    describe "Nested Associations" do
      it "prevents N+1 queries in nested many-to-many associations" do
        movies = Movie.all
        query_count = 0

        # Mock the query execution to count queries
        allow(TestDB).to receive(:query) do |sql|
          query_count += 1
          [] of DB::Any
        end

        # Preload actors and their movies
        movies.each do |movie|
          movie.actors.preload([:movies])
        end

        # Access nested associations
        movies.each do |movie|
          movie.actors.each do |actor|
            actor.movies.each do |nested_movie|
              nested_movie.title
            end
          end
        end

        # Should be 1 query per movie for actors + 1 query per movie for nested movies
        expect(query_count).to eq(movies.size * 2)
      end

      it "prevents N+1 queries in nested many-to-many associations with includes" do
        movies = Movie.all
        query_count = 0

        # Mock the query execution to count queries
        allow(TestDB).to receive(:query) do |sql|
          query_count += 1
          [] of DB::Any
        end

        # Include actors and their movies
        movies.each do |movie|
          movie.actors.includes([:movies])
        end

        # Access nested associations
        movies.each do |movie|
          movie.actors.each do |actor|
            actor.movies.each do |nested_movie|
              nested_movie.title
            end
          end
        end

        # Should be 1 query per movie for actors with nested movies
        expect(query_count).to eq(movies.size)
      end
    end
  end
end
