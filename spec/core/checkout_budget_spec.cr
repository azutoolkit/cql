require "../spec_helper"

private alias Budget = CQL::CheckoutBudget

private def current_scope : Budget?
  Fiber.current.cql_checkout_budget
end

describe CQL::CheckoutBudget do
  describe ".within" do
    it "restores the enclosing scope after a nested one, and none outside any scope" do
      Budget.within do
        outer = Budget.claim(1.second)
        Budget.within do
          sleep 1.millisecond
          Budget.claim(1.second).should_not eq outer
        end
        Budget.claim(1.second).should eq outer
      end
      current_scope.should be_nil
    end

    it "restores the enclosing scope, and none outside any scope, when the block raises" do
      Budget.within do
        outer = Budget.claim(1.second)
        expect_raises(Exception, "inner") { Budget.within { Budget.claim(2.seconds); raise "inner" } }
        Budget.claim(1.second).should eq outer
      end
      expect_raises(Exception, "outer") { Budget.within { Budget.claim(1.second); raise "outer" } }
      current_scope.should be_nil
    end

    it "is not seen by a fiber spawned inside it" do
      Budget.within do
        Budget.claim(1.second)
        seen = Channel(Budget?).new
        spawn { seen.send(current_scope) }
        seen.receive.should be_nil
      end
    end
  end

  describe ".claim" do
    it "gives every claim in a scope the first claim's deadline" do
      Budget.within do
        first = Budget.claim(1.second).should_not be_nil
        sleep 1.millisecond
        Budget.claim(5.seconds).should eq first
      end
    end

    it "gives each claim outside a scope a deadline of its own" do
      first = Budget.claim(1.second).should_not be_nil
      sleep 1.millisecond
      second = Budget.claim(1.second).should_not be_nil
      second.should be > first
    end
  end

  it "gives a zero timeout no deadline and no health check, in a scope or not" do
    Budget.claim(Time::Span.zero).should be_nil
    Budget.check_wait(Time::Span.zero, cap: 5.seconds).should be_nil
    Budget.within do
      Budget.claim(Time::Span.zero).should be_nil
      Budget.check_wait(Time::Span.zero, cap: 5.seconds).should be_nil
    end
  end

  describe ".check_wait" do
    it "lets the health checks of a scope share half its budget" do
      Budget.within do
        first = Budget.check_wait(1.second, cap: 5.seconds).should_not be_nil
        first.should be <= 0.5.seconds
        first.should be > 0.3.seconds
        later = Budget.check_wait(1.second, cap: 5.seconds).should_not be_nil
        later.should be > 0.3.seconds
      end
    end

    it "gives a later health check in a scope none once the half is spent" do
      Budget.within do
        Budget.check_wait(0.2.seconds, cap: 5.seconds).should_not be_nil
        sleep 0.12.seconds
        Budget.check_wait(0.2.seconds, cap: 5.seconds).should be_nil
      end
    end

    it "gives a later health check in a scope none when less than MIN_CHECK_WAIT of the half is left" do
      Budget.within do
        Budget.check_wait(98.milliseconds, cap: 5.seconds).should eq Budget::MIN_CHECK_WAIT
        Budget.check_wait(98.milliseconds, cap: 5.seconds).should be_nil
      end
    end
  end

  describe "#check_wait" do
    it "gives a first check at least MIN_CHECK_WAIT and a later one with less than that left none" do
      budget = Budget.new(Time.instant + 98.milliseconds)
      budget.check_wait(5.seconds).should eq Budget::MIN_CHECK_WAIT
      budget.check_wait(5.seconds).should be_nil
    end

    it "waits at most the cap" do
      Budget.new(Time.instant + 10.seconds).check_wait(1.second).should eq 1.second
    end
  end
end
