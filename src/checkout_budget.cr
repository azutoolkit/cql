module CQL
  # The time one checkout may spend, and the half of it its health checks share, so a replacement can still connect.
  # Inside `within` (`DatabaseSource` may try several connections for one borrow) every claim on the current fiber
  # shares one budget; outside, each starts its own. Kept inline in the fiber, so a scope allocates nothing.
  struct CheckoutBudget
    # A health check with less time left than this is not worth a round trip.
    MIN_CHECK_WAIT = 50.milliseconds

    # When the checkout must end; nil: no deadline, and no time for health checks.
    getter deadline : Time::Instant?
    @checks_due : Time::Instant?
    @checked = false

    def initialize(@deadline : Time::Instant?)
      @checks_due = deadline.try { |due| Time.instant + (due - Time.instant) / 2 }
    end

    # Runs the block in a new scope; the enclosing one, or none, is back afterwards, also when the block raises.
    def self.within(& : -> T) : T forall T
      previous = Fiber.current.cql_checkout_budget
      Fiber.current.cql_checkout_budget = new(nil)
      yield
    ensure
      Fiber.current.cql_checkout_budget = previous
    end

    # The deadline of a checkout allowed *timeout* (zero: none): the first claim in a scope sets it, later ones reuse it.
    def self.claim(timeout : Time::Span) : Time::Instant?
      claimed(timeout).deadline
    end

    # How long a health check in a checkout allowed *timeout* may wait (see `#check_wait`), counted in the scope.
    def self.check_wait(timeout : Time::Span, cap : Time::Span) : Time::Span?
      budget = claimed(timeout)
      wait = budget.check_wait(cap)
      keep(budget)
      wait
    end

    # The scope's budget, which its first claim starts and keeps; outside a scope, a fresh one.
    private def self.claimed(timeout : Time::Span) : CheckoutBudget
      scope = Fiber.current.cql_checkout_budget
      return scope if scope && scope.deadline
      keep(new(timeout.positive? ? Time.instant + timeout : nil))
    end

    # Writes *budget* back to the scope, if any: the fiber holds a copy.
    private def self.keep(budget : CheckoutBudget) : CheckoutBudget
      Fiber.current.cql_checkout_budget = budget if Fiber.current.cql_checkout_budget
      budget
    end

    # How long the next health check may wait (at least MIN_CHECK_WAIT, at most *cap*), or nil to drop the
    # connection unchecked: the checks' half is spent, or less than MIN_CHECK_WAIT of it is left after a first check.
    def check_wait(cap : Time::Span) : Time::Span?
      left = @checks_due.try { |due| due - Time.instant }
      checked, @checked = @checked, true
      return if left.nil? || left <= Time::Span.zero || (checked && left < MIN_CHECK_WAIT)
      Math.min(Math.max(left, MIN_CHECK_WAIT), cap)
    end
  end
end

# :nodoc:
class ::Fiber
  # :nodoc:
  property cql_checkout_budget : CQL::CheckoutBudget?
end
