# N+1 detector with direct method calls
# Removes event system overhead for better performance

require "db"
require "./utilities"
require "./config"
require "./unified_report_generator"
require "./interfaces"

module CQL::Performance
  # N+1 query pattern data
  struct NPlusOnePattern
    getter parent_query : String
    getter repeated_query : String
    getter repetition_count : Int32
    getter timestamp : Time = Time.utc
    getter backtrace : Array(String)?

    def initialize(@parent_query, @repeated_query, @repetition_count, @backtrace = nil)
    end
  end

  # N+1 detector without event system
  class NPlusOneDetector < BasePerformanceComponent
    include CQL::Performance::NPlusOneDetectorInterface
    @recent_queries : RecentQueries
    # Entries recorded, capped as the buffer the ring replaced was: a query that takes it past
    # twice the window cuts it back to the window. The detection warm-up still reads it. Markers
    # never cut it, so it saturates just past twice the window, where every value acts the same.
    @recorded : Int32 = 0
    @patterns : Hash(String, NPlusOnePattern) = {} of String => NPlusOnePattern
    @config : Config::Detection
    @detection_window : Int32
    @mutex : CQL::Compat::Mutex = CQL::Compat::Mutex.new

    MAX_PATTERNS = 100

    def initialize(@config : Config::Detection = Config::Detection.new)
      super()
      @detection_window = @config.detection_window
      @recent_queries = RecentQueries.new(@detection_window)
    end

    # Direct method call for query recording
    def record_query(sql : String, normalized_sql : String? = nil) : Void
      return unless @enabled
      return if should_ignore?(sql)

      normalized = normalized_sql || SQLUtils.normalize_sql(sql)
      should_log, log_query, log_count = @mutex.synchronize do
        remember(normalized)
        @recorded = @detection_window if @recorded > @detection_window * 2
        detect_patterns
      end

      if should_log
        log_detection(log_query, log_count)
      end
    end

    # Mark relation loading boundaries
    def start_relation_loading(relation_name : String, parent_model : String) : Void
      return unless @enabled
      @mutex.synchronize do
        remember("-- RELATION START: #{parent_model}.#{relation_name}")
      end
    end

    def end_relation_loading : Void
      return unless @enabled
      @mutex.synchronize do
        remember("-- RELATION END")
      end
    end

    # Get detected patterns
    def patterns : Array(NPlusOnePattern)
      @mutex.synchronize { @patterns.values }
    end

    # Get performance issues
    def issues : Array(Issue)
      @mutex.synchronize do
        @patterns.map do |_, pattern|
          severity = case pattern.repetition_count
                     when 2..5   then :low
                     when 6..20  then :medium
                     when 21..50 then :high
                     else             :critical
                     end

          Issue.new(
            type: :n_plus_one,
            severity: severity,
            message: "N+1 pattern detected: Query repeated #{pattern.repetition_count} times",
            details: {
              "parent_query"   => SQLUtils.truncate_sql(pattern.parent_query),
              "repeated_query" => SQLUtils.truncate_sql(pattern.repeated_query),
              "repetitions"    => pattern.repetition_count.to_s,
            },
            timestamp: pattern.timestamp
          )
        end
      end
    end

    # Clear all data
    def clear : Void
      @mutex.synchronize do
        @recent_queries.clear
        @recorded = 0
        @patterns.clear
        reset
      end
    end

    private def remember(entry : String) : Nil
      @recent_queries.push(entry)
      @recorded = Math.min(@recorded + 1, @detection_window * 2 + 1)
    end

    private def detect_patterns : Tuple(Bool, String, Int32)
      detection = {false, "", 0}
      return detection if @recorded < @config.threshold + 1

      @recent_queries.each_repeated(@config.threshold) do |query, count, offset|
        existing = @patterns[query]?
        next if existing && existing.repetition_count >= count

        store_pattern(query, count, offset)
        detection = {true, query, count} if existing.nil? && @config.strict_mode?
      end
      detection
    end

    # A new or grown pattern goes last, as the latest detected.
    private def store_pattern(query : String, count : Int32, offset : Int32) : Nil
      parent = @recent_queries.query_before(offset) || "Unknown"
      previous = @patterns.delete(query)
      trace = previous.try(&.backtrace)
      trace ||= caller if previous.nil? && @config.capture_backtrace?
      @patterns[query] = NPlusOnePattern.new(parent, query, count, trace)
      @patterns.shift if @patterns.size > MAX_PATTERNS
    end

    private def should_ignore?(sql : String) : Bool
      statement = sql.to_slice
      statement += statement.index { |byte| !byte.unsafe_chr.ascii_whitespace? } || statement.size
      @config.ignore_patterns.any? { |pattern| starts_with_upcased?(statement, pattern.to_slice) }
    end

    private def starts_with_upcased?(statement : Bytes, prefix : Bytes) : Bool
      prefix.size <= statement.size &&
        (0...prefix.size).all? { |i| statement[i].unsafe_chr.upcase(:ascii) == prefix[i].unsafe_chr }
    end

    private def log_detection(query : String, count : Int32)
      Log.warn { "N+1 Query Pattern Detected: #{SQLUtils.truncate_sql(query)} (#{count} times)" }
    end

    # The last `capacity` entries in a fixed ring. Each query in it maps to its count and to the
    # push sequence of its oldest entry. Relation markers take slots but are never counted. A
    # count is deleted at zero, so the counts stay bounded by the window rather than by every
    # statement ever recorded.
    private class RecentQueries
      MARKER = "-- RELATION"

      @head = 0
      @size = 0
      @pushed = 0_i64
      @counts = {} of String => {Int32, Int64}

      def initialize(@capacity : Int32)
        @entries = Array(String).new(@capacity, "")
      end

      def push(entry : String) : Nil
        return if @capacity.zero?
        evict_oldest if @size == @capacity
        unless marker?(entry)
          count, first = @counts[entry]? || {0, @pushed}
          @counts[entry] = {count + 1, first}
        end
        @entries[(@head + @size) % @capacity] = entry
        @size += 1
        @pushed += 1
      end

      # Yields each query counted at least `min_count` times once, at its oldest offset, oldest first.
      def each_repeated(min_count : Int32, & : String, Int32, Int32 ->) : Nil
        @size.times do |offset|
          query = self[offset]
          count, first = @counts[query]? || next
          yield query, count, offset if count >= min_count && first == sequence(offset)
        end
      end

      def query_before(offset : Int32) : String?
        (offset - 1).downto(0) do |earlier|
          entry = self[earlier]
          return entry unless marker?(entry)
        end
      end

      def clear : Nil
        @head = @size = 0
        @counts.clear
        @entries.fill("")
      end

      private def [](offset : Int32) : String
        @entries[(@head + offset) % @capacity]
      end

      private def sequence(offset : Int32) : Int64
        @pushed - @size + offset
      end

      # The evicted entry was its query's oldest, so the query's next entry becomes the oldest.
      private def evict_oldest : Nil
        evicted = @entries[@head]
        @head = (@head + 1) % @capacity
        @size -= 1
        return if marker?(evicted)
        count = @counts[evicted][0] - 1
        if count.zero?
          @counts.delete(evicted)
        else
          @counts[evicted] = {count, first_sequence(evicted)}
        end
      end

      private def first_sequence(query : String) : Int64
        @size.times { |offset| return sequence(offset) if self[offset] == query }
        @pushed
      end

      private def marker?(entry : String) : Bool
        entry.starts_with?(MARKER)
      end
    end
  end
end
