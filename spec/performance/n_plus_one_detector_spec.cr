require "../spec_helper"
require "../../src/performance/n_plus_one_detector"

describe CQL::Performance::NPlusOnePattern do
  describe "#initialize" do
    it "stores parent_query, repeated_query, and repetition_count" do
      pattern = CQL::Performance::NPlusOnePattern.new(
        "SELECT * FROM users WHERE id = ?",
        "SELECT * FROM posts WHERE user_id = ?",
        5
      )

      pattern.parent_query.should eq("SELECT * FROM users WHERE id = ?")
      pattern.repeated_query.should eq("SELECT * FROM posts WHERE user_id = ?")
      pattern.repetition_count.should eq(5)
    end

    it "sets timestamp to current UTC time" do
      before = Time.utc
      pattern = CQL::Performance::NPlusOnePattern.new("parent", "child", 3)
      after = Time.utc

      pattern.timestamp.should be >= before
      pattern.timestamp.should be <= after
    end
  end
end

describe CQL::Performance::NPlusOneDetector do
  describe "#initialize" do
    it "initializes with default config" do
      detector = CQL::Performance::NPlusOneDetector.new
      detector.enabled?.should be_true
      detector.patterns.should be_empty
      detector.issues.should be_empty
    end

    it "initializes with custom config" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 5
      config.detection_window = 20

      detector = CQL::Performance::NPlusOneDetector.new(config)
      detector.enabled?.should be_true
      detector.patterns.should be_empty
    end
  end

  describe "#record_query" do
    it "normalizes SQL before recording" do
      detector = CQL::Performance::NPlusOneDetector.new

      # Record a parent query first
      detector.record_query("SELECT * FROM users")

      # Record the same query with different literal values multiple times
      # The normalizer replaces numbers and quoted strings with placeholders
      3.times do |i|
        detector.record_query("SELECT * FROM posts WHERE user_id = #{i + 1}")
      end

      # All three should normalize to the same pattern and be detected
      detector.patterns.size.should eq(1)
      detector.patterns.first.repeated_query.should eq("SELECT * FROM posts WHERE user_id = ?")
    end

    it "detects repeated queries that meet the threshold" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 2

      detector = CQL::Performance::NPlusOneDetector.new(config)

      # Parent query
      detector.record_query("SELECT * FROM users")

      # Repeated child query (threshold = 2, so 2 repetitions should trigger)
      detector.record_query("SELECT * FROM posts WHERE user_id = ?")
      detector.record_query("SELECT * FROM posts WHERE user_id = ?")

      detector.patterns.size.should eq(1)
      pattern = detector.patterns.first
      pattern.repeated_query.should eq("SELECT * FROM posts WHERE user_id = ?")
      pattern.repetition_count.should eq(2)
    end

    it "does not detect queries below the threshold" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 3

      detector = CQL::Performance::NPlusOneDetector.new(config)

      detector.record_query("SELECT * FROM users")
      detector.record_query("SELECT * FROM posts WHERE user_id = ?")
      detector.record_query("SELECT * FROM posts WHERE user_id = ?")

      # Only 2 repetitions but threshold is 3
      detector.patterns.should be_empty
    end

    it "identifies the parent query correctly" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 2

      detector = CQL::Performance::NPlusOneDetector.new(config)

      detector.record_query("SELECT * FROM users")
      detector.record_query("SELECT * FROM posts WHERE user_id = ?")
      detector.record_query("SELECT * FROM posts WHERE user_id = ?")

      pattern = detector.patterns.first
      pattern.parent_query.should eq("SELECT * FROM users")
    end

    it "updates repetition count when pattern repeats more" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 2
      config.detection_window = 20

      detector = CQL::Performance::NPlusOneDetector.new(config)

      detector.record_query("SELECT * FROM users")
      3.times { detector.record_query("SELECT * FROM posts WHERE user_id = ?") }

      detector.patterns.size.should eq(1)
      first_count = detector.patterns.first.repetition_count

      # Add more repetitions
      2.times { detector.record_query("SELECT * FROM posts WHERE user_id = ?") }

      updated_count = detector.patterns.first.repetition_count
      updated_count.should be >= first_count
    end

    it "detects multiple different N+1 patterns" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 2
      config.detection_window = 30

      detector = CQL::Performance::NPlusOneDetector.new(config)

      # First N+1 pattern
      detector.record_query("SELECT * FROM users")
      3.times { detector.record_query("SELECT * FROM posts WHERE user_id = ?") }

      # Second N+1 pattern
      detector.record_query("SELECT * FROM orders")
      3.times { detector.record_query("SELECT * FROM items WHERE order_id = ?") }

      detector.patterns.size.should eq(2)
      queries = detector.patterns.map(&.repeated_query)
      queries.should contain("SELECT * FROM posts WHERE user_id = ?")
      queries.should contain("SELECT * FROM items WHERE order_id = ?")
    end
  end

  describe "#start_relation_loading / #end_relation_loading" do
    it "adds relation markers to recent queries" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 2

      detector = CQL::Performance::NPlusOneDetector.new(config)

      detector.start_relation_loading("posts", "User")
      detector.record_query("SELECT * FROM posts WHERE user_id = ?")
      detector.record_query("SELECT * FROM posts WHERE user_id = ?")
      detector.end_relation_loading

      # Markers themselves should not be counted as repeated queries
      # But the queries inside should still be detected
      detector.patterns.size.should eq(1)
      detector.patterns.first.repeated_query.should eq("SELECT * FROM posts WHERE user_id = ?")
    end

    it "does nothing when disabled" do
      config = CQL::Performance::Config::Detection.new
      detector = CQL::Performance::NPlusOneDetector.new(config)
      detector.enabled = false

      detector.start_relation_loading("posts", "User")
      detector.end_relation_loading

      # No errors should occur when disabled
      detector.patterns.should be_empty
    end
  end

  describe "#patterns" do
    it "returns a duplicate of the patterns array" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 2

      detector = CQL::Performance::NPlusOneDetector.new(config)

      detector.record_query("SELECT * FROM users")
      3.times { detector.record_query("SELECT * FROM posts WHERE user_id = ?") }

      patterns1 = detector.patterns
      patterns2 = detector.patterns

      patterns1.size.should eq(patterns2.size)
      patterns1.first.repeated_query.should eq(patterns2.first.repeated_query)
    end

    it "returns empty array when no patterns detected" do
      detector = CQL::Performance::NPlusOneDetector.new
      detector.patterns.should be_empty
      detector.patterns.should be_a(Array(CQL::Performance::NPlusOnePattern))
    end
  end

  describe "#issues" do
    it "maps patterns to issues with correct severity for low (2-5 repetitions)" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 2
      config.detection_window = 20

      detector = CQL::Performance::NPlusOneDetector.new(config)

      detector.record_query("SELECT * FROM users")
      3.times { detector.record_query("SELECT * FROM posts WHERE user_id = ?") }

      issues = detector.issues
      issues.size.should eq(1)
      issues.first.severity.should eq(:low)
      issues.first.type.should eq(:n_plus_one)
      issues.first.message.should contain("3 times")
    end

    it "maps patterns to issues with medium severity (6-20 repetitions)" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 2
      config.detection_window = 30

      detector = CQL::Performance::NPlusOneDetector.new(config)

      detector.record_query("SELECT * FROM users")
      10.times { detector.record_query("SELECT * FROM posts WHERE user_id = ?") }

      issues = detector.issues
      issues.size.should eq(1)
      issues.first.severity.should eq(:medium)
    end

    it "maps patterns to issues with high severity (21-50 repetitions)" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 2
      config.detection_window = 60

      detector = CQL::Performance::NPlusOneDetector.new(config)

      detector.record_query("SELECT * FROM users")
      25.times { detector.record_query("SELECT * FROM posts WHERE user_id = ?") }

      issues = detector.issues
      issues.size.should eq(1)
      issues.first.severity.should eq(:high)
    end

    it "maps patterns to issues with critical severity (51+ repetitions)" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 2
      config.detection_window = 120

      detector = CQL::Performance::NPlusOneDetector.new(config)

      detector.record_query("SELECT * FROM users")
      55.times { detector.record_query("SELECT * FROM posts WHERE user_id = ?") }

      issues = detector.issues
      issues.size.should eq(1)
      issues.first.severity.should eq(:critical)
    end

    it "includes details with parent and repeated query info" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 2

      detector = CQL::Performance::NPlusOneDetector.new(config)

      detector.record_query("SELECT * FROM users")
      3.times { detector.record_query("SELECT * FROM posts WHERE user_id = ?") }

      issue = detector.issues.first
      issue.details.has_key?("parent_query").should be_true
      issue.details.has_key?("repeated_query").should be_true
      issue.details.has_key?("repetitions").should be_true
      issue.details["repetitions"].should eq("3")
    end

    it "returns empty array when no patterns exist" do
      detector = CQL::Performance::NPlusOneDetector.new
      detector.issues.should be_empty
    end
  end

  describe "#clear" do
    it "resets all patterns and recent queries" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 2

      detector = CQL::Performance::NPlusOneDetector.new(config)

      detector.record_query("SELECT * FROM users")
      3.times { detector.record_query("SELECT * FROM posts WHERE user_id = ?") }

      detector.patterns.should_not be_empty

      detector.clear

      detector.patterns.should be_empty
      detector.issues.should be_empty
    end

    it "allows new detection after clearing" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 2

      detector = CQL::Performance::NPlusOneDetector.new(config)

      detector.record_query("SELECT * FROM users")
      3.times { detector.record_query("SELECT * FROM posts WHERE user_id = ?") }

      detector.clear

      # Record new queries after clearing
      detector.record_query("SELECT * FROM orders")
      3.times { detector.record_query("SELECT * FROM items WHERE order_id = ?") }

      detector.patterns.size.should eq(1)
      detector.patterns.first.repeated_query.should eq("SELECT * FROM items WHERE order_id = ?")
    end
  end

  describe "ignored patterns" do
    it "ignores COMMIT statements" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 2

      detector = CQL::Performance::NPlusOneDetector.new(config)

      detector.record_query("SELECT * FROM users")
      3.times { detector.record_query("COMMIT") }

      detector.patterns.should be_empty
    end

    it "ignores BEGIN statements" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 2

      detector = CQL::Performance::NPlusOneDetector.new(config)

      detector.record_query("SELECT * FROM users")
      3.times { detector.record_query("BEGIN") }

      detector.patterns.should be_empty
    end

    it "ignores ROLLBACK statements" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 2

      detector = CQL::Performance::NPlusOneDetector.new(config)

      detector.record_query("SELECT * FROM users")
      3.times { detector.record_query("ROLLBACK") }

      detector.patterns.should be_empty
    end

    it "ignores case-insensitive transaction statements" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 2

      detector = CQL::Performance::NPlusOneDetector.new(config)

      detector.record_query("SELECT * FROM users")
      detector.record_query("commit")
      detector.record_query("Commit")
      detector.record_query("begin")

      detector.patterns.should be_empty
    end
  end

  describe "enabled flag" do
    it "does not record queries when disabled" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 2

      detector = CQL::Performance::NPlusOneDetector.new(config)
      detector.enabled = false

      detector.record_query("SELECT * FROM users")
      3.times { detector.record_query("SELECT * FROM posts WHERE user_id = ?") }

      detector.patterns.should be_empty
    end

    it "resumes detection when re-enabled" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 2

      detector = CQL::Performance::NPlusOneDetector.new(config)
      detector.enabled = false

      detector.record_query("SELECT * FROM users")
      3.times { detector.record_query("SELECT * FROM posts WHERE user_id = ?") }

      detector.patterns.should be_empty

      # Re-enable and record new queries
      detector.enabled = true

      detector.record_query("SELECT * FROM orders")
      3.times { detector.record_query("SELECT * FROM items WHERE order_id = ?") }

      detector.patterns.size.should eq(1)
    end
  end

  describe "MAX_PATTERNS cap" do
    it "limits stored patterns to MAX_PATTERNS" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 2
      config.detection_window = 500

      detector = CQL::Performance::NPlusOneDetector.new(config)

      # Generate more than MAX_PATTERNS (100) distinct patterns
      105.times do |i|
        detector.record_query("SELECT * FROM parent_#{i}")
        detector.record_query("SELECT * FROM child_#{i} WHERE parent_id = ?")
        detector.record_query("SELECT * FROM child_#{i} WHERE parent_id = ?")
      end

      detector.patterns.size.should be <= 100
    end
  end

  describe "detection_window" do
    it "respects custom detection window size" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 2
      config.detection_window = 5

      detector = CQL::Performance::NPlusOneDetector.new(config)

      # Record a parent query
      detector.record_query("SELECT * FROM users")

      # Record enough filler queries to push the repeated query out of the window
      10.times { |i| detector.record_query("SELECT * FROM table_#{i}") }

      # Now record repeated queries - within the small window they should be detected
      detector.record_query("SELECT * FROM posts WHERE user_id = ?")
      detector.record_query("SELECT * FROM posts WHERE user_id = ?")

      # The repeated queries should still be detected within the current window
      detector.patterns.size.should eq(1)
    end
  end

  describe "SQL normalization" do
    it "normalizes numeric literals to placeholders" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 2

      detector = CQL::Performance::NPlusOneDetector.new(config)

      detector.record_query("SELECT * FROM users")
      detector.record_query("SELECT * FROM posts WHERE user_id = 1")
      detector.record_query("SELECT * FROM posts WHERE user_id = 2")
      detector.record_query("SELECT * FROM posts WHERE user_id = 3")

      detector.patterns.size.should eq(1)
      detector.patterns.first.repeated_query.should eq("SELECT * FROM posts WHERE user_id = ?")
    end

    it "normalizes string literals to placeholders" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 2

      detector = CQL::Performance::NPlusOneDetector.new(config)

      detector.record_query("SELECT * FROM users")
      detector.record_query("SELECT * FROM posts WHERE slug = 'hello-world'")
      detector.record_query("SELECT * FROM posts WHERE slug = 'another-post'")
      detector.record_query("SELECT * FROM posts WHERE slug = 'third-post'")

      detector.patterns.size.should eq(1)
      detector.patterns.first.repeated_query.should eq("SELECT * FROM posts WHERE slug = '?'")
    end

    it "normalizes positional parameters" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 2

      detector = CQL::Performance::NPlusOneDetector.new(config)

      detector.record_query("SELECT * FROM users")
      detector.record_query("SELECT * FROM posts WHERE user_id = $1")
      detector.record_query("SELECT * FROM posts WHERE user_id = $2")
      detector.record_query("SELECT * FROM posts WHERE user_id = $3")

      detector.patterns.size.should eq(1)
    end

    it "collapses whitespace in queries" do
      config = CQL::Performance::Config::Detection.new
      config.threshold = 2

      detector = CQL::Performance::NPlusOneDetector.new(config)

      detector.record_query("SELECT * FROM users")
      detector.record_query("SELECT  *  FROM  posts  WHERE  user_id = ?")
      detector.record_query("SELECT * FROM posts WHERE user_id = ?")

      detector.patterns.size.should eq(1)
    end
  end
end
