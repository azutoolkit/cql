struct CustomerModel
  include DB::Serializable

  property id : Int32
  property name : String
  property city : String
  property balance : Int64
  property created_at : Time
  property updated_at : Time

  def initialize(@id : Int32, @name : String, @city : String, @balance : Int64,
                 @created_at = Time.local, @updated_at = Time.local)
  end
end
