struct User
  include DB::Serializable

  getter id : Int32
  getter name : String
  getter email : String

  def initialize(@id : Int32, @name : String, @email : String)
  end
end
