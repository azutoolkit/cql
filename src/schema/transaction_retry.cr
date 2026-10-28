module CQL
  class Schema
    # Runs `transaction(isolation:, read_only:)` with the block; while `dialect.retryable_transaction_error?` accepts
    # what a run raised, runs it again after a short random pause, up to *attempts* runs. Returns the last run's value
    # (nil after `DB::Rollback`) or raises its error. Only this transaction's work is undone: build or load the records
    # the block changes inside it; a run whose block ended the transaction (`tx.commit` or `tx.rollback`) is not
    # retried; other effects (other connections, emails) run again. Raises `ArgumentError` for *attempts* below 1 and
    # inside a transaction.
    def retrying_transaction(attempts : Int32 = 3, *, isolation : (IsolationLevel | Symbol)? = nil,
                             read_only : Bool = false, & : DB::Transaction -> T) : T? forall T
      raise ArgumentError.new("attempts must be at least 1, got #{attempts}") if attempts < 1
      raise ArgumentError.new("retrying_transaction inside a transaction would retry only a savepoint") if active_frame
      (1..).each do |attempt|
        result = nil
        ended_by_block = false
        transaction(isolation: isolation, read_only: read_only) do |tx|
          result = yield tx
        ensure
          ended_by_block = tx.closed? # after `tx.commit` or `tx.rollback`, work was kept that a retry would repeat
        end
        return result
      rescue ex
        run_again = !ended_by_block && attempt < attempts && dialect.retryable_transaction_error?(ex)
        raise ex unless run_again
        Log.debug &.emit("Retrying transaction", attempt: attempt + 1, error: ex.class.name)
        sleep retry_backoff(attempt)
      end
    end

    # Random below 10 ms, doubling per attempt up to 200 ms, so clashing transactions do not retry in lockstep.
    private def retry_backoff(attempt : Int32) : Time::Span
      Math.min(10.milliseconds * 2 ** Math.min(attempt - 1, 5), 200.milliseconds) * Random.rand
    end
  end
end
