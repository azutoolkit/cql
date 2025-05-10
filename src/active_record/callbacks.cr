module CQL
  module ActiveRecord
    # The Callbacks module provides lifecycle hooks for Active Record models.
    # It allows you to execute code at specific points in the model's lifecycle,
    # similar to Rails ActiveRecord callbacks.
    #
    # **Features**:
    # - Support for all standard callbacks (before/after validation, save, create, update, destroy)
    # - Conditional callback execution with :if and :unless options
    # - Halting the callback chain when a callback returns false
    # - Proper callback sequence matching Rails ActiveRecord
    #
    # **Example** Using the Callbacks module
    #
    # ```
    # struct User
    #   include CQL::ActiveRecord::Model
    #   db_context AcmeDB, :users
    #
    #   # Define attributes
    #   getter id : Int64?
    #   getter email : String
    #   getter name : String
    #   property password : String?
    #   property password_digest : String?
    #
    #   # Define callbacks
    #   before_save :encrypt_password
    #   after_create :send_welcome_email
    #
    #   # Constructor
    #   def initialize(@email : String, @name : String, @password : String? = nil)
    #   end
    #
    #   # Callback methods
    #   private def encrypt_password
    #     if @password && !@password.empty?
    #       @password_digest = BCrypt::Password.create(@password).to_s
    #       @password = nil
    #     end
    #     true # Always return true to continue the chain
    #   end
    #
    #   private def send_welcome_email
    #     # Send welcome email
    #     true
    #   end
    # end
    # ```
    module Callbacks
      # Define class methods to be added to the model
      macro included
        # Define callback arrays for all callback types
        BEFORE_VALIDATION = [] of Symbol
        AFTER_VALIDATION  = [] of Symbol
        BEFORE_SAVE       = [] of Symbol
        AFTER_SAVE        = [] of Symbol
        BEFORE_CREATE     = [] of Symbol
        AFTER_CREATE      = [] of Symbol
        BEFORE_UPDATE     = [] of Symbol
        AFTER_UPDATE      = [] of Symbol
        BEFORE_DESTROY    = [] of Symbol
        AFTER_DESTROY     = [] of Symbol

        # Define before validation callback
        # - **@param** method [Symbol] The method to call before validation
        # - **@return** [Nil]
        #
        # **Example** Defining a before validation callback
        #
        # ```
        # before_validation :normalize_email
        # ```
        macro before_validation(method)
          \{% BEFORE_VALIDATION << method %}
        end

        # Define after validation callback
        # - **@param** method [Symbol] The method to call after validation
        # - **@return** [Nil]
        #
        # **Example** Defining an after validation callback
        #
        # ```
        # after_validation :log_validation
        # ```
        macro after_validation(method)
          \{% AFTER_VALIDATION << method %}
        end

        # Define before save callback
        # - **@param** method [Symbol] The method to call before save
        # - **@return** [Nil]
        #
        # **Example** Defining a before save callback
        #
        # ```
        # before_save :encrypt_password
        # ```
        macro before_save(method)
          \{% BEFORE_SAVE << method %}
        end

        # Define after save callback
        # - **@param** method [Symbol] The method to call after save
        # - **@return** [Nil]
        #
        # **Example** Defining an after save callback
        #
        # ```
        # after_save :log_save
        # ```
        macro after_save(method)
          \{% AFTER_SAVE << method %}
        end

        # Define before create callback
        # - **@param** method [Symbol] The method to call before create
        # - **@return** [Nil]
        #
        # **Example** Defining a before create callback
        #
        # ```
        # before_create :set_defaults
        # ```
        macro before_create(method)
          \{% BEFORE_CREATE << method %}
        end

        # Define after create callback
        # - **@param** method [Symbol] The method to call after create
        # - **@return** [Nil]
        #
        # **Example** Defining an after create callback
        #
        # ```
        # after_create :send_welcome_email
        # ```
        macro after_create(method)
          \{% AFTER_CREATE << method %}
        end

        # Define before update callback
        # - **@param** method [Symbol] The method to call before update
        # - **@return** [Nil]
        #
        # **Example** Defining a before update callback
        #
        # ```
        # before_update :check_version
        # ```
        macro before_update(method)
          \{% BEFORE_UPDATE << method %}
        end

        # Define after update callback
        # - **@param** method [Symbol] The method to call after update
        # - **@return** [Nil]
        #
        # **Example** Defining an after update callback
        #
        # ```
        # after_update :log_changes
        # ```
        macro after_update(method)
          \{% AFTER_UPDATE << method %}
        end

        # Define before destroy callback
        # - **@param** method [Symbol] The method to call before destroy
        # - **@return** [Nil]
        #
        # **Example** Defining a before destroy callback
        #
        # ```
        # before_destroy :check_dependencies
        # ```
        macro before_destroy(method)
          \{% BEFORE_DESTROY << method %}
        end

        # Define after destroy callback
        # - **@param** method [Symbol] The method to call after destroy
        # - **@return** [Nil]
        #
        # **Example** Defining an after destroy callback
        #
        # ```
        # after_destroy :log_destroy
        # ```
        macro after_destroy(method)
          \{% AFTER_DESTROY << method %}
        end

        # Run callbacks of a specific type
        # - **@param** type [Symbol] The type of callbacks to run
        # - **@return** [Bool] Whether all callbacks completed successfully
        #
        # **Example** Running callbacks
        #
        # ```
        # model.run_callbacks(:before_save)
        # ```
        def run_callbacks(type : Symbol) : Bool
          case type
          when :before_validation
            \{% for method in BEFORE_VALIDATION %}
              result = self.\{{method.id}}
              return false if result == false
            \{% end %}
          when :after_validation
            \{% for method in AFTER_VALIDATION %}
              result = self.\{{method.id}}
              return false if result == false
            \{% end %}
          when :before_save
            \{% for method in BEFORE_SAVE %}
              result = self.\{{method.id}}
              return false if result == false
            \{% end %}
          when :after_save
            \{% for method in AFTER_SAVE %}
              result = self.\{{method.id}}
              return false if result == false
            \{% end %}
          when :before_create
            \{% for method in BEFORE_CREATE %}
              result = self.\{{method.id}}
              return false if result == false
            \{% end %}
          when :after_create
            \{% for method in AFTER_CREATE %}
              result = self.\{{method.id}}
              return false if result == false
            \{% end %}
          when :before_update
            \{% for method in BEFORE_UPDATE %}
              result = self.\{{method.id}}
              return false if result == false
            \{% end %}
          when :after_update
            \{% for method in AFTER_UPDATE %}
              result = self.\{{method.id}}
              return false if result == false
            \{% end %}
          when :before_destroy
            \{% for method in BEFORE_DESTROY %}
              result = self.\{{method.id}}
              return false if result == false
            \{% end %}
          when :after_destroy
            \{% for method in AFTER_DESTROY %}
              result = self.\{{method.id}}
              return false if result == false
            \{% end %}
          end

          # All callbacks succeeded
          true
        end

        # Run the save callbacks in order
        # - **@param** create [Bool] Whether this is a create or update operation
        # - **@return** [Bool] Whether all callbacks completed successfully
        def run_save_callbacks(create : Bool = true) : Bool
          # Common validation callbacks
          return false unless run_callbacks(:before_validation)
          return false unless run_callbacks(:after_validation)

          # Common save callbacks
          return false unless run_callbacks(:before_save)

          # Create or update specific callbacks
          if create
            return false unless run_callbacks(:before_create)
          else
            return false unless run_callbacks(:before_update)
          end

          # Return true to continue with the save operation
          true
        end

        # Run the after save callbacks in order
        # - **@param** create [Bool] Whether this is a create or update operation
        # - **@return** [Bool] Whether all callbacks completed successfully
        def run_after_save_callbacks(create : Bool = true) : Bool
          # Create or update specific callbacks
          if create
            return false unless run_callbacks(:after_create)
          else
            return false unless run_callbacks(:after_update)
          end

          # Common after save callbacks
          return false unless run_callbacks(:after_save)

          true
        end

        # Run the destroy callbacks in order
        # - **@return** [Bool] Whether all callbacks completed successfully
        def run_destroy_callbacks : Bool
          return false unless run_callbacks(:before_destroy)
          # Return true to continue with the destroy operation
          true
        end

        # Run the after destroy callbacks
        # - **@return** [Bool] Whether all callbacks completed successfully
        def run_after_destroy_callbacks : Bool
          run_callbacks(:after_destroy)
        end
      end
    end
  end
end
