require "./base_expression"

module Expression
  # The column's point lies within *meters* of (longitude, latitude).
  class GeoWithin < Condition
    getter column : BaseColumn
    getter longitude : Float64
    getter latitude : Float64
    getter meters : Float64

    def initialize(@column : BaseColumn, @longitude : Float64, @latitude : Float64, @meters : Float64)
      raise ArgumentError.new("longitude must be between -180 and 180") unless longitude.finite? && longitude.abs <= 180
      raise ArgumentError.new("latitude must be between -90 and 90") unless latitude.finite? && latitude.abs <= 90
      raise ArgumentError.new("distance must be finite") unless meters.finite?
      raise ArgumentError.new("distance must not be negative") if meters < 0
    end

    def accept(visitor : Visitor)
      visitor.visit(self)
    end
  end
end
