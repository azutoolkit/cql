struct CustomerModel
  include DB::Serializable

  property id : Int32? = nil
  property name : String
  property city : String
  property balance : Int32
  property created_at : Time
  property updated_at : Time

  def initialize(@id : Int32?, @name : String, @city : String, @balance : Int32,
                 @created_at = Time.local, @updated_at = Time.local)
  end
end
