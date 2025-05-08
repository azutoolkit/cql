class MoviesActor
  include CQL::ActiveRecord::Model(Int32)
  db_context schema: UserDB, table: :movies_actor

  property movie_id : Int32?
  property actor_id : Int32?

  belongs_to :movie, Movie, :movie_id
  belongs_to :actor, Actor, :actor_id

  def initialize(@movie_id, @actor_id)
  end
end
