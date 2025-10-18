# Test Coverage & Quality Assurance

> **Ensure code quality** - Comprehensive guide to testing, coverage measurement, and quality assurance in CQL

## Overview

This guide covers testing strategies, coverage measurement, and quality assurance practices for CQL development.

---

## Test Coverage Strategy

### Current State

CQL maintains high test quality with:

- **801 passing tests** across all features
- **Comprehensive test organization** by pattern and feature
- **Multiple database adapters** tested (SQLite, PostgreSQL, MySQL)
- **Integration and unit tests** covering core functionality

### Coverage Philosophy

While Crystal doesn't have built-in coverage tools like some languages, we ensure comprehensive testing through:

1. **Feature-driven testing** - Every feature has corresponding tests
2. **Pattern coverage** - All design patterns (Active Record, Repository, Data Mapper) tested
3. **Dialect coverage** - Tests run against all supported databases
4. **Edge case testing** - Security, concurrency, error handling

---

## Test Organization

### Test Structure

```
spec/
├── core/              # Core functionality tests
│   ├── query_spec.cr
│   ├── schema_spec.cr
│   └── migration_spec.cr
├── patterns/          # Design pattern tests
│   ├── active_record/
│   └── repository_spec.cr
├── operations/        # CRUD operation tests
│   ├── insert_spec.cr
│   ├── update_spec.cr
│   └── delete_spec.cr
├── integration/       # Database integration tests
│   ├── adapters/
│   └── dialects/
├── security/          # Security tests
│   └── sql_injection_spec.cr
└── support/           # Test helpers and fixtures
```

---

## Running Tests

### Full Test Suite

```bash
# Run all tests
crystal spec

# Run with verbose output
crystal spec --verbose

# Run specific test file
crystal spec spec/core/query_spec.cr

# Run specific test by line number
crystal spec spec/core/query_spec.cr:42
```

### Database-Specific Testing

```bash
# Test with PostgreSQL
DATABASE_URL="postgres://user:pass@localhost/test" crystal spec

# Test with MySQL
DATABASE_URL="mysql://user:pass@localhost/test" crystal spec

# Test with SQLite (default)
crystal spec
```

---

## Coverage Measurement Strategies

### Manual Coverage Analysis

Since Crystal lacks automated coverage tools, use these strategies:

#### 1. Feature Checklist

Maintain a checklist for each feature:

```markdown
Feature: Query Builder

- [x] SELECT statements
- [x] WHERE clauses (hash syntax)
- [x] WHERE clauses (block syntax)
- [x] JOIN operations
- [x] ORDER BY
- [x] LIMIT/OFFSET
- [x] GROUP BY
- [x] HAVING
- [x] Aggregates
- [x] Subqueries
- [x] NULL handling
- [x] LIKE clauses
```

#### 2. Code Review Coverage

During code reviews, verify:

- New code has corresponding tests
- Edge cases are tested
- Error conditions are tested
- All code paths are reachable via tests

#### 3. Integration Testing

Ensure real-world usage patterns are tested:

```crystal
# Test complete workflows
describe "User Registration Workflow" do
  it "creates user, sends email, logs event" do
    user = User.create(email: "test@example.com")
    user.should_not be_nil

    # Verify all side effects
    emails_sent.should eq(1)
    audit_log.should contain("user_created")
  end
end
```

---

## Test Quality Guidelines

### 1. Test Independence

Each test should be independent:

```crystal
# ✅ Good - creates own data
it "finds user by email" do
  user = User.create(email: "test@example.com")
  found = User.find_by(email: "test@example.com")
  found.should eq(user)
end

# ❌ Bad - depends on other tests
it "finds user by email" do
  # Assumes user exists from previous test
  found = User.find_by(email: "test@example.com")
  found.should_not be_nil
end
```

### 2. Clear Test Names

Use descriptive test names:

```crystal
# ✅ Good - clear intent
it "prevents SQL injection in WHERE clauses"
it "raises RecordNotFound when ID doesn't exist"
it "caches query results within same request"

# ❌ Bad - vague
it "works correctly"
it "test 1"
it "user stuff"
```

### 3. Test One Thing

Each test should verify one behavior:

```crystal
# ✅ Good - focused
it "validates email presence" do
  user = User.new(email: nil)
  user.valid?.should be_false
  user.errors.first.field.should eq(:email)
end

# ❌ Bad - tests multiple things
it "validates user" do
  user = User.new(email: nil, name: nil)
  user.valid?.should be_false
  user.save.should be_false
  User.count.should eq(0)
end
```

### 4. Use Setup/Teardown

Keep tests DRY with helpers:

```crystal
describe "User Operations" do
  before_each do
    @schema = create_test_schema
    @schema.users.create!
  end

  after_each do
    @schema.users.drop!
  end

  it "creates user" do
    user = User.create(email: "test@example.com")
    user.id.should_not be_nil
  end
end
```

---

## Coverage Targets by Component

### Core Components (>95%)

These critical components should have near-complete coverage:

- Query builder (`src/query.cr`)
- Schema management (`src/schema.cr`)
- Migrations (`src/migrations.cr`)
- Active Record model (`src/active_record/model.cr`)

### Feature Components (>85%)

Feature implementations should be well-tested:

- Validations
- Callbacks
- Relations
- Transactions
- Caching

### Utility Components (>70%)

Utility code needs good coverage:

- Expression builders
- Dialects
- Helpers

---

## Testing Best Practices

### 1. Test Public APIs

Focus on testing public interfaces:

```crystal
# ✅ Test public API
it "query builder chains methods" do
  query = schema.query
    .from(:users)
    .where(active: true)
    .order(name: :asc)
    .limit(10)

  query.to_sql.should contain("WHERE")
end

# ⚠️ Avoid testing internals
it "query builder internal state" do
  query = schema.query.from(:users)
  query.@table.should eq(:users)  # Testing internal state
end
```

### 2. Test Edge Cases

Don't just test the happy path:

```crystal
describe "User.find" do
  it "returns user when found" do
    user = User.create(email: "test@example.com")
    User.find(user.id).should eq(user)
  end

  it "returns nil when not found" do
    User.find(99999).should be_nil
  end

  it "handles nil ID gracefully" do
    User.find(nil).should be_nil
  end

  it "handles negative IDs" do
    User.find(-1).should be_nil
  end
end
```

### 3. Test Error Conditions

Verify error handling:

```crystal
it "raises ValidationError with invalid data" do
  expect_raises(CQL::RecordInvalid) do
    User.create!(email: "invalid")
  end
end

it "rolls back transaction on error" do
  expect_raises(Exception) do
    User.transaction do
      User.create(email: "test@example.com")
      raise "Error!"
    end
  end

  User.count.should eq(0)
end
```

### 4. Test Concurrency

Test thread safety where applicable:

```crystal
it "handles concurrent inserts safely" do
  threads = 10.times.map do
    spawn do
      User.create(email: "user#{Random.rand}@example.com")
    end
  end

  threads.each(&.join)
  User.count.should eq(10)
end
```

---

## Performance Testing

### Benchmark Tests

Add performance benchmarks for critical paths:

```crystal
require "benchmark"

describe "Query Performance" do
  it "performs 1000 inserts efficiently" do
    time = Benchmark.measure do
      1000.times do
        User.create(email: "user#{Random.rand}@example.com")
      end
    end

    # Should complete in reasonable time
    time.real.should be < 5.seconds
  end
end
```

### N+1 Detection

Test for N+1 query patterns:

```crystal
it "avoids N+1 queries with associations" do
  create_users_with_posts(10)

  query_count = 0
  monitor = ->(sql : String) { query_count += 1 }

  users = User.includes(:posts).all
  users.each { |u| u.posts.size }

  # Should be 2 queries (users + posts), not 11 (users + N * posts)
  query_count.should be <= 2
end
```

---

## Continuous Integration

### GitHub Actions Example

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: password
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v3
      - name: Install Crystal
        uses: crystal-lang/install-crystal@v1
      - name: Install dependencies
        run: shards install
      - name: Run tests
        env:
          DATABASE_URL: postgres://postgres:password@localhost/test
        run: crystal spec
      - name: Check formatting
        run: crystal tool format --check
      - name: Run linter
        run: ./bin/ameba
```

---

## Manual Coverage Verification

### Coverage Checklist

Before each release, verify:

- [ ] All public methods have tests
- [ ] All error paths tested
- [ ] All database adapters tested
- [ ] Integration tests cover main workflows
- [ ] Security tests passing
- [ ] Performance benchmarks stable
- [ ] Documentation examples work

### Coverage Review Process

1. **Feature Addition**: Require tests with new features
2. **Bug Fixes**: Add regression test
3. **Code Review**: Verify test coverage
4. **Release**: Run full test suite on all adapters

---

## Future: Automated Coverage

### Potential Tools

When Crystal coverage tools become available:

1. **LLVM Coverage**: Crystal uses LLVM, may support coverage flags
2. **Custom Tooling**: Build Crystal-specific coverage
3. **Integration**: Add to CI pipeline

### Tracking Issue

Monitor Crystal language progress on coverage:

- https://github.com/crystal-lang/crystal (search for "coverage")

---

## Summary

While Crystal lacks automated coverage tools, CQL maintains high test quality through:

✅ **Comprehensive test suite** (801 tests)
✅ **Pattern-based organization**
✅ **Multiple database testing**
✅ **Security testing**
✅ **Manual coverage verification**
✅ **Code review process**

**Key Principle:** Every feature has tests, every bug has a regression test, every PR includes tests.

---

## Resources

- [Crystal Spec Documentation](https://crystal-lang.org/api/latest/Spec.html)
- [CQL Testing Examples](../examples/)
- [Contributing Guide](../../CONTRIBUTING.md)

---

**Next:** [Performance Testing](./performance-optimization.md)





