# Count how often a report reads each profiler and detector source.
class CallCountingProfiler < CQL::Performance::QueryProfiler
  getter calls = Hash(String, Int32).new(0)

  def statistics
    calls["statistics"] += 1
    super
  end

  def slowest_queries(limit : Int32 = 10)
    calls["slowest_queries"] += 1
    super
  end

  def issues
    calls["issues"] += 1
    super
  end
end

class CallCountingDetector < CQL::Performance::NPlusOneDetector
  getter calls = Hash(String, Int32).new(0)

  def patterns
    calls["patterns"] += 1
    super
  end

  def issues
    calls["issues"] += 1
    super
  end
end
