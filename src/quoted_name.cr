module CQL
  # A table or column name quoted for one dialect. Kept as one immutable object, so a fiber that
  # reads it while another replaces it sees the old or the new one (a pointer-sized store), never
  # a mix of the two; two fibers quoting at once only compute the same text twice.
  class QuotedName
    getter dialect : Expression::BaseDialect
    getter name : Symbol
    getter text : String

    def initialize(@dialect : Expression::BaseDialect, @name : Symbol, @text : String)
    end
  end

  # Remembers the quoted form of a table's or column's name (for schemas with
  # `quote_identifiers: true`), so rendering it again is a comparison instead of a quote.
  # Another dialect, or a renamed table or column, quotes it afresh.
  module QuotedNameCache
    @quoted : QuotedName? = nil

    # :nodoc:
    # Named so no column can shadow it: tables reach their columns through `method_missing`.
    def __quoted_name(dialect : Expression::BaseDialect, name : Symbol) : String
      cached = @quoted
      return cached.text if cached && cached.dialect.same?(dialect) && cached.name == name
      dialect.quote_identifier(name.to_s).tap { |text| @quoted = QuotedName.new(dialect, name, text) }
    end
  end
end
