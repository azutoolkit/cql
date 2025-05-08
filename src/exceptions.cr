module CQL
  # Error class
  # This class represents an error in the CQL library
  # It provides a message describing the error
  #
  # **Example** Raising an error
  #
  # ```
  # raise CQL::Error.new("Something went wrong")
  # ```
  class Error < Exception
  end

  # Raised when a record is invalid and cannot be saved
  class RecordInvalid < Error
  end

  # Raised when a record cannot be saved for reasons other than validation errors
  class RecordNotSaved < Error
  end

  # Raised when a record is not found
  class RecordNotFound < Error
  end

  # Error raised when a record is not found
  class RecordNotFoundError < Error
    getter model_class : String
    getter id : DB::Any

    def initialize(@model_class : String, @id : DB::Any)
      super("Couldn't find #{@model_class} with id=#{@id}")
    end
  end

  # Error raised when a validation fails
  class ValidationError < Error
    getter errors : Hash(String, Array(String))

    def initialize(@errors : Hash(String, Array(String)))
      message = "Validation failed: " + @errors.map do |field, messages|
        "#{field} #{messages.join(", ")}"
      end.join("; ")

      super(message)
    end
  end

  # Error raised when a connection fails
  class ConnectionError < Error
    def initialize(message : String)
      super("Database connection error: #{message}")
    end
  end

  # Error class for dialect-specific errors
  class DialectError < Error
    getter dialect : String
    getter feature : String
    getter workaround : String?

    def initialize(@dialect : String, @feature : String, @workaround : String? = nil)
      message = "#{@dialect} does not support #{@feature}"
      message += "\n\nWorkaround:\n#{@workaround}" if @workaround
      super(message)
    end
  end

  # Error class specifically for SQLite unsupported features
  class SQLiteUnsupportedFeatureError < DialectError
    def initialize(feature : String, workaround : String? = nil)
      super("SQLite", feature, workaround)
    end
  end

  # Error class specifically for MySQL unsupported features
  class MySqlUnsupportedFeatureError < DialectError
    def initialize(feature : String, workaround : String? = nil)
      super("MySQL", feature, workaround)
    end
  end
end
