module Sql
  class Index
    getter columns : Array(Symbol)
    getter unique : Bool
    getter table : Table

    def initialize(@table : Table, @columns : Array(Symbol), @unique : Bool = false)
    end

    def index_name
      "idx_#{columns.map { |c| c.to_s[0..3] }.join("_")}"
    end
  end
end
