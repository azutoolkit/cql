require "./table"

module CQL
  # A table-shaped view of a statement's select list, so CTEs and subqueries in
  # FROM are addressable by the DSL exactly like schema tables. A table built
  # `inline` also remembers the statement it renders as `(SELECT ...) AS alias`.
  class DerivedTable < Table
    getter subquery : Expression::Statement?

    def initialize(schema : Schema, name : Symbol, statement : Expression::Statement, inline : Bool = false)
      super(name, schema)
      @subquery = statement if inline
      statement.output_columns.each { |column| @columns[column.name] = column.copy_to(self) }
      raise ArgumentError.new("#{name} must select at least one named column") if @columns.empty?
    end

    # Derived tables have no primary key; the first column leads the select list.
    def primary : BaseColumn
      columns.first_value
    end
  end
end
