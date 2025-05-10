module CQL
  # Error handling module that follows CQL's error handling principles
  module ErrorHandler
    # Handle errors according to method convention
    # Methods with ! should raise, methods without ! should return nil
    macro handle_error(method_name)
      {% if method_name.ends_with?("!") %}
        # For methods ending with !, propagate the error
        def {{method_name.id}}(*args, **named_args)
          begin
            super(*args, **named_args)
          rescue e : CQL::RecordNotFoundError
            # Re-raise record not found errors
            raise e
          rescue e : CQL::Error
            # Re-raise CQL-specific errors
            raise e
          rescue e : DB::Error
            # Propagate database errors
            raise e
          rescue e : Exception
            # Wrap other exceptions
            raise CQL::Error.new("Error in #{{{method_name.stringify}}}: #{e.message}")
          end
        end
      {% else %}
        # For methods without !, return nil on failure
        def {{method_name.id}}(*args, **named_args)
          begin
            super(*args, **named_args)
          rescue e : CQL::RecordNotFoundError
            # Return nil for record not found
            nil
          rescue e : CQL::Error
            # Log the error and return nil
            # TODO: Add proper logging
            nil
          rescue e : DB::Error
            # Propagate database connection errors
            raise CQL::ConnectionError.new(e.message.to_s)
          rescue e : Exception
            # Return nil for other exceptions
            nil
          end
        end
      {% end %}
    end

    # Handle dialect-specific errors
    # This can be used to catch and handle dialect-specific errors
    # like SQLiteUnsupportedFeatureError
    def self.handle_dialect_error(error : CQL::DialectError)
      # Log the error
      # TODO: Add proper logging

      # Return a helpful message
      message = "#{error.dialect} does not support #{error.feature}"
      if error.workaround
        message += "\n\nWorkaround:\n#{error.workaround}"
      end

      message
    end
  end
end
