module Expression
  enum LockMode
    Update
    Share
  end

  enum LockWait
    Wait
    SkipLocked
    NoWait
  end

  # `FOR UPDATE | FOR SHARE [SKIP LOCKED | NOWAIT]`.
  struct RowLock
    getter mode : LockMode
    getter wait : LockWait

    def initialize(@mode : LockMode, @wait : LockWait = LockWait::Wait)
    end
  end
end
