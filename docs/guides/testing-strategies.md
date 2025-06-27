# Testing Strategies with CQL

Comprehensive testing strategies for CQL applications covering unit tests, integration tests, and mocking.

## Testing Fundamentals

### Testing Pyramid

CQL applications should follow a structured testing approach:

- **Unit Tests** - Fast, isolated tests for business logic and validations
- **Integration Tests** - Medium speed tests for database operations and queries
- **End-to-End Tests** - Slow, full application flow tests

## Test Environment Setup

### Database Configuration

```crystal
# spec/spec_helper.cr
require "spec"
require "../src/myapp"

TestDB = CQL::Schema.define(
  :test_db,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://:memory:",
  pool_size: 1
) do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String
    column :email, String
    column :active, Bool, default: true
    timestamps

    unique_constraint [:email]
  end

  table :posts do
    primary :id, Int64, auto_increment: true
    column :user_id, Int64
    column :title, String
    column :content, String
    column :published, Bool, default: false
    timestamps

    foreign_key :user_id, references: :users
  end
end

TestDB.build

# Test cleanup helpers
module TestHelpers
  def cleanup_database
    TestDB.query("DELETE FROM posts").commit
    TestDB.query("DELETE FROM users").commit
    TestDB.query("DELETE FROM sqlite_sequence").commit if TestDB.adapter.is_a?(CQL::Adapter::SQLite)
  end

  def with_rollback(&block)
    TestDB.transaction do |tx|
      begin
        yield
      ensure
        tx.rollback
      end
    end
  end
end

Spec.before_each do
  TestHelpers.cleanup_database
end

Spec.after_suite do
  TestDB.close
end
```

### Environment Configuration

```crystal
# config/test.cr
module TestConfig
  DATABASE_CONFIG = {
    adapter: CQL::Adapter::SQLite,
    uri: "sqlite3://:memory:",
    pool_size: 1,
    checkout_timeout: 1.second
  }

  def self.unit_test_db
    CQL::Schema.define(:unit_test, **DATABASE_CONFIG)
  end

  def self.integration_test_db
    CQL::Schema.define(:integration_test, **DATABASE_CONFIG.merge({
      uri: "sqlite3://./tmp/integration_test.db"
    }))
  end

  def self.enable_fast_tests
    CQL::ActiveRecord::Base.skip_validations = true
    ENV["BCRYPT_COST"] = "1"
  end
end
```

## Unit Testing

### Model Logic Testing

```crystal
# spec/models/user_spec.cr
require "../spec_helper"

describe User do
  describe "validations" do
    it "validates presence of name" do
      user = User.new(name: "", email: "test@example.com")
      user.valid?.should be_false
      user.errors[:name].should contain("can't be blank")
    end

    it "validates email format" do
      user = User.new(name: "Test", email: "invalid-email")
      user.valid?.should be_false
      user.errors[:email].should contain("is invalid")
    end

    it "validates email uniqueness" do
      User.create!(name: "First", email: "test@example.com")

      duplicate_user = User.new(name: "Second", email: "test@example.com")
      duplicate_user.valid?.should be_false
      duplicate_user.errors[:email].should contain("has already been taken")
    end
  end

  describe "business logic" do
    it "has correct full name" do
      user = User.new(name: "John Doe", email: "john@example.com")
      user.full_name.should eq("John Doe")
    end

    it "can be activated" do
      user = User.create!(name: "Test", email: "test@example.com", active: false)

      user.activate!
      user.active?.should be_true
      user.activated_at.should_not be_nil
    end
  end

  describe "scopes" do
    before_each do
      User.create!(name: "Active User", email: "active@example.com", active: true)
      User.create!(name: "Inactive User", email: "inactive@example.com", active: false)
    end

    it "finds active users" do
      active_users = User.active.all
      active_users.size.should eq(1)
      active_users.all?(&.active?).should be_true
    end
  end
end
```

### Callback Testing

```crystal
# spec/models/user_callbacks_spec.cr
require "../spec_helper"

describe User do
  describe "callbacks" do
    it "normalizes email before saving" do
      user = User.new(name: "Test", email: "TEST@EXAMPLE.COM")
      user.save!
      user.email.should eq("test@example.com")
    end

    it "sends welcome email after creation" do
      welcome_mailer = WelcomeMailer.new
      WelcomeMailer.stub(:new).and_return(welcome_mailer)
      welcome_mailer.stub(:deliver).and_return(true)

      user = User.create!(name: "Test", email: "test@example.com")

      WelcomeMailer.should have_received(:new)
      welcome_mailer.should have_received(:deliver)
    end

    it "updates timestamps on save" do
      user = User.create!(name: "Test", email: "test@example.com")
      original_updated_at = user.updated_at

      sleep 0.1
      user.update!(name: "Updated Name")

      user.updated_at.should be > original_updated_at
    end
  end
end
```

### Custom Validator Testing

```crystal
# spec/validators/email_validator_spec.cr
require "../spec_helper"

describe EmailValidator do
  it "validates correct email formats" do
    valid_emails = [
      "test@example.com",
      "user+tag@domain.co.uk",
      "name.surname@subdomain.example.org"
    ]

    valid_emails.each do |email|
      validator = EmailValidator.new
      validator.validate(email).should be_true
    end
  end

  it "rejects invalid email formats" do
    invalid_emails = [
      "invalid",
      "@example.com",
      "test@",
      "test..test@example.com"
    ]

    invalid_emails.each do |email|
      validator = EmailValidator.new
      validator.validate(email).should be_false
    end
  end
end
```

## Integration Testing

### Database Persistence Tests

```crystal
# spec/integration/user_persistence_spec.cr
require "../spec_helper"

describe "User Persistence" do
  describe "CRUD operations" do
    it "creates and retrieves users" do
      user = User.create!(
        name: "John Doe",
        email: "john@example.com"
      )

      user.id.should_not be_nil
      user.persisted?.should be_true

      found_user = User.find!(user.id!)
      found_user.name.should eq("John Doe")
      found_user.email.should eq("john@example.com")
    end

    it "updates user attributes" do
      user = User.create!(name: "Original", email: "original@example.com")

      user.update!(name: "Updated", email: "updated@example.com")

      reloaded_user = User.find!(user.id!)
      reloaded_user.name.should eq("Updated")
      reloaded_user.email.should eq("updated@example.com")
    end

    it "deletes users" do
      user = User.create!(name: "To Delete", email: "delete@example.com")
      user_id = user.id!

      user.delete!

      User.find(user_id).should be_nil
    end
  end

  describe "complex queries" do
    before_each do
      active_user = User.create!(name: "Active", email: "active@example.com", active: true)
      inactive_user = User.create!(name: "Inactive", email: "inactive@example.com", active: false)

      active_user.posts.create!(title: "Active Post", content: "Content")
    end

    it "finds users with posts" do
      users_with_posts = User.joins(:posts).distinct.all
      users_with_posts.size.should eq(1)
      users_with_posts.first.name.should eq("Active")
    end

    it "aggregates user statistics" do
      stats = User.select(
        "COUNT(*) as total_users",
        "COUNT(CASE WHEN active = 1 THEN 1 END) as active_users"
      ).first

      stats["total_users"].should eq(2)
      stats["active_users"].should eq(1)
    end
  end
end
```

### Transaction Testing

```crystal
# spec/integration/transaction_spec.cr
require "../spec_helper"

describe "Transactions" do
  it "commits successful transactions" do
    User.transaction do
      User.create!(name: "User 1", email: "user1@example.com")
      User.create!(name: "User 2", email: "user2@example.com")
    end

    User.count.should eq(2)
  end

  it "rolls back failed transactions" do
    expect_raises(CQL::RecordInvalid) do
      User.transaction do
        User.create!(name: "Valid User", email: "valid@example.com")
        User.create!(name: "", email: "invalid@example.com")  # This will fail
      end
    end

    User.count.should eq(0)
  end
end
```

## Mocking and Stubbing

### Database Mocking

```crystal
# spec/mocks/mock_database.cr
class MockDatabase
  getter queries : Array(String)
  getter results : Hash(String, Array(NamedTuple))

  def initialize
    @queries = [] of String
    @results = {} of String => Array(NamedTuple)
  end

  def expect_query(sql : String, result : Array(NamedTuple))
    @results[sql] = result
  end

  def query(sql : String)
    @queries << sql
    @results[sql]? || [] of NamedTuple
  end

  def reset
    @queries.clear
    @results.clear
  end
end

# Usage in tests
describe "User finder" do
  it "executes correct SQL for finding by email" do
    mock_db = MockDatabase.new
    mock_db.expect_query(
      "SELECT * FROM users WHERE email = ?",
      [{id: 1_i64, name: "Test", email: "test@example.com"}]
    )

    # Test your code with mock_db
    mock_db.queries.should contain("SELECT * FROM users WHERE email = ?")
  end
end
```

## Test Data Factories

### Factory Pattern

```crystal
# spec/factories/user_factory.cr
module UserFactory
  def self.build(attributes = {} of Symbol => String | Bool)
    defaults = {
      :name => "Test User",
      :email => "test@example.com",
      :active => true
    }

    User.new(**defaults.merge(attributes))
  end

  def self.create!(attributes = {} of Symbol => String | Bool)
    build(attributes).tap(&.save!)
  end

  def self.build_list(count : Int32, attributes = {} of Symbol => String | Bool)
    (1..count).map do |i|
      attrs = attributes.merge({:email => "test#{i}@example.com"})
      build(attrs)
    end
  end
end

# Usage
describe "User operations" do
  it "works with factory-created users" do
    user = UserFactory.create!(name: "Custom Name")
    user.name.should eq("Custom Name")
    user.persisted?.should be_true
  end

  it "creates multiple users" do
    users = UserFactory.build_list(3)
    users.size.should eq(3)
    users.each { |u| u.should be_a(User) }
  end
end
```

## Performance Testing

### Query Performance

```crystal
# spec/performance/query_performance_spec.cr
require "../spec_helper"

describe "Query Performance" do
  before_each do
    # Create test data
    100.times do |i|
      User.create!(name: "User #{i}", email: "user#{i}@example.com")
    end
  end

  it "loads users efficiently" do
    start_time = Time.monotonic

    users = User.where(active: true).limit(10).all

    end_time = Time.monotonic
    duration = end_time - start_time

    users.size.should eq(10)
    duration.should be < 100.milliseconds
  end

  it "uses indexes for email lookup" do
    start_time = Time.monotonic

    user = User.find_by!(email: "user50@example.com")

    end_time = Time.monotonic
    duration = end_time - start_time

    user.should_not be_nil
    duration.should be < 10.milliseconds
  end
end
```

## Testing Best Practices

### Model Testing Guidelines

1. **Test validations separately** from business logic
2. **Use factories** for consistent test data
3. **Test edge cases** and error conditions
4. **Mock external services** to avoid dependencies
5. **Use transactions** for test isolation when possible

### Database Testing Guidelines

1. **Use in-memory SQLite** for fast unit tests
2. **Test with real database** for integration tests
3. **Clean database** between tests
4. **Test transactions** explicitly
5. **Verify SQL queries** when performance matters

### Example Test Structure

```crystal
# spec/models/user_spec.cr
require "../spec_helper"

describe User do
  # Unit tests - fast, isolated
  describe "validations" do
    # Test each validation rule
  end

  describe "business logic" do
    # Test model methods without database
  end

  # Integration tests - with database
  describe "persistence" do
    # Test database operations
  end

  describe "associations" do
    # Test relationships
  end
end
```

## Running Tests

### Test Commands

```bash
# Run all tests
crystal spec

# Run specific test file
crystal spec spec/models/user_spec.cr

# Run with coverage
crystal spec --coverage

# Run performance tests only
crystal spec spec/performance/

# Parallel test execution
crystal spec --parallel
```

### CI Configuration

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v3
      - uses: crystal-lang/install-crystal@v1

      - name: Install dependencies
        run: shards install

      - name: Run tests
        run: crystal spec
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test
```

This testing guide provides practical strategies for testing CQL applications while maintaining good performance and reliability.
