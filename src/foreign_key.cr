require "./base_column"
require "./table"

module CQL
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
    # Name of the foreign key constraint (optional, often auto-generated).
    getter name : String?

    # The table this foreign key constraint belongs to.
    getter table : CQL::Table

    # The column(s) in the current table that make up the foreign key.
    getter columns : Array(Symbol)

    # The table that the foreign key references.
    getter references_table : Symbol

    # The column(s) in the referenced table.
    getter references_columns : Array(Symbol)

    # Action to perform on delete (e.g., :cascade, :restrict, :set_null, :no_action).
    getter on_delete : Symbol

    # Action to perform on update (e.g., :cascade, :restrict, :set_null, :no_action).
    getter on_update : Symbol

    def initialize(
      @table : CQL::Table,
      @columns : Array(Symbol),
      @references_table : Symbol,
      @references_columns : Array(Symbol),
      @name : String? = nil,
      @on_delete : Symbol = :no_action,
      @on_update : Symbol = :no_action,
    )
      # Basic validation
      raise ArgumentError.new("Foreign key columns cannot be empty") if @columns.empty?
      raise ArgumentError.new("Referenced table cannot be empty") if @references_table.to_s.empty?
      raise ArgumentError.new("Referenced columns cannot be empty") if @references_columns.empty?
      raise ArgumentError.new("Number of columns must match number of referenced columns") if @columns.size != @references_columns.size
    end
  end
end
