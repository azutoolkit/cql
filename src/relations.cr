require "./relations/*"

module Cql
  module Relations
    # Define class-level storage for associations
    @@associations = {} of Symbol => Hash(Symbol, Symbol)

    macro included
      include Cql::Relations::BelongsTo
      include Cql::Relations::HasMany
      include Cql::Relations::HasOne
      include Cql::Relations::ManyToMany
    end
  end
end
