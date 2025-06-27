# Best Practices

_Essential guidelines for building robust, performant, and maintainable applications with CQL_

***

## 📋 Overview

This guide covers proven patterns and practices for:

* **Database Design** - Schema and relationship patterns
* **Model Architecture** - Clean, maintainable model design
* **Query Optimization** - Fast, efficient database queries
* **Error Handling** - Robust error management
* **Testing** - Comprehensive testing strategies
* **Security** - Protection against common vulnerabilities
* **Performance** - Scaling and optimization techniques

***

## 🏗️ Database Design Best Practices

### 1. Schema Design

#### ✅ Use Appropriate Data Types

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: UserDB, table: :users

  # ✅ Good: Use specific, appropriate types
  property id : Int64 = 0
  property email : String              # Not String | Nil if always required
  property age : Int32                 # Not String for numeric data
  property balance : Float64           # Use Float64 for currency (or consider BigDecimal)
  property active : Bool = true        # Explicit boolean, not String
  property created_at : Time = Time.utc

  # ✅ Use union types only when truly optional
  property phone : String?             # Optional field
  property last_login : Time?          # Can be nil
end
```

#### ❌ Common Schema Mistakes

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: UserDB, table: :users

  # ❌ Avoid: Overly generic types
  property data : String               # Should be structured
  property settings : String           # Use JSON column or separate table

  # ❌ Avoid: String for everything
  property age : String                # Should be Int32
  property active : String             # Should be Bool

  # ❌ Avoid: Missing constraints
  property email : String?             # Should not be nil if required
end
```

### 2. Indexing Strategy

```crystal
class UserSchema < CQL::Schema(UserDB)
  table :users do |t|
    t.integer :id, primary: true, auto_increment: true
    t.string :email, null: false, index: {unique: true}        # ✅ Unique index for lookups
    t.string :username, null: false, index: {unique: true}     # ✅ Another unique field
    t.string :first_name, null: false, index: true             # ✅ Index for searches
    t.string :last_name, null: false, index: true              # ✅ Index for searches
    t.integer :age, index: true                                # ✅ Index for range queries
    t.boolean :active, default: true, index: true              # ✅ Index for filtering
    t.string :status, index: true                              # ✅ Index for status queries
    t.timestamp :created_at, null: false, index: true          # ✅ Index for date ranges
    t.timestamp :updated_at, null: false

    # ✅ Composite indexes for common query patterns
    t.index([:last_name, :first_name])                         # Name searches
    t.index([:active, :created_at])                            # Active users by date
    t.index([:status, :updated_at])                            # Status changes by date
  end
end
```

### 3. Relationship Design

#### ✅ Clear Relationship Patterns

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: UserDB, table: :users
  property id : Int64 = 0
  property name : String
  property email : String

  # ✅ Clear, descriptive relationships
  has_many :posts, Post, foreign_key: :author_id           # Use descriptive foreign key
  has_many :comments, Comment, foreign_key: :commenter_id  # Avoid ambiguous names
  has_one :profile, UserProfile, foreign_key: :user_id     # Clear ownership

  # ✅ Many-to-many with join table
  has_many :user_roles, UserRole, foreign_key: :user_id
  has_many :roles, Role, through: :user_roles
end

class Post
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: UserDB, table: :users
  property id : Int64 = 0
  property title : String
  property content : String
  property author_id : Int64                               # ✅ Explicit foreign key property

  belongs_to :author, User, foreign_key: :author_id       # ✅ Use descriptive alias
  has_many :comments, Comment, foreign_key: :post_id
end
```

***

## 🏛️ Model Architecture Best Practices

### 1. Model Organization

#### ✅ Single Responsibility Principle

```crystal
# ✅ Good: User model focused on user-specific logic
class User
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: UserDB, table: :users

  property id : Int64 = 0
  property email : String
  property encrypted_password : String

  validate :email, required: true, unique: true, match: EMAIL_REGEX
  validate :password, size: 8..255, confirmation: true

  before_save :encrypt_password

  def authenticate(password : String) : Bool
    # Authentication logic here
    true
  end

  private def encrypt_password
    # Encryption logic here
  end
end

# ✅ Good: Separate concern for user preferences
class UserPreference
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: UserDB, table: :user_preferences

  property id : Int64 = 0
  property user_id : Int64
  property theme : String = "light"
  property notifications : Bool = true
  property language : String = "en"

  belongs_to :user, User, foreign_key: :user_id

  validate :theme, in: ["light", "dark"]
  validate :language, in: ["en", "es", "fr", "de"]
end
```

### 2. Validation Patterns

#### ✅ Comprehensive Validation

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: UserDB, table: :users

  EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

  property id : Int64 = 0
  property first_name : String
  property last_name : String
  property email : String
  property age : Int32
  property password : String
  property password_confirmation : String?

  # ✅ Layer multiple validations appropriately
  validate :first_name, required: true, size: 2..50
  validate :last_name, required: true, size: 2..50
  validate :email, required: true, unique: true, match: EMAIL_REGEX
  validate :age, gt: 0, lt: 150
  validate :password, size: 8..255, confirmation: true

  # ✅ Custom validations for complex logic
  validate :password_complexity
  validate :age_appropriate_for_service

  private def password_complexity
    return unless password

    errors.add(:password, "must contain uppercase letter") unless password.match(/[A-Z]/)
    errors.add(:password, "must contain lowercase letter") unless password.match(/[a-z]/)
    errors.add(:password, "must contain number") unless password.match(/[0-9]/)
    errors.add(:password, "must contain special character") unless password.match(/[!@#$%^&*]/)
  end

  private def age_appropriate_for_service
    return unless age

    if age < 13
      errors.add(:age, "must be at least 13 years old")
    end
  end
end
```

### 3. Callback Patterns

#### ✅ Focused Callbacks

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: UserDB, table: :users

  property id : Int64 = 0
  property email : String
  property password : String
  property email_verified : Bool = false
  property last_login : Time?

  # ✅ Use callbacks for model-related side effects only
  before_save :normalize_email
  before_create :generate_verification_token
  after_create :send_welcome_email
  after_update :log_important_changes

  private def normalize_email
    self.email = email.downcase.strip
  end

  private def generate_verification_token
    # Generate email verification token
  end

  private def send_welcome_email
    # Trigger email sending (consider async)
    EmailJob.send_welcome(self.id)
  end

  private def log_important_changes
    # Log security-relevant changes
    if email_changed? || password_changed?
      SecurityLog.create!(
        user_id: self.id,
        action: "profile_updated",
        details: changed_attributes
      )
    end
  end
end

# ❌ Avoid: Heavy business logic in callbacks
class User
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: UserDB, table: :users

  after_create :setup_user_account  # ❌ Too much responsibility

  private def setup_user_account
    # ❌ This should be in a service object
    UserProfile.create!(user_id: self.id)
    UserPreferences.create!(user_id: self.id)
    NotificationSettings.create!(user_id: self.id)
    # ... many more operations
  end
end
```

***

## 🚀 Query Optimization Best Practices

### 1. Efficient Query Patterns

#### ✅ Use Specific Queries

```crystal
# ✅ Good: Only load what you need
users = User.select(:id, :name, :email)
           .where(active: true)
           .order(name: :asc)
           .limit(50)
           .all

# ✅ Good: Use appropriate query methods
user = User.find_by!(email: "user@example.com")  # When you expect one result
users = User.where(age: 25..35).all              # When you expect multiple
count = User.where(active: true).count           # When you only need the count

# ✅ Good: Efficient joins
posts_with_authors = Post.join(:author)
                        .where { author.active.eq(true) }
                        .select("posts.title", "users.name as author_name")
                        .all
```

#### ❌ Inefficient Query Patterns

```crystal
# ❌ Bad: Loading unnecessary data
users = User.all                                 # Loads everything
first_user = User.all.first                     # Should use User.first

# ❌ Bad: N+1 queries
posts = Post.all
posts.each do |post|
  puts post.author.name                          # N+1 query problem
end

# ✅ Better: Use joins
posts = Post.join(:author).all
posts.each do |post|
  puts post.author.name                          # No additional queries
end
```

### 2. Pagination Best Practices

```crystal
# ✅ Good: Limit-offset pagination for small datasets
class UsersController
  def index
    page = params[:page]?.try(&.to_i) || 1
    per_page = 20
    offset = (page - 1) * per_page

    users = User.where(active: true)
               .order(created_at: :desc)
               .limit(per_page)
               .offset(offset)
               .all

    total_count = User.where(active: true).count
    total_pages = (total_count / per_page.to_f).ceil.to_i

    render_users(users, page, total_pages)
  end
end

# ✅ Better: Cursor-based pagination for large datasets
class UsersController
  def index
    cursor = params[:cursor]?.try(&.to_i64)
    per_page = 20

    query = User.where(active: true).order(id: :desc).limit(per_page)
    query = query.where { id < cursor } if cursor

    users = query.all
    next_cursor = users.last?.try(&.id)

    render_users(users, next_cursor)
  end
end
```

### 3. Batch Processing

```crystal
# ✅ Good: Process records in batches
def update_all_user_statistics
  User.find_each(batch_size: 1000) do |user|
    user.update_statistics!
  end
end

# ✅ Good: Bulk operations for simple updates
def deactivate_inactive_users
  cutoff_date = 6.months.ago

  User.where { last_login < cutoff_date }
     .update_all({active: false, deactivated_at: Time.utc})
end

# ❌ Bad: Individual updates in loops
def deactivate_inactive_users
  users = User.where { last_login < 6.months.ago }.all
  users.each do |user|              # ❌ Individual UPDATE queries
    user.update!(active: false)
  end
end
```

***

## 🛡️ Security Best Practices

### 1. SQL Injection Prevention

```crystal
# ✅ Good: Use parameterized queries (CQL handles this automatically)
def find_users_by_name(name : String)
  User.where(name: name).all                    # ✅ Safe - parameterized
end

def find_users_by_age_range(min_age : Int32, max_age : Int32)
  User.where { (age >= min_age) & (age <= max_age) }.all  # ✅ Safe
end

# ❌ Never do this (not possible in CQL, but good to know)
# def find_users_by_name(name : String)
#   User.query("SELECT * FROM users WHERE name = '#{name}'")  # ❌ SQL injection risk
# end
```

### 2. Input Validation

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: UserDB, table: :users
  property id : Int64 = 0
  property email : String
  property role : String = "user"
  property bio : String?

  # ✅ Validate input format and content
  validates :email, presence: true, format: EMAIL_REGEX
  validates :role, inclusion: {in: ["user", "admin", "moderator"]}
  validates :bio, length: {maximum: 1000}

  # ✅ Sanitize HTML content
  before_save :sanitize_bio

  private def sanitize_bio
    if bio = @bio
      # Remove dangerous HTML tags
      self.bio = bio.gsub(/<script.*?<\/script>/mi, "")
                   .gsub(/<iframe.*?<\/iframe>/mi, "")
                   .gsub(/javascript:/i, "")
    end
  end
end
```

### 3. Mass Assignment Protection

```crystal
class UsersController
  def create
    # ✅ Good: Explicitly permit only safe parameters
    user_params = {
      :name => params[:name]?.try(&.as(String)),
      :email => params[:email]?.try(&.as(String)),
      :age => params[:age]?.try(&.to_i32)
    }.compact

    user = User.create!(user_params)
    render_success(user)
  end

  def update
    user = User.find!(params[:id].to_i64)

    # ✅ Good: Only allow specific fields to be updated
    allowed_params = {
      :name => params[:name]?,
      :bio => params[:bio]?
    }.compact

    user.update!(allowed_params)
    render_success(user)
  end

  # ❌ Bad: Allow all parameters (if CQL supported this)
  # def create
  #   user = User.create!(params)  # ❌ Dangerous mass assignment
  # end
end
```

***

## 🧪 Testing Best Practices

### 1. Model Testing

```crystal
require "spec"

describe User do
  before_each do
    UserDB.users.create!
  end

  after_each do
    UserDB.users.drop!
  end

  describe "validations" do
    it "validates email format" do
      user = User.new(name: "Test", email: "invalid-email", age: 25)
      user.valid?.should be_false
      user.errors[:email].should_not be_empty
    end

    it "validates password complexity" do
      user = User.new(
        name: "Test",
        email: "test@example.com",
        age: 25,
        password: "simple"
      )

      user.valid?.should be_false
      user.errors[:password].should contain("must contain uppercase letter")
    end

    it "validates uniqueness of email" do
      User.create!(name: "First", email: "test@example.com", age: 25, password: "Password123!")

      duplicate = User.new(name: "Second", email: "test@example.com", age: 30, password: "Password123!")
      duplicate.valid?.should be_false
      duplicate.errors[:email].should contain("has already been taken")
    end
  end

  describe "callbacks" do
    it "normalizes email before save" do
      user = User.create!(
        name: "Test",
        email: "  TEST@EXAMPLE.COM  ",
        age: 25,
        password: "Password123!"
      )

      user.email.should eq("test@example.com")
    end
  end

  describe "relationships" do
    it "has many posts" do
      user = User.create!(name: "Author", email: "author@example.com", age: 30, password: "Password123!")
      post1 = Post.create!(title: "Post 1", content: "Content 1", author_id: user.id)
      post2 = Post.create!(title: "Post 2", content: "Content 2", author_id: user.id)

      user.posts.size.should eq(2)
      user.posts.map(&.title).should contain("Post 1")
      user.posts.map(&.title).should contain("Post 2")
    end
  end
end
```

### 2. Integration Testing

```crystal
describe "User workflow" do
  before_each do
    UserDB.users.create!
  end

  after_each do
    UserDB.users.drop!
  end

  it "creates user with profile and preferences" do
    # Test complete user creation workflow
    user = User.create!(
      name: "John Doe",
      email: "john@example.com",
      age: 30,
      password: "SecurePassword123!"
    )

    # Verify user was created
    user.persisted?.should be_true
    user.id.should_not be_nil

    # Create related records
    profile = UserProfile.create!(
      user_id: user.id,
      bio: "Software developer",
      website: "https://johndoe.com"
    )

    preferences = UserPreference.create!(
      user_id: user.id,
      theme: "dark",
      notifications: true
    )

    # Verify relationships work
    user.profile.should_not be_nil
    user.profile.not_nil!.bio.should eq("Software developer")

    user.preference.should_not be_nil
    user.preference.not_nil!.theme.should eq("dark")
  end
end
```

### 3. Performance Testing

```crystal
require "benchmark"

describe "Performance tests" do
  before_each do
    UserDB.users.create!

    # Create test data
    100.times do |i|
      User.create!(
        name: "User #{i}",
        email: "user#{i}@example.com",
        age: (18..65).sample,
        password: "Password123!"
      )
    end
  end

  after_each do
    UserDB.users.drop!
  end

  it "performs queries efficiently" do
    # Test query performance
    time = Benchmark.measure do
      100.times do
        User.where(age: 25..35).limit(10).all
      end
    end

    # Should complete 100 queries in reasonable time
    time.total.should be < 1.0  # Less than 1 second
  end

  it "handles large result sets efficiently" do
    memory_before = GC.stats.heap_size

    users = User.all
    users.size.should eq(100)

    memory_after = GC.stats.heap_size
    memory_used = memory_after - memory_before

    # Should use reasonable amount of memory
    memory_used.should be < 1_000_000  # Less than 1MB for 100 users
  end
end
```

***

## 📊 Performance Monitoring

### 1. Query Performance Monitoring

```crystal
# Create a performance logger
class QueryPerformanceLogger
  def self.log_slow_query(query : String, duration : Time::Span)
    if duration > 100.milliseconds
      puts "SLOW QUERY (#{duration.total_milliseconds}ms): #{query}"
    end
  end
end

# Monitor queries in your application
module QueryMonitoring
  def self.time_query(query : String, &block)
    start_time = Time.utc
    result = yield
    end_time = Time.utc
    duration = end_time - start_time

    QueryPerformanceLogger.log_slow_query(query, duration)
    result
  end
end

# Usage example
def find_active_users
  QueryMonitoring.time_query("User.where(active: true)") do
    User.where(active: true).all
  end
end
```

### 2. Memory Usage Monitoring

```crystal
class MemoryMonitor
  def self.check_usage(operation : String)
    gc_stats_before = GC.stats
    yield
    gc_stats_after = GC.stats

    heap_growth = gc_stats_after.heap_size - gc_stats_before.heap_size

    if heap_growth > 10_000_000  # 10MB
      puts "HIGH MEMORY USAGE in #{operation}: #{heap_growth} bytes"
    end
  end
end

# Usage
MemoryMonitor.check_usage("bulk user creation") do
  1000.times do |i|
    User.create!(name: "User #{i}", email: "user#{i}@example.com", age: 25, password: "Password123!")
  end
end
```

***

## 🎯 Code Organization

### 1. Directory Structure

```
src/
├── models/
│   ├── user.cr
│   ├── post.cr
│   ├── comment.cr
│   └── concerns/
│       ├── auditable.cr
│       └── sluggable.cr
├── schemas/
│   ├── user_schema.cr
│   ├── blog_schema.cr
│   └── base_schema.cr
├── repositories/
│   ├── user_repository.cr
│   └── post_repository.cr
├── services/
│   ├── user_service.cr
│   └── email_service.cr
└── validators/
    ├── email_validator.cr
    └── password_validator.cr
```

### 2. Shared Concerns

```crystal
# src/models/concerns/auditable.cr
module Auditable
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def auditable(user_field : Symbol = :user_id)
      property created_by : Int64?
      property updated_by : Int64?
      property created_at : Time = Time.utc
      property updated_at : Time = Time.utc

      before_save :set_audit_fields
    end
  end

  private def set_audit_fields
    now = Time.utc

    if new_record?
      self.created_at = now
      self.created_by = current_user_id
    end

    self.updated_at = now
    self.updated_by = current_user_id
  end

  private def current_user_id
    # Get current user ID from context
    RequestContext.current_user_id
  end
end

# Usage in models
class Post
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: UserDB, table: :users
  include Auditable
  auditable(:author_id)

  property id : Int64 = 0
  property title : String
  property content : String
end
```

***

## 🎓 Summary

### Key Takeaways

1. **Type Safety First**: Leverage Crystal's type system for better code quality
2. **Database Design**: Plan your schema carefully with proper indexes and relationships
3. **Query Optimization**: Use specific queries, avoid N+1 problems, implement proper pagination
4. **Security**: Validate inputs, prevent SQL injection, protect against mass assignment
5. **Testing**: Write comprehensive tests for models, validations, and performance
6. **Monitoring**: Track query performance and memory usage
7. **Code Organization**: Use clear structure and shared concerns for maintainability

### Quick Reference Checklist

* [ ] Use appropriate data types for all properties
* [ ] Add indexes for commonly queried fields
* [ ] Implement comprehensive validations
* [ ] Use efficient query patterns
* [ ] Test all model functionality
* [ ] Monitor performance in production
* [ ] Organize code with clear separation of concerns
* [ ] Follow security best practices

***

**Continue Learning:**

* 📚 [**Performance Optimization**](broken-reference) - Advanced optimization techniques
* 🔒 [**Security Guide**](../advanced-topics/security-guide.md) - Comprehensive security practices
* 🧪 [**Testing Strategies**](../advanced-topics/testing-strategies.md) - Advanced testing approaches
* 🏗️ [**Architecture Guide**](architecture-overview.md) - Understanding CQL's architecture
