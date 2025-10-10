require "db"

module CQL
  # Base error class for all CQL exceptions
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

  # ========== Record Errors ==========

  # Raised when a record is invalid and cannot be saved
  # Contains detailed validation error information
  class RecordInvalid < Error
    # Store validation errors as an array (actual type will be Validations::Error)
    getter validation_errors : Array(NamedTuple(field: Symbol, message: String))?

    def initialize(message : String, @validation_errors : Array(NamedTuple(field: Symbol, message: String))? = nil)
      super(message)
    end

    def error_messages : Array(String)
      @validation_errors.try(&.map(&.[:message])) || [] of String
    end

    def error_fields : Array(Symbol)
      @validation_errors.try(&.map(&.[:field])) || [] of Symbol
    end
  end

  # Raised when a record cannot be saved for reasons other than validation errors
  class RecordNotSaved < Error
  end

  # Raised when a record is not found
  class RecordNotFound < Error
  end

  # Error raised when a record is not found with enhanced context
  class RecordNotFoundError < Error
    getter model_class : String
    getter id : DB::Any

    def initialize(@model_class : String, @id : DB::Any)
      super("Couldn't find #{@model_class} with id=#{@id}")
    end
  end

  # ========== Validation Errors ==========

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

  # ========== Connection Errors ==========

  # Error raised when a connection fails
  class ConnectionError < Error
    def initialize(message : String)
      super("Database connection error: #{message}")
    end
  end

  # ========== Dialect Errors ==========

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

  # ========== Active Record Errors ==========

  # Raised when an attribute operation fails
  class AttributeError < Error
    getter attribute_name : Symbol
    getter value : DB::Any?
    getter expected_type : String?

    def initialize(@attribute_name : Symbol, message : String, @value : DB::Any? = nil, @expected_type : String? = nil)
      full_message = "Attribute '#{@attribute_name}': #{message}"
      full_message += "\nValue: #{@value.inspect}" if @value
      full_message += "\nExpected type: #{@expected_type}" if @expected_type
      super(full_message)
    end
  end

  # Raised when a persistence operation fails
  class PersistenceError < Error
    getter operation : String
    getter model_class : String?

    def initialize(@operation : String, message : String, @model_class : String? = nil)
      full_message = "Persistence error during #{@operation}"
      full_message += " for #{@model_class}" if @model_class
      full_message += ": #{message}"
      super(full_message)
    end
  end

  # Raised when a callback fails or halts execution
  class CallbackError < Error
    getter callback_name : Symbol
    getter callback_type : Symbol

    def initialize(@callback_name : Symbol, @callback_type : Symbol, message : String)
      super("Callback #{@callback_type} '#{@callback_name}' failed: #{message}")
    end
  end

  # Raised when a query operation fails
  class QueryError < Error
    getter sql : String?
    getter params : Array(DB::Any)?

    def initialize(message : String, @sql : String? = nil, @params : Array(DB::Any)? = nil)
      full_message = "Query error: #{message}"
      if sql = @sql
        full_message += "\nSQL: #{sql}"
        full_message += "\nParams: #{@params.inspect}" if @params
      end
      super(full_message)
    end
  end

  # ========== Concurrency Errors ==========

  # Optimistic Lock Error - Raised when a concurrent update has occurred
  class OptimisticLockError < Error
    getter model_class : String?
    getter id : DB::Any?
    getter expected_version : Int32?
    getter actual_version : Int32?

    def initialize(
      message : String = "Record has been modified by another process",
      @model_class : String? = nil,
      @id : DB::Any? = nil,
      @expected_version : Int32? = nil,
      @actual_version : Int32? = nil,
    )
      full_message = message
      if model_class && id
        full_message += " (#{model_class}##{id})"
      end
      if expected_version && actual_version
        full_message += "\nExpected version: #{expected_version}, actual: #{actual_version}"
      end
      super(full_message)
    end
  end

  # ========== Transaction Errors ==========

  # Raised when a transaction operation fails
  class TransactionError < Error
    getter transaction_state : String?

    def initialize(message : String, @transaction_state : String? = nil)
      full_message = "Transaction error: #{message}"
      full_message += " (state: #{@transaction_state})" if @transaction_state
      super(full_message)
    end
  end

  # ========== Migration Errors ==========

  # Raised when a migration operation fails
  class MigrationError < Error
    getter migration_version : Int64?
    getter direction : String?

    def initialize(message : String, @migration_version : Int64? = nil, @direction : String? = nil)
      full_message = "Migration error"
      full_message += " (version: #{@migration_version})" if @migration_version
      full_message += " during #{@direction}" if @direction
      full_message += ": #{message}"
      super(full_message)
    end
  end
end
