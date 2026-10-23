require "./result"

module CQL::Postgres
  # The rows of one statement, read from the server `fetch_size` at a time
  # through a portal, so a large result is never held in memory whole. It is an
  # `Iterator`, valid only inside the block of `Session#stream` (the session is
  # locked and the portal open until the block ends).
  class RowStream
    include Iterator(Array(Types::Value))

    getter columns : Array(Column)
    getter tag : String = ""
    getter rows_read : Int64 = 0_i64
    # The most rows ever held at once; never more than the fetch size.
    getter peak_buffered : Int32 = 0

    def initialize(@session : Session, @columns : Array(Column), @fetch_size : Int32)
      @buffer = Deque(Array(Types::Value)).new
      @finished = false
      @aborted = false
      @closed = false
      @completed = false
      @reader = Fiber.current
    end

    def next
      raise Error.new("a stream must be read by the fiber that opened it") unless Fiber.current == @reader
      fetch_more if @buffer.empty? && !@finished
      row = @buffer.shift?
      raise StreamClosed.new("the stream was closed before all its rows were read") if row.nil? && @closed && !@completed
      return stop unless row
      @rows_read += 1
      row
    end

    def rows_affected : Int64
      tag.split(' ').last.to_i64? || 0_i64
    end

    # The server sent every row.
    def finished? : Bool
      @finished
    end

    # The statement failed or the session was dropped; nothing is left to clean up.
    def aborted? : Bool
      @aborted
    end

    # Ends the stream when its block does: rows still buffered can be read,
    # but nothing more is fetched from a session that has moved on.
    protected def close : Nil
      @closed = true
      @finished = true
    end

    protected def add(row : Array(Types::Value)) : Nil
      @buffer << row
      @peak_buffered = @buffer.size if @buffer.size > @peak_buffered
    end

    protected def complete(tag : String) : Nil
      @tag = tag
      @finished = @completed = true
    end

    protected def abort : Nil
      @aborted = @closed = @finished = true
      @buffer.clear
    end

    private def fetch_more : Nil
      @session.fetch_rows(self, @fetch_size)
    end
  end
end
