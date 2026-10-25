require "./result"

module CQL::Postgres
  # Least-recently-used map from SQL text to the statement the server holds
  # for it. Entries over capacity are handed back for closing, never dropped
  # silently, because the server keeps prepared statements until told to close.
  class StatementCache
    # A cached statement and when it was last used, so a hit is one lookup.
    private class Entry
      getter statement : PreparedStatement
      property used : Int64

      def initialize(@statement : PreparedStatement, @used : Int64)
      end
    end

    def initialize(@capacity : Int32)
      @entries = {} of String => Entry
      @counter = 0
      @clock = 0_i64
    end

    def enabled? : Bool
      @capacity > 0
    end

    def next_name : String
      "cql_#{@counter += 1}"
    end

    def fetch(sql : String) : PreparedStatement?
      @entries[sql]?.try do |entry|
        entry.used = tick
        entry.statement
      end
    end

    def store(sql : String, statement : PreparedStatement) : Nil
      @entries[sql] = Entry.new(statement, tick)
    end

    def delete(sql : String) : PreparedStatement?
      @entries.delete(sql).try(&.statement)
    end

    def clear : Nil
      @entries.clear
    end

    # Removes the least recently used statements until *room* more fit, except those in
    # *keep* (statements about to be used), and returns them to be closed.
    def evict(room : Int32, keep : Set(String) = Set(String).new) : Array(PreparedStatement)
      excess = @entries.size + room - @capacity
      return [] of PreparedStatement if excess <= 0

      victims = least_recently_used(excess, keep)
      victims.each { |sql, _| @entries.delete(sql) }
      victims.map { |_, entry| entry.statement }
    end

    def size : Int32
      @entries.size
    end

    # One scan for the usual single victim (a miss on a full cache); a sort only for a batch.
    private def least_recently_used(count : Int32, keep : Set(String)) : Array({String, Entry})
      candidates = @entries.each.reject { |_, entry| keep.includes?(entry.statement.name) }
      return candidates.to_a.sort_by!(&.[1].used).first(count) if count > 1
      candidates.min_by?(&.[1].used).try { |victim| [victim] } || [] of {String, Entry}
    end

    private def tick : Int64
      @clock += 1
    end
  end
end
