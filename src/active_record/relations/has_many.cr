module CQL::ActiveRecord::Relations
  # Define the has_many association module that will be included in the model
  # to define a one-to-many relationship between two tables in the database
  # and provide methods to manage the association between the two tables and
  # query records in the associated table based on the foreign key value of
  # the parent record.
  #
  # - **param** : name (Symbol) - The name of the association
  # - **param** : type (CQL::Model) - The target model
  # - **param** : foreign_key (Symbol) - The foreign key column in the target table
  # - **return** : Nil
  #
  # **Example**
  #
  # ```
  # class User
  #   include CQL::Model(User, Int64)
  #   property id : Int64
  #   property name : String
  #   has_many :posts, Post, foreign_key: :user_id
  # end
  # ```
  module HasMany
    macro has_many(name, type, foreign_key, cascade = false)
      # Define an instance variable to memoize the collection
      @[DB::Field(ignore: true)]
      @_{{name.id}} : CQL::ActiveRecord::Relations::Collection({{type.id}}, Pk)?

      # Getter that memoizes the collection
      @[DB::Field(ignore: true)]
      def {{name.id}} : CQL::ActiveRecord::Relations::Collection({{type.id}}, Pk)
        @_{{name.id}} ||= CQL::ActiveRecord::Relations::Collection({{type.id}}, Pk).new(
          key: :{{foreign_key.id}},
          id: @id.not_nil!,
          cascade: {{cascade.id}},
          query: {{type.id}}.query.where({{foreign_key.id}}: @id.not_nil!)
        )
      end

      # Method to reload the association and clear the memoized value
      def reload_{{name.id}} : CQL::ActiveRecord::Relations::Collection({{type.id}}, Pk)
        @_{{name.id}} = nil
        {{name.id}}.reload
        {{name.id}}
      end
    end

    # Reload all associations for the model
    # This method will be overridden in models with associations to reload specific associations
    def reload_associations
      # This is a placeholder that will be extended by models with associations
    end
  end
end
