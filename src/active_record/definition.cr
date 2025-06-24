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
        # struct User
        #   include CQL::ActiveRecord::Model
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

        def self.table_columns
          schema.tables[table].columns
        end

        def self.table_column(column : Symbol)
          table_columns[column].expression
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

        # Build a new object of type T with the given attributes
        # - **@param** hash_attrs [Hash(Symbol, DB::Any)] The attributes to use
        # - **@return** [T] The new object
        #
        # **Example** Building a new user object
        #
        # ```
        # User.from_hash({name: "Alice", email: "alice@example.com"})
        # ```
        def self.from_hash(hash_attrs : Hash(Symbol, DB::Any))
          # Create instance using build method with empty fields and then set attributes
          instance = allocate
          instance.initialize
          # Use the existing attributes method to set the hash values
          instance.attributes(hash_attrs) if instance.responds_to?(:attributes)
          instance
        end
      end
    end
  end
end
