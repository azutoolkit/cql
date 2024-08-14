module Cql::Relations
  module BelongsTo
    # Define the belongs_to association
    macro belongs_to(assoc, foreign_key)
      @{{foreign_key.id}} : {{assoc.camelcase.id}}

      def {{assoc.id}} : {{assoc.camelcase.id}}
        {{assoc.camelcase.id}}.find!(@{{foreign_key.id}})
      end

      property {{assoc.id}}_id : Int64

      def {{assoc.id}}=(record : {{assoc.camelcase.id}})
        @{{foreign_key.id}} = record.id.not_nil!
      end

      def build_{{assoc.id}}(**attributes) : {{assoc.camelcase.id}}
        {{assoc.camelcase.id}}.new(**attributes)
      end

      def create_{{assoc.id}}(**attributes) : {{assoc.camelcase.id}}
        @{{foreign_key.id}} = {{assoc.camelcase.id}}.create!(**attributes)
      end

      def update_{{assoc.id}}(**attributes) : {{assoc.camelcase.id}}
        {{assoc.camelcase.id}}.update(@{{foreign_key.id}}, **attributes)
        movie
      end

      def delete_{{assoc.id}} : Bool
        {{assoc.camelcase.id}}.delete(@{{foreign_key.id}}).rows_affected > 0
      end
    end
  end
end
