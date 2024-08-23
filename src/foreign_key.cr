module Cql
  # A foreign key constraint
  # This class represents a foreign key constraint
  # It provides methods for setting the columns, table, and references
  # It also provides methods for setting the on delete and on update actions
  #
  # **Example** Creating a new foreign key
  #
  # ```
  # Schema.define do
  #   table :users do
  #     column :id, Int32, primary: true
  #     column :name, String
  #   end
  # end
  #
  # table :posts do
  #   column :id, Int32, primary: true
  #   column :user_id, Int32
  #   foreign_key [:user_id], :users, [:id]
  # end
  # ```
  class ForeignKey
    # :nodoc:
    getter name : Symbol
    # :nodoc:
    getter columns : Array(Symbol)
    # :nodoc:
    getter table : Symbol
    # :nodoc:
    getter references : Array(Symbol)
    # :nodoc:
    getter on_delete : String = "NO ACTION"
    # :nodoc:
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
