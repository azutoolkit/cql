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

    def initialize(@parent_query, @repeated_query, @repetition_count)
    end
  end

  # N+1 detector without event system
  class NPlusOneDetector < BasePerformanceComponent
    include CQL::Performance::NPlusOneDetectorInterface
    @recent_queries : Array(String) = [] of String
    @patterns : Array(NPlusOnePattern) = [] of NPlusOnePattern
    @config : Config::Detection
    @detection_window : Int32 = 10 # Look at last N queries

    def initialize(@config : Config::Detection = Config::Detection.new)
      super()
    end

    # Direct method call for query recording
    def record_query(sql : String) : Void
      return unless @enabled
      return if should_ignore?(sql)

      normalized = SQLUtils.normalize_sql(sql)
      @recent_queries << normalized

      # Keep window size manageable
      if @recent_queries.size > @detection_window * 2
        @recent_queries = @recent_queries.last(@detection_window)
      end

      detect_patterns
    end

    # Mark relation loading boundaries
    def start_relation_loading(relation_name : String, parent_model : String) : Void
      return unless @enabled
      # Add marker to help identify relation loading patterns
      @recent_queries << "-- RELATION START: #{parent_model}.#{relation_name}"
    end

    def end_relation_loading : Void
      return unless @enabled
      @recent_queries << "-- RELATION END"
    end

    # Get detected patterns
    def patterns : Array(NPlusOnePattern)
      @patterns.dup
    end

    # Get performance issues
    def issues : Array(Issue)
      @patterns.map do |pattern|
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

    # Clear all data
    def clear : Void
      @recent_queries.clear
      @patterns.clear
      reset
    end

    private def detect_patterns
      return if @recent_queries.size < @config.threshold + 1

      # Look for repeated queries in recent window
      last_queries = @recent_queries.last(@detection_window)

      # Count query frequencies
      query_counts = {} of String => Int32
      last_queries.each do |query|
        next if query.starts_with?("-- RELATION")
        query_counts[query] = (query_counts[query]? || 0) + 1
      end

      # Find queries that appear multiple times
      query_counts.each do |query, count|
        next if count < @config.threshold

        # Try to find parent query
        parent = find_parent_query(query, last_queries)

        # Check if this is a new pattern or update existing
        existing = @patterns.find { |pattern| pattern.repeated_query == query }
        if existing.nil?
          @patterns << NPlusOnePattern.new(parent, query, count)
          log_detection(query, count) if @config.strict_mode?
        elsif existing.repetition_count < count
          # Update count if increased
          @patterns.delete(existing)
          @patterns << NPlusOnePattern.new(parent, query, count)
        end
      end
    end

    private def find_parent_query(repeated_query : String, queries : Array(String)) : String
      # Look for query before the first occurrence of repeated query
      first_index = queries.index(repeated_query)
      return "Unknown" unless first_index && first_index > 0

      # Walk back to find non-repeated query
      (first_index - 1).downto(0) do |i|
        query = queries[i]
        next if query == repeated_query || query.starts_with?("-- RELATION")
        return query
      end

      "Unknown"
    end

    private def should_ignore?(sql : String) : Bool
      normalized = sql.strip.upcase
      @config.ignore_patterns.any? { |pattern| normalized.starts_with?(pattern) }
    end

    private def log_detection(query : String, count : Int32)
      Log.warn { "N+1 Query Pattern Detected: #{SQLUtils.truncate_sql(query)} (#{count} times)" }
    end
  end
end
