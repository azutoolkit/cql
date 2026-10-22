require "../exceptions"

module CQL::Postgres
  # Base class of everything the wire driver raises. Driver-built messages never
  # contain credentials or bound values; see `ServerError` for the server's.
  class Error < CQL::Error
  end

  # The bytes on the wire did not follow protocol v3.0.
  class ProtocolError < Error
  end

  # A valid PostgreSQL value Crystal cannot represent (infinite or far-out dates).
  class UnsupportedValue < Error
  end

  # The client could not complete the authentication exchange.
  class AuthenticationError < Error
  end

  # The socket failed or the connection was already closed.
  class ConnectionLost < Error
  end

  # A statement exceeded its time limit and was canceled on the server.
  class QueryTimeout < Error
  end

  class PoolTimeout < Error
  end

  class PoolClosed < Error
  end

  # An ErrorResponse from the server. The server's own wording
  # (`server_message`) and `detail` can quote bound values (a unique violation
  # names the duplicate key, "invalid input syntax" quotes the offending text,
  # a `$1::regclass` cast quotes its argument). `message` therefore uses the
  # server's wording only for SQLSTATE classes known to be value-free and a
  # fixed title otherwise; the raw fields stay available for callers who accept
  # that risk.
  class ServerError < Error
    VALUE_FREE_CLASSES = {"08", "0A", "23", "25", "28", "3D", "53", "54", "55", "57", "58"}
    TITLES             = {
      "42P01" => "undefined table", "42703" => "undefined column", "42601" => "syntax error",
      "42501" => "insufficient privilege", "22P02" => "invalid text representation",
      "40001" => "serialization failure", "40P01" => "deadlock detected", "40" => "transaction rollback",
      "22" => "data exception", "42" => "syntax error or access rule violation", "P0" => "PL/pgSQL error",
    }

    getter severity : String
    getter sqlstate : String
    getter server_message : String
    getter detail : String?
    getter routine : String?
    getter hint : String?
    getter position : Int32?
    getter schema : String?
    getter table : String?
    getter column : String?
    getter constraint : String?

    def initialize(fields : Hash(Char, String))
      @severity = fields['V']? || fields['S']? || "ERROR"
      @sqlstate = fields['C']? || "XX000"
      @server_message = fields['M']? || "unknown error"
      @routine = fields['R']?
      @detail = fields['D']?
      @hint = fields['H']?
      @position = fields['P']?.try(&.to_i?)
      @schema = fields['s']?
      @table = fields['t']?
      @column = fields['c']?
      @constraint = fields['n']?
      super("#{@severity}: #{safe_wording} (SQLSTATE #{@sqlstate})")
    end

    private def safe_wording : String
      return @server_message if VALUE_FREE_CLASSES.includes?(@sqlstate[0, 2])
      TITLES[@sqlstate]? || TITLES[@sqlstate[0, 2]]? || "server error"
    end

    # The server's cached plan became invalid after a schema change; preparing
    # the statement again fixes it.
    def stale_plan? : Bool
      sqlstate == "0A000" && routine == "RevalidateCachedQuery"
    end

    # Subclass per SQLSTATE where one exists, else per SQLSTATE class.
    def self.from(fields : Hash(Char, String)) : ServerError
      code = fields['C']? || ""
      (BY_SQLSTATE[code]? || BY_CLASS[code[0, 2]]? || ServerError).new(fields)
    end
  end

  class IntegrityViolation < ServerError
  end

  class UniqueViolation < IntegrityViolation
  end

  class ForeignKeyViolation < IntegrityViolation
  end

  class NotNullViolation < IntegrityViolation
  end

  class CheckViolation < IntegrityViolation
  end

  class TransactionRollback < ServerError
  end

  class SerializationFailure < TransactionRollback
  end

  class DeadlockDetected < TransactionRollback
  end

  class SyntaxOrAccessError < ServerError
  end

  class UndefinedTable < SyntaxOrAccessError
  end

  class UndefinedColumn < SyntaxOrAccessError
  end

  class InvalidAuthorization < ServerError
  end

  class QueryCanceled < ServerError
  end

  class ServerError
    BY_SQLSTATE = {
      "23505" => UniqueViolation,
      "23503" => ForeignKeyViolation,
      "23502" => NotNullViolation,
      "23514" => CheckViolation,
      "40001" => SerializationFailure,
      "40P01" => DeadlockDetected,
      "42P01" => UndefinedTable,
      "42703" => UndefinedColumn,
      "57014" => QueryCanceled,
    } of String => ServerError.class

    BY_CLASS = {
      "23" => IntegrityViolation,
      "28" => InvalidAuthorization,
      "40" => TransactionRollback,
      "42" => SyntaxOrAccessError,
    } of String => ServerError.class
  end
end
