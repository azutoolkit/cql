module CQL
  module ActiveRecord
    # Primary keys as bound values for `WHERE id IN (...)` statements.
    module IdChunks
      # Yields *ids* (deduplicated, UUIDs as strings) in chunks of at most *size*.
      def self.each(ids : Array, size : Int32, &) : Nil
        ids.uniq.each_slice(size) do |chunk|
          yield chunk.map { |id| id.is_a?(UUID) ? id.to_s.as(DB::Any) : id.as(DB::Any) }
        end
      end
    end
  end
end
