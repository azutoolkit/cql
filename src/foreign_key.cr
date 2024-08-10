module Cql
  # A foreign key constraint
  # This class represents a foreign key constraint
  # It provides methods for setting the columns, table, and references
  # It also provides methods for setting the on delete and on update actions
  #
  # **Example** Creating a new foreign key
  #
  # ```
  # schema.build do
  # table :users do
  #  column :id, Int32, primary: true
  # column :name, String
  # end
  #
  # table :posts do
  # column :id, Int32, primary: true
  # column :user_id, Int32
  # foreign_key [:user_id], :users, [:id]
  # end
  # ```
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
