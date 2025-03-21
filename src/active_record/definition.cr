module CQL
  module ActiveRecord
    module Definition
      macro included
        @@schema : CQL::Schema? = nil
        @@table : Symbol? = nil

        # Define the schema and table for the model
        # - **@param** schema [CQL::Schema] The schema to use
        # - **@param** table [Symbol] The table to use
        # - **@return** [Nil]
        #
        # **Example** Defining the schema and table
        #
        # ```
        # struct User < CQL::Model(Int64)
        #   db_context AcmeDB, :users
        # end
        # ```
        def self.db_context(schema : CQL::Schema, table : Symbol)
          @@schema = schema
          @@table = table
        end

        # Return the schema for the model
        # - **@return** [CQL::Schema] The schema
        #
        # **Example** Fetching the schema
        #
        # ```
        # User.schema
        # ```
        def self.schema
          @@schema.not_nil!
        end

        # Return the table for the model
        # - **@return** [Symbol] The table
        # **Example** Fetching the table
        # ```
        # User.table
        # ```
        def self.table
          @@table.not_nil!
        end

        # Return the adapter for the schema
        # - **@return** [CQL::Adapter] The adapter
        # **Example** Fetching the adapter
        # ```
        # User.adapter
        # ```
        def self.adapter
          schema.adapter
        end

        # Build a new object of type T with the given attributes
        # - **@param** attrs [Hash(Symbol, DB::Any)] The attributes to use
        # - **@return** [T] The new object
        #
        # **Example** Building a new user object
        #
        # ```
        # User.build(name: "Alice", email: "alice@example.com")
        # ```
        #
        def self.build(**fields)
          new(**fields)
        end
      end
    end
  end
end
