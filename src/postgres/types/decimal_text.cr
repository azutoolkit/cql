module CQL::Postgres::Types
  # A `numeric` value kept as the exact decimal text PostgreSQL sent, so no
  # precision is lost. Use `BigDecimal.new(numeric.to_s)` when `big` is loaded.
  struct DecimalText
    getter text : String

    def initialize(@text : String)
    end

    def to_s(io : IO) : Nil
      io << @text
    end

    def to_f : Float64
      @text.to_f
    end

    def nan? : Bool
      @text == "NaN"
    end
  end
end
