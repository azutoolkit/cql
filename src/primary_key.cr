module Sql
  class PrimaryKey(T) < Column(T)
    getter auto_increment : Bool = true
    getter unique : Bool = true
    @as_name : String?

    def initialize(
      @name : Symbol = :id,
      @type : PrimaryKeyType = Int64.class,
      @as_name : String? = nil,
      @auto_increment : Bool = true,
      @unique : Bool = true,
      @default : DB::Any = nil
    )
    end

    def as_name
      @as_name || "pk_#{name.to_s[0..2]}_#{self.object_id}"
    end
  end
end
