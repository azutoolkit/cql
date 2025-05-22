class Movie
  include CQL::ActiveRecord::Model(Int32)
  db_context schema: UserDB, table: :movies

  property title : String
  property release_year : Int32

  many_to_many :actors, Actor, join_through: MoviesActor, cascade: true

  def initialize(@title, @release_year)
  end
end
