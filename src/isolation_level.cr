module CQL
  # A transaction isolation level, as the SQL standard names it. A database may run a stronger one than asked.
  enum IsolationLevel
    ReadUncommitted
    ReadCommitted
    RepeatableRead
    Serializable

    def to_sql : String
      to_s.underscore.tr("_", " ").upcase
    end
  end
end
