require "./base_column"
require "./table"

module CQL
  # A foreign key constraint: the local columns, the referenced table and columns,
  # and the `ON DELETE` / `ON UPDATE` actions. Declare one with `Table#foreign_key`
  # in a table block, or add one later with `AlterTable#foreign_key`.
  #
  # **Example** Declaring a foreign key
  #
  # ```
  # schema.table :comments do
  #   primary :id, Int64
  #   column :post_id, Int64
  #   foreign_key [:post_id], references: :posts, references_columns: [:id], on_delete: :cascade
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
