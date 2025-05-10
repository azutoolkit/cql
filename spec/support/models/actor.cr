class Actor
  include CQL::ActiveRecord::Model(Int32)
  db_context schema: UserDB, table: :actors

  property name : String
  property age : Int32

  many_to_many :movies, Movie, join_through: :movies_actor

  def initialize(@name, @age)
  end
end
