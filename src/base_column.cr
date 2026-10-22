module CQL
  # :nodoc:
  abstract class BaseColumn
    # A copy of this column owned by *table* (used for CTEs and derived tables).
    abstract def copy_to(table : Table) : BaseColumn
  end
end
