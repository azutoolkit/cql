module Sql
  class ForeignKey
    getter name : Symbol
    getter columns : Array(Symbol)
    getter table : Symbol
    getter references : Array(Symbol)
    getter on_delete : String = "NO ACTION"
    getter on_update : String = "NO ACTION"

    def initialize(
      @name : Symbol,
      @columns : Array(Symbol),
      @table : Symbol,
      @references : Array(Symbol),
      @on_delete : String = "NO ACTION",
      @on_update : String = "NO ACTION"
    )
    end
  end
end
