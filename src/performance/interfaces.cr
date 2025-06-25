# Core interfaces for CQL Performance Monitoring
# Follows Interface Segregation Principle - focused, single-purpose interfaces

require "../cql"

module CQL::Performance
  # Event data structure for monitoring events
  abstract struct MonitoringEvent
    getter timestamp : Time
    getter context : String?

    def initialize(@timestamp : Time = Time.utc, @context : String? = nil)
    end
  end

  # Query execution event
  struct QueryExecutionEvent < MonitoringEvent
    getter sql : String
    getter params : Array(DB::Any)
    getter execution_time : Time::Span
    getter rows_affected : Int64?

    def initialize(@sql : String, @params : Array(DB::Any), @execution_time : Time::Span,
                   @rows_affected : Int64? = nil, timestamp : Time = Time.utc, context : String? = nil)
      super(timestamp, context)
    end
  end

  # Relation loading event
  struct RelationLoadingEvent < MonitoringEvent
    getter relation_name : String
    getter parent_model : String
    getter loading_type : LoadingType

    enum LoadingType
      Started
      Ended
    end

    def initialize(@relation_name : String, @parent_model : String, @loading_type : LoadingType,
                   timestamp : Time = Time.utc, context : String? = nil)
      super(timestamp, context)
    end
  end

  # Core interfaces following ISP

  # Single responsibility: Listen to monitoring events
  abstract class EventListener
    abstract def handle_event(event : MonitoringEvent) : Void
  end

  # Single responsibility: Analyze queries
  abstract class QueryAnalyzer
    abstract def analyze(sql : String, params : Array(DB::Any) = [] of DB::Any) : AnalysisResult?
    abstract def supports?(adapter : Adapter) : Bool
  end

  # Single responsibility: Detect performance issues
  abstract class PerformanceDetector
    abstract def process_event(event : MonitoringEvent) : Array(PerformanceIssue)
    abstract def issues : Array(PerformanceIssue)
    abstract def clear_issues : Void
  end

  # Single responsibility: Generate reports
  abstract class ReportGenerator
    abstract def generate(data : ReportData) : String
    abstract def format : String
  end

  # Single responsibility: Manage configuration
  abstract class ConfigurationManager
    abstract def get_config(type)
    abstract def update_config(config) : Void
  end

  # Single responsibility: Publish events
  abstract class EventPublisher
    abstract def publish(event : MonitoringEvent) : Void
    abstract def subscribe(listener : EventListener) : Void
    abstract def unsubscribe(listener : EventListener) : Void
  end

  # Data structures for clean interfaces

  # Analysis result from query analyzers
  abstract struct AnalysisResult
    getter query : String
    getter warnings : Array(String)

    def initialize(@query : String, @warnings : Array(String) = [] of String)
    end

    abstract def has_issues? : Bool
  end

  # Performance issue detected by detectors
  abstract struct PerformanceIssue
    getter type : String
    getter severity : Severity
    getter message : String
    getter detected_at : Time

    enum Severity
      Low
      Medium
      High
      Critical
    end

    def initialize(@type : String, @severity : Severity, @message : String, @detected_at : Time = Time.utc)
    end

    abstract def summary : String
  end

  # Report data structure
  struct ReportData
    getter events : Array(MonitoringEvent)
    getter issues : Array(PerformanceIssue)
    getter metadata : Hash(String, String)

    def initialize(@events : Array(MonitoringEvent) = [] of MonitoringEvent,
                   @issues : Array(PerformanceIssue) = [] of PerformanceIssue,
                   @metadata : Hash(String, String) = {} of String => String)
    end
  end
end
