require "spec"
require "sqlite3"
require "./src/cql"
require "./spec/support/**"

# Setup test database
UserDB.movies.create!
UserDB.actors.create!
UserDB.movies_actor.create!

# Create test data
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

puts "Movie ID: #{movie.id!}"
puts "Actor ID: #{actor.id!}"
puts "Actor name: #{actor.name}"

# Test exists? method
puts "\nTesting exists? method:"
puts "movie.actors.exists?(name: \"Keanu Reeves\"): #{movie.actors.exists?(name: "Keanu Reeves")}"
puts "movie.actors.exists?(name: \"Non-existent Actor\"): #{movie.actors.exists?(name: "Non-existent Actor")}"

# Let's also check what's in the database
puts "\nChecking database contents:"
puts "Actors in database:"
Actor.all.each do |a|
  puts "  - ID: #{a.id}, Name: #{a.name}"
end

puts "\nMoviesActor associations:"
MoviesActor.all.each do |ma|
  puts "  - Movie ID: #{ma.movie_id}, Actor ID: #{ma.actor_id}"
end

# Cleanup
UserDB.movies_actor.drop!
UserDB.actors.drop!
UserDB.movies.drop!
