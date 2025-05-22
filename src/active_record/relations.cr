require "./relations/*"

module CQL
  module ActiveRecord
    module Relations
      macro included
        include CQL::ActiveRecord::Relations::AssociationRegistry
        include CQL::ActiveRecord::Relations::HasMany
        include CQL::ActiveRecord::Relations::HasOne
        include CQL::ActiveRecord::Relations::BelongsTo
        include CQL::ActiveRecord::Relations::ManyToMany
      end
    end
  end
end
