module Cql
  class Index
    getter columns : Array(Symbol)
    getter unique : Bool
    getter table : Table
    property name : String? = nil

    def initialize(@table : Table, @columns : Array(Symbol), @unique : Bool = false, @name : String? = nil)
    end

    def index_name
      @name || "idx_#{columns.map { |c| c.to_s[0..3] }.join("_")}"
    end
  end
end
