require "./quoted_name"

module CQL
  # :nodoc:
  abstract class BaseColumn
    include QuotedNameCache

    # A copy of this column owned by *table* (used for CTEs and derived tables).
    abstract def copy_to(table : Table) : BaseColumn

    # Complete declaration copy used by explicit resource bindings.
    abstract def copy_declaration_to(table : Table) : BaseColumn
  end
end
