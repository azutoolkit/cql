require "./wire/frontend"

module CQL::Postgres
  # Sends the body of a `COPY ... FROM STDIN`. Anything written is framed as
  # CopyData and handed to the stream whenever a chunk has built up. It is only
  # valid inside the block it was yielded to.
  class CopyIn
    FLUSH_THRESHOLD = 64 * 1024

    def initialize(@buffer : IO::Memory, @flush : Proc(Nil))
      @open = true
    end

    def write(chunk : Bytes) : Nil
      raise Error.new("the COPY stream is only usable inside its block") unless @open
      Wire::Frontend.copy_data(@buffer, chunk)
      @flush.call if @buffer.size >= FLUSH_THRESHOLD
    end

    def <<(text : String) : self
      write(text.to_slice)
      self
    end

    # :nodoc:
    def finish : Nil
      @open = false
    end
  end
end
