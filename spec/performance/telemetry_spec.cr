require "../spec_helper"

class RecordingTracer < CQL::Telemetry::Tracer
  getter spans = [] of {Symbol, String}

  def in_span(operation : Symbol, sql : String, & : -> T) : T forall T
    @spans << {operation, sql}
    yield
  end
end

class SkippingTracer < CQL::Telemetry::Tracer
  def in_span(operation : Symbol, sql : String, &)
  end
end

class SwallowingTracer < CQL::Telemetry::Tracer
  def in_span(operation : Symbol, sql : String, &)
    yield
  rescue
  end
end

describe CQL::Telemetry do
  events = [] of CQL::Telemetry::QueryEvent

  before_each do
    CQL::Telemetry.reset!
    UserDB.users.create!
    events.clear
    CQL::Telemetry.subscribe("spec") { |event| events << event }
  end

  after_each do
    CQL::Telemetry.reset!
    UserDB.users.drop!
  end

  add_user = ->(name : String) { UserDB.insert.into(:users).values(name: name, email: "#{name}@x.io", age: 30, password: "pw").commit }

  describe "regressions from review" do
    it "restores the outer context after a nested with_context" do
      CQL::Telemetry.with_context("outer") do
        CQL::Telemetry.with_context("inner") { UserDB.query.from(:users).select(:name).all(as: String) }
        UserDB.query.from(:users).select(:name).all(as: String)
      end

      events.map(&.context).should eq(["inner", "outer"])
    end

    it "does not put the error message in the logged line" do
      io = IO::Memory.new
      Log.setup(:debug, Log::IOBackend.new(io: io, dispatcher: Log::DispatchMode::Sync))
      CQL::Telemetry.log_queries
      expect_raises(Exception) { UserDB.query.from(:users).where("nope = ?", "secret-value").all(as: Int32) }
      Log.setup(:warn)

      io.to_s.should contain("FAILED")
      io.to_s.should_not contain("secret-value")
    end

    it "fails loudly when a tracer never runs the statement" do
      CQL::Telemetry.tracer = SkippingTracer.new
      expect_raises(Exception, /did not run the statement/) { UserDB.query.from(:users).select(:name).all(as: String) }
    end

    it "re-raises a statement error that a tracer swallowed" do
      CQL::Telemetry.tracer = SwallowingTracer.new
      expect_raises(Exception) { UserDB.query.from(:users).where("nope = ?", 1).all(as: Int32) }
    end

    it "hands out the transaction's connection from with_connection" do
      UserDB.transaction do |tx|
        UserDB.with_connection(&.should(be(tx.connection)))
      end
    end
  end

  describe "events" do
    it "describes a select without exposing parameter values by default" do
      UserDB.query.from(:users).select(:name).where(name: "ada").all(as: String)

      event = events.last
      event.operation.should eq(:select)
      event.sql.should contain("FROM users")
      event.param_count.should eq(1)
      event.params.should be_nil
      event.adapter.should eq(CQL::Adapter::SQLite)
      event.error.should be_nil
      event.success?.should be_true
      event.duration.should be >= Time::Span.zero
    end

    it "includes parameter values when capture_params is on" do
      CQL::Telemetry.capture_params = true
      UserDB.query.from(:users).select(:name).where(name: "ada").all(as: String)

      events.last.params.should eq(["ada"] of DB::Any)
    end

    it "reports insert, update and delete with the rows they affected" do
      add_user.call("ada")
      events.last.operation.should eq(:insert)
      events.last.rows_affected.should eq(1)

      UserDB.update.table(:users).set(age: 31).where(name: "ada").commit
      events.last.operation.should eq(:update)
      events.last.rows_affected.should eq(1)

      UserDB.delete.from(:users).where(name: "ada").commit
      events.last.operation.should eq(:delete)
      events.last.rows_affected.should eq(1)
    end

    it "labels raw SQL run through Schema#exec by its statement" do
      UserDB.exec("SELECT 1")
      UserDB.exec("INSERT INTO users (name, email, age, password) VALUES ('ada', 'ada@x.io', 30, 'pw')")
      UserDB.exec("DROP TABLE IF EXISTS no_such_table")
      events.map(&.operation).should eq([:select, :insert, :ddl])
    end

    it "reports plans as :explain and ActiveRecord ids as selects" do
      UserDB.query.from(:users).explain
      events.last.operation.should eq(:explain)

      TestUser.ids
      events.last.operation.should eq(:select)
    end

    it "reports failures, then re-raises" do
      expect_raises(Exception) { UserDB.query.from(:users).where("nope = ?", 1).all(as: Int32) }

      events.last.error.should_not be_nil
      events.last.success?.should be_false
    end
  end

  describe "pool wait" do
    it "is within the duration for an ordinary statement" do
      add_user.call("ada")

      events.last.pool_wait.should be >= Time::Span.zero
      events.last.pool_wait.should be <= events.last.duration
    end

    it "measures the wait for a connection held by another fiber" do
      busy = spec_sqlite_schema("telemetry_pool_wait.db", "?initial_pool_size=0&max_pool_size=1&checkout_timeout=5")
      done = Channel(Nil).new
      busy.with_connection do |_connection|
        spawn { busy.exec("SELECT 1"); done.send(nil) }
        Fiber.yield
        sleep 20.milliseconds
      end
      done.receive

      events.last.pool_wait.should be >= 10.milliseconds
      events.last.pool_wait.should be <= events.last.duration
    end

    it "counts a failed checkout's wait until the failure" do
      busy = spec_sqlite_schema("telemetry_pool_timeout.db", "?initial_pool_size=0&max_pool_size=1&checkout_timeout=0.05")
      busy.with_connection do |_connection|
        expect_raises(DB::PoolTimeout) { busy.exec("SELECT 1") }
      end

      events.last.error.should be_a(DB::PoolTimeout)
      events.last.pool_wait.should be >= 40.milliseconds
      events.last.pool_wait.should eq(events.last.duration)
    end

    it "is zero for an event built with the original nine arguments" do
      event = CQL::Telemetry::QueryEvent.new("SELECT 1", 0, nil, 1.millisecond, nil, CQL::Adapter::SQLite, :select, nil, nil)

      event.pool_wait.should eq(Time::Span.zero)
    end
  end

  describe "subscribers" do
    it "stop receiving events once unsubscribed" do
      CQL::Telemetry.unsubscribe("spec")
      add_user.call("ada")
      events.should be_empty
    end

    it "cannot break a query when one of them raises, and the others still run" do
      CQL::Telemetry.subscribe("broken") { |_| raise "subscriber bug" }
      add_user.call("ada")

      events.size.should eq(1)
      UserDB.query.from(:users).select(:name).all(as: String).should eq(["ada"])
    end

    it "are safe to add and remove concurrently with emission" do
      done = Channel(Nil).new
      4.times do |i|
        spawn do
          50.times do |index|
            CQL::Telemetry.subscribe("worker-#{i}-#{index}") { |_| }
            CQL::Telemetry.unsubscribe("worker-#{i}-#{index}")
          end
          done.send(nil)
        end
      end
      add_user.call("ada")
      4.times { done.receive }

      events.size.should eq(1)
    end
  end

  describe "slow query alerts" do
    it "call back only for statements at or above the threshold" do
      slow = [] of CQL::Telemetry::QueryEvent
      CQL::Telemetry.alert_on_slow(1.hour) { |event| slow << event }
      add_user.call("ada")
      slow.should be_empty

      CQL::Telemetry.alert_on_slow(Time::Span.zero, name: "all") { |event| slow << event }
      add_user.call("grace")
      slow.size.should eq(1)
    end
  end

  describe "context" do
    it "tags events emitted inside with_context for the current fiber only" do
      CQL::Telemetry.with_context("Users#index") { add_user.call("ada") }
      events.last.context.should eq("Users#index")

      add_user.call("grace")
      events.last.context.should be_nil
    end

    it "tags events emitted inside Performance.with_context, the same slot as Telemetry.with_context" do
      CQL::Performance.with_context("perf-ctx") { add_user.call("ada") }

      events.last.context.should eq("perf-ctx")
    end

    it "keeps the contexts of concurrently running fibers apart" do
      done = Channel(Nil).new
      %w[x y].each do |name|
        spawn do
          CQL::Telemetry.with_context(name) do
            UserDB.query.from(:users).select(:name).all(as: String)
            sleep 5.milliseconds
            UserDB.query.from(:users).select(:name).all(as: String)
          end
          done.send(nil)
        end
      end
      2.times { done.receive }

      events.map(&.context.to_s).sort!.should eq(%w[x x y y])
    end

    it "restores the outer context when the block raises, so nothing carries over" do
      CQL::Telemetry.with_context("outer") do
        expect_raises(Exception, "boom") { CQL::Telemetry.with_context("tenant-1") { raise "boom" } }
        CQL::Telemetry.current_context.should eq("outer")
      end
      CQL::Telemetry.current_context.should be_nil
    end

    it "does not hand its context to fibers spawned inside the block" do
      seen = Channel(String?).new
      CQL::Telemetry.with_context("parent") { spawn { seen.send(CQL::Telemetry.current_context) } }
      seen.receive.should be_nil
    end
  end

  describe "tracer" do
    it "wraps each statement in a span" do
      tracer = RecordingTracer.new
      CQL::Telemetry.tracer = tracer
      add_user.call("ada")

      tracer.spans.size.should eq(1)
      tracer.spans.first[0].should eq(:insert)
      tracer.spans.first[1].should start_with("INSERT INTO users")
    end
  end
end

describe CQL::Executor do
  before_each { UserDB.users.create! }
  after_each { UserDB.users.drop! }

  it "runs statements on an explicit connection, so they join its transaction" do
    UserDB.with_connection do |connection|
      transaction = connection.begin_transaction
      UserDB.insert.into(:users).values(name: "ada", email: "a@x.io", age: 1, password: "pw").using(connection).commit
      UserDB.query.from(:users).select(:name).using(connection).all(as: String).should eq(["ada"])
      transaction.rollback
    end

    UserDB.query.from(:users).select(:name).all(as: String).should be_empty
  end

  it "applies to updates, deletes and ActiveRecord builders" do
    UserDB.with_connection do |connection|
      transaction = connection.begin_transaction
      UserDB.insert.into(:users).values(name: "ada", email: "a@x.io", age: 1, password: "pw").using(connection).commit
      UserDB.update.table(:users).set(age: 2).where(name: "ada").using(connection).commit
      TestUser.query.using(connection).to_a.map(&.age).should eq([2])
      UserDB.delete.from(:users).where(name: "ada").using(connection).commit
      TestUser.query.using(connection).to_a.should be_empty
      transaction.rollback
    end
  end

  it "keeps the pinned connection through clone and set operations" do
    UserDB.with_connection do |connection|
      transaction = connection.begin_transaction
      UserDB.insert.into(:users).values(name: "ada", email: "a@x.io", age: 1, password: "pw").using(connection).commit
      names = UserDB.query.from(:users).select(:name).using(connection)

      names.clone.all(as: String).should eq(["ada"])
      names.union(names).all(as: String).should eq(["ada"])
      transaction.rollback
    end
  end
end
