module Sql
  class Check
    property name : String
    property condition : String

    def initialize(@name : String, @condition : String)
    end
  end
end
