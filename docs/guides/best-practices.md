# CQL Best Practices

Essential guidelines for building robust, performant, and maintainable CQL applications.

## Database Design

### Schema Design

#### Use Appropriate Data Types

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: UserDB, table: :users

  # ✅ Good: Specific, appropriate types
  property id : Int64 = 0
  property email : String              # Not String | Nil if always required
  property age : Int32                 # Not String for numeric data
  property balance : Float64           # Use Float64 for currency
  property active : Bool = true        # Explicit boolean
  property created_at : Time = Time.utc

  # ✅ Use union types only when truly optional
  property phone : String?             # Optional field
  property last_login : Time?          # Can be nil
end
```

#### Common Schema Mistakes

```crystal
class User
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

### Indexing Strategy

```crystal
class UserSchema < CQL::Schema(UserDB)
  table :users do |t|
    t.integer :id, primary: true, auto_increment: true
    t.string :email, null: false, index: {unique: true}
    t.string :username, null: false, index: {unique: true}
    t.string :first_name, null: false, index: true
    t.string :last_name, null: false, index: true
    t.integer :age, index: true
    t.boolean :active, default: true, index: true
    t.timestamp :created_at, null: false, index: true
    t.timestamp :updated_at, null: false

    # Composite indexes for common query patterns
    t.index([:last_name, :first_name])
    t.index([:active, :created_at])
    t.index([:status, :updated_at])
  end
end
```

### Relationship Design

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)
  db_context schema: UserDB, table: :users

  property id : Int64 = 0
  property name : String
  property email : String

  # ✅ Clear, descriptive relationships
  has_many :posts, Post, foreign_key: :author_id
  has_many :comments, Comment, foreign_key: :commenter_id
  has_one :profile, UserProfile, foreign_key: :user_id

  # ✅ Many-to-many with join table
  has_many :user_roles, UserRole, foreign_key: :user_id
  has_many :roles, Role, through: :user_roles
end

class Post
  include CQL::ActiveRecord::Model(Int64)

  property id : Int64 = 0
  property title : String
  property content : String
  property author_id : Int64

  belongs_to :author, User, foreign_key: :author_id
  has_many :comments, Comment, foreign_key: :post_id
end
```

## Model Architecture

### Single Responsibility Principle

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

### Validation Patterns

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

### Callback Patterns

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
```

## Query Optimization

### Efficient Query Patterns

```crystal
# ✅ Good: Only load what you need
users = User.select(:id, :name, :email)
           .where(active: true)
           .order(name: :asc)
           .limit(50)
           .all

# ✅ Good: Use appropriate query methods
user = User.find_by!(email: "user@example.com")
users = User.where(age: 25..35).all
count = User.where(active: true).count

# ✅ Good: Efficient joins
posts_with_authors = Post.join(:author)
                        .where { author.active.eq(true) }
                        .select("posts.title", "users.name as author_name")
                        .all
```

#### Inefficient Query Patterns

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

### Pagination Best Practices

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

### Batch Processing

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

## Security Best Practices

### SQL Injection Prevention

```crystal
# ✅ Good: Use parameterized queries (CQL handles this automatically)
def find_users_by_name(name : String)
  User.where(name: name).all                    # ✅ Safe - parameterized
end

def find_users_by_age_range(min_age : Int32, max_age : Int32)
  User.where { (age >= min_age) & (age <= max_age) }.all  # ✅ Safe
end
```

### Input Validation

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

### Mass Assignment Protection

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
end
```

## Performance Guidelines

### Use Appropriate Indexes

```crystal
# ✅ Index frequently queried columns
table :users do
  column :email, String, index: {unique: true}
  column :status, String, index: true
  column :created_at, Time, index: true

  # Composite indexes for common query patterns
  index [:status, :created_at]
  index [:active, :last_login]
end
```

### Avoid N+1 Queries

```crystal
# ❌ Bad: N+1 queries
posts = Post.all
posts.each { |post| puts post.user.name }

# ✅ Good: Eager loading
posts = Post.join(:user).all
posts.each { |post| puts post.user.name }

# ✅ Good: Preload associations
posts = Post.includes(:user).all
posts.each { |post| puts post.user.name }
```

### Use Database-Level Operations

```crystal
# ✅ Good: Database-level aggregations
user_count = User.where(active: true).count
total_revenue = Order.where(status: "completed").sum(:amount)

# ❌ Bad: Application-level aggregations
users = User.where(active: true).all
user_count = users.size  # Loads all records unnecessarily
```

## Error Handling

### Use Appropriate Exception Types

```crystal
class UserService
  def find_user!(id : Int64)
    User.find(id) || raise CQL::RecordNotFound.new("User not found")
  end

  def create_user(attributes)
    user = User.new(**attributes)

    if user.valid?
      user.save!
    else
      raise CQL::RecordInvalid.new(user.errors)
    end
  end
end
```

### Transaction Error Handling

```crystal
def transfer_credits(from_user : User, to_user : User, amount : Int32)
  User.transaction do
    from_user.decrement!(:credits, amount)
    to_user.increment!(:credits, amount)

    CreditTransfer.create!(
      from_user: from_user,
      to_user: to_user,
      amount: amount
    )
  end
rescue CQL::RecordInvalid => ex
  # Handle validation errors
  log_error("Credit transfer failed: #{ex.message}")
  raise
rescue CQL::DatabaseError => ex
  # Handle database errors
  log_error("Database error during credit transfer: #{ex.message}")
  raise
end
```

## Testing Guidelines

### Use Appropriate Test Database

```crystal
# Test configuration
TestDB = CQL::Schema.define(
  :test,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://:memory:"  # Fast in-memory database
)

# Clean database between tests
Spec.before_each do
  TestDB.tables.each { |name, _| TestDB.query("DELETE FROM #{name}").commit }
end
```

### Test Factory Pattern

```crystal
module UserFactory
  def self.build(attributes = {} of Symbol => String | Int32 | Bool)
    defaults = {
      :name => "Test User",
      :email => "test@example.com",
      :active => true
    }

    User.new(**defaults.merge(attributes))
  end

  def self.create!(attributes = {} of Symbol => String | Int32 | Bool)
    build(attributes).tap(&.save!)
  end
end

# Usage in tests
describe User do
  it "validates email presence" do
    user = UserFactory.build(email: "")
    user.valid?.should be_false
    user.errors[:email].should contain("can't be blank")
  end
end
```

This guide provides the essential best practices for building maintainable, performant CQL applications.
