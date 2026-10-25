require "db"
require "openssl"
require "./errors"
require "./session"

module CQL::Postgres
  # Transport failures while opening a connection become `DB::ConnectionRefused`,
  # which crystal-db's pool retries and callers already rescue; server errors do not.
  module Refusal
    # *log* writes a warning naming the cause: wanted where crystal-db's pool retries and drops the cause, not on
    # every checkout of an engine pool during an outage (the exception carries the cause).
    def self.translate(log : Bool = true, & : -> T) : T forall T
      yield
    rescue ex : IO::Error | OpenSSL::Error
      refuse(ex, log)
    rescue ex : UnrecognizedStartupReply
      ex.cause.is_a?(IO::Error) ? refuse(ex, log) : raise(ex)
    end

    # crystal-db's pool drops the cause when its retries run out, so say why here (the message names no secret).
    def self.refuse(ex : Exception, log : Bool = true) : NoReturn
      Session::Log.warn { "could not open a PostgreSQL connection: #{ex.message}" } if log
      raise ::DB::ConnectionRefused.new(ex.message, cause: ex)
    end
  end
end
