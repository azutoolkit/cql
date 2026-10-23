require "./result"

module CQL::Postgres
  # Least-recently-used map from SQL text to the statement the server holds
  # for it. Entries over capacity are handed back for closing, never dropped
  # silently, because the server keeps prepared statements until told to close.
  class StatementCache
    def initialize(@capacity : Int32)
      @entries = {} of String => PreparedStatement
      @counter = 0
    end

    def enabled? : Bool
      @capacity > 0
    end

    def next_name : String
      "cql_#{@counter += 1}"
    end

    def fetch(sql : String) : PreparedStatement?
      @entries.delete(sql).try { |statement| @entries[sql] = statement }
    end

    def store(sql : String, statement : PreparedStatement) : Nil
      @entries[sql] = statement
    end

    def delete(sql : String) : PreparedStatement?
      @entries.delete(sql)
    end

    def clear : Nil
      @entries.clear
    end

    # Removes the oldest statements until *room* more fit, except those in
    # *keep* (statements about to be used), and returns them to be closed.
    def evict(room : Int32, keep : Set(String) = Set(String).new) : Array(PreparedStatement)
      evicted = [] of PreparedStatement
      @entries.each_value do |statement|
        break if @entries.size - evicted.size + room <= @capacity
        evicted << statement unless keep.includes?(statement.name)
      end
      evicted.each { |statement| @entries.reject! { |_, cached| cached.name == statement.name } }
      evicted
    end

    def size : Int32
      @entries.size
    end
  end
end
