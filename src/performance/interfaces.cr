# Interface modules for performance monitoring components

module CQL::Performance
  module QueryProfilerInterface
    abstract def record_query(sql : String, params : Array(DB::Any),
                              execution_time : Time::Span,
                              rows_affected : Int64? = nil,
                              error : String? = nil) : Void
    abstract def statistics
    abstract def slowest_queries(limit : Int32) : Array(QueryData)
    abstract def stats_trackers : Hash(String, StatsTracker)
    abstract def issues : Array(Issue)
    abstract def clear : Void
  end

  module NPlusOneDetectorInterface
    abstract def record_query(sql : String) : Void
    abstract def start_relation_loading(relation_name : String, parent_model : String) : Void
    abstract def end_relation_loading : Void
    abstract def patterns
    abstract def issues : Array(Issue)
    abstract def clear : Void
  end
end
