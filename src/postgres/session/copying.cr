module CQL::Postgres
  class Session
    private def run_copy_in(sql : String, binary_required : Bool = false, &) : Int64
      rows = 0_i64
      queue_query(sql)
      flush
      until_ready(copy_in: true) do |message|
        case message
        when Wire::Backend::CopyResponse    then accept_copy_in(message, binary_required) { |writer| yield writer }
        when Wire::Backend::CommandComplete then rows = message.rows_affected
        end
      end
      rows
    end

    private def accept_copy_in(message : Wire::Backend::CopyResponse, binary_required : Bool, &) : Nil
      return unless message.direction == 'G'
      stream_copy_in do |writer|
        require_binary(message) if binary_required
        yield writer
      end
    end

    # A binary COPY method on a statement the server runs as text would load
    # garbage (or fail with a confusing message): refuse before any data moves.
    private def require_binary(message : Wire::Backend::CopyResponse) : Nil
      raise ArgumentError.new("the COPY runs in text format; add (FORMAT binary) to the statement") unless message.binary
    end

    private def stream_copy_in(&) : Nil
      writer = CopyIn.new(@out, -> { flush })
      begin
        yield writer
      ensure
        writer.finish
      end
      Wire::Frontend.copy_done(@out)
      flush
    rescue ex
      @out.clear
      Wire::Frontend.copy_fail(@out, "the client aborted the COPY")
      flush
      raise ex
    end

    private def run_copy_out(sql : String, binary_required : Bool = false, &) : Int64
      rows = 0_i64
      queue_query(sql)
      flush
      until_ready do |message|
        case message
        when Wire::Backend::CopyResponse    then require_binary(message) if binary_required
        when Wire::Backend::CopyData        then yield message.data
        when Wire::Backend::CommandComplete then rows = message.rows_affected
        end
      end
      rows
    end
  end
end
