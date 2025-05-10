module CQL
  module ActiveRecord
    module Identifyable
      macro included
        @id : Pk? = nil

        # Identity method for the record ID
        # - **@return** [PrimaryKey] The ID
        #
        # **Example** Getting the ID of a record
        #
        # ```
        # user.id
        # -> Pk | Nil
        # ```
        def id : Pk?
          @id
        end

        # Identity method for the record ID
        # - **@return** [PrimaryKey] The ID
        #
        # **Example** Getting the ID of a record
        #
        # ```
        # user.id!
        # -> 1
        # ```
        def id! : Pk
          @id.not_nil!
        end

        # Set the record's ID
        # - **@param** id [PrimaryKey] The ID
        #
        # **Example** Setting the ID of a record
        #
        # ```
        # user.id = 1
        # ```
        def id=(id : Pk)
          @id = id
        end

        # Identity method for the record ID
        # - **@return** [PrimaryKey] The ID
        #
        # **Example** Getting the ID of a record
        #
        # ```
        # user.id?
        # -> Pk | Nil
        # ```
        def id? : Pk?
          @id
        end
      end
    end
  end
end
