module CQL
  module ActiveRecord
    module Relations
      module BelongsTo
      # Define the belongs_to association
      macro belongs_to(assoc, klass, foreign_key)
        # Register the association
        register_association({{assoc}}, :belongs_to, {{klass}}, {{foreign_key}})

        property {{foreign_key.id}} : Int32? = nil

        def {{assoc.id}} : {{klass.id}}?
          return nil if @{{foreign_key.id}}.nil?
          {{klass.id}}.find!(@{{foreign_key.id}}.not_nil!)
        end

        def {{assoc.id}}=(record : {{klass.id}})
          @{{foreign_key.id}} = record.id.not_nil!
        end

        def build_{{assoc.id}}(**attributes) : {{klass.id}}
          {{klass.id}}.new(**attributes)
        end

        def create_{{assoc.id}}(**attributes) : {{klass.id}}
          record = {{klass.id}}.new(**attributes)
          record.create!
          @{{foreign_key.id}} = record.id.not_nil!
          record
        end

        def update_{{assoc.id}}(**attributes) : {{klass.id}}
          return raise "Cannot update nil association" if @{{foreign_key.id}}.nil?
          record = {{klass.id}}.find!(@{{foreign_key.id}}.not_nil!)
          record.update!(**attributes)
          record
        end

        def delete_{{assoc.id}} : Bool
          return false if @{{foreign_key.id}}.nil?
          {{klass.id}}.delete!(@{{foreign_key.id}}.not_nil!).rows_affected > 0
        end
      end
      end
    end
  end
end
