require "./relations/*"

module CQL
  module Relations
    # Define class-level storage for associations
    @@associations = {} of Symbol => Hash(Symbol, Symbol)

    macro included
      include CQL::Relations::BelongsTo
      include CQL::Relations::HasMany
      include CQL::Relations::HasOne
      include CQL::Relations::ManyToMany
    end
  end
end
