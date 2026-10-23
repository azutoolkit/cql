module CQL::Postgres
  class Session
    private def run_copy_in(sql : String, &) : Int64
      rows = 0_i64
      queue_query(sql)
      flush
      until_ready(copy_in: true) do |message|
        case message
        when Wire::Backend::CopyResponse    then stream_copy_in { |writer| yield writer } if message.direction == 'G'
        when Wire::Backend::CommandComplete then rows = message.rows_affected
        end
      end
      rows
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

    private def run_copy_out(sql : String, &) : Int64
      rows = 0_i64
      queue_query(sql)
      flush
      until_ready do |message|
        case message
        when Wire::Backend::CopyData        then yield message.data
        when Wire::Backend::CommandComplete then rows = message.rows_affected
        end
      end
      rows
    end
  end
end
