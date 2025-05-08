struct CustomerModel
  include DB::Serializable

  property id : Int32? = nil
  property name : String
  property email : String = ""
  property city : String = ""
  property balance : Int32 = 0

  property created_at : Time = Time.local
  property updated_at : Time = Time.local

  def initialize(@id : Int32?,
                 @name : String = "",
                 @email : String = "",
                 @city : String = "",
                 @balance : Int32 = 0,
                 @created_at = Time.local,
                 @updated_at = Time.local)
  end
end
