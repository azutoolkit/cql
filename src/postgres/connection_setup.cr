require "./connection"

module CQL::Postgres
  # :nodoc:
  # A hook can wait outside SQL, so closing its socket alone cannot release the
  # pool slot. The caller owns the deadline; the worker owns the private setup
  # operation. A timed-out worker can never return its connection to the pool.
  module ConnectionSetup
    def self.run(connection : Connection, deadline : Time::Instant?, &hook : -> Nil) : Nil
      return hook.call unless deadline
      remaining = deadline - Time.instant
      expired(connection) unless remaining.positive?
      completed = Channel(Exception?).new(1)
      spawn do
        error = begin
          hook.call
          nil
        rescue ex
          ex
        end
        completed.send(error)
      end
      select
      when error = completed.receive
        expired(connection) if Time.instant >= deadline
        raise error if error
      when timeout(remaining)
        expired(connection)
      end
    end

    private def self.expired(connection : Connection) : NoReturn
      connection.session.hard_close
      raise IO::TimeoutError.new("cannot connect to #{connection.session.config.address}: checkout_timeout expired during connection setup/reset")
    end
  end
end
