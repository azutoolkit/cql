# Part 5: Adding Features

In this final part, you'll enhance your blog engine with validations, callbacks, transactions, and performance monitoring. You'll also learn how to seed data and prepare your application for production.

## What You'll Learn

- Adding model validations
- Using lifecycle callbacks
- Implementing transactions
- Seeding sample data
- Performance monitoring basics
- Production considerations

## Prerequisites

- Completed [Part 4: CRUD Operations](04-crud-operations.md)

## Step 1: Add Validations

Validations ensure data integrity before records are saved.

### User Validations

Update your User model:

```crystal
# src/models/user.cr
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :users

  # ... existing properties ...

  # Validations
  validate :username, presence: true, size: (3..50)
  validate :email, presence: true, match: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

  # Custom validation
  def validate
    super
    validate_username_uniqueness
    validate_email_uniqueness
  end

  private def validate_username_uniqueness
    existing = User.find_by(username: @username)
    if existing && existing.id != @id
      errors.add(:username, "has already been taken")
    end
  end

  private def validate_email_uniqueness
    existing = User.find_by(email: @email)
    if existing && existing.id != @id
      errors.add(:email, "has already been taken")
    end
  end
end
```

### Post Validations

```crystal
# src/models/post.cr
struct Post
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :posts

  # ... existing properties ...

  # Validations
  validate :title, presence: true, size: (1..200)
  validate :content, presence: true

  def validate
    super
    validate_title_length
  end

  private def validate_title_length
    if @title.size > 200
      errors.add(:title, "is too long (maximum 200 characters)")
    end
  end
end
```

### Using Validations

```crystal
# Test validations
user = User.new(username: "ab", email: "invalid")

if user.valid?
  user.save
else
  puts "Validation errors:"
  user.errors.each do |field, messages|
    messages.each do |message|
      puts "  #{field}: #{message}"
    end
  end
end
```

## Step 2: Add Callbacks

Callbacks let you run code at specific points in a model's lifecycle.

### User Callbacks

```crystal
# src/models/user.cr
struct User
  # ... existing code ...

  # Callbacks
  before_save :normalize_email
  after_create :send_welcome_notification

  private def normalize_email
    @email = @email.downcase.strip
  end

  private def send_welcome_notification
    # In a real app, this would send an email or create a notification
    puts "Welcome, #{display_name}! Your account has been created."
  end
end
```

### Post Callbacks

```crystal
# src/models/post.cr
struct Post
  # ... existing code ...

  # Callbacks
  before_save :update_timestamps
  after_save :notify_subscribers

  private def update_timestamps
    now = Time.utc
    @created_at ||= now
    @updated_at = now
  end

  private def notify_subscribers
    if @published && changes.includes?(:published)
      # Notify subscribers about new post
      puts "Notifying subscribers about: #{@title}"
    end
  end
end
```

### Category Callbacks

```crystal
# src/models/category.cr
struct Category
  # ... existing code ...

  before_save :generate_slug_if_blank

  private def generate_slug_if_blank
    if @slug.blank?
      @slug = generate_slug(@name)
    end
  end
end
```

## Step 3: Implement Transactions

Transactions ensure multiple operations succeed or fail together.

### Creating a Post with Comments

```crystal
def create_post_with_comments(author : User, title : String, content : String, comment_texts : Array(String))
  Post.transaction do
    post = Post.create!(
      title: title,
      content: content,
      user_id: author.id.not_nil!,
      published: true
    )

    comment_texts.each do |text|
      Comment.create!(
        content: text,
        post_id: post.id.not_nil!,
        user_id: author.id
      )
    end

    puts "Created post with #{comment_texts.size} comments"
    post
  end
end
```

### User Registration with Profile

```crystal
def register_user(username : String, email : String, bio : String?)
  User.transaction do
    user = User.create!(
      username: username,
      email: email
    )

    # Create welcome post
    Post.create!(
      title: "Welcome to my blog!",
      content: "Hi, I'm #{user.display_name}. #{bio || "Welcome to my blog!"}",
      user_id: user.id.not_nil!,
      published: true
    )

    user
  end
rescue ex
  puts "Registration failed: #{ex.message}"
  nil
end
```

## Step 4: Create a Seeder

Create a script to populate your database with sample data:

```crystal
# src/seeders.cr
require "./blog_engine"

module Seeders
  def self.run
    puts "Seeding database..."

    # Create users
    users = create_users
    puts "Created #{users.size} users"

    # Create categories
    categories = create_categories
    puts "Created #{categories.size} categories"

    # Create posts
    posts = create_posts(users, categories)
    puts "Created #{posts.size} posts"

    # Create comments
    comments = create_comments(users, posts)
    puts "Created #{comments.size} comments"

    puts "Seeding complete!"
  end

  private def self.create_users
    [
      {username: "alice", email: "alice@example.com", first_name: "Alice", last_name: "Johnson"},
      {username: "bob", email: "bob@example.com", first_name: "Bob", last_name: "Smith"},
      {username: "charlie", email: "charlie@example.com", first_name: "Charlie", last_name: "Brown"},
    ].map do |attrs|
      User.create!(
        username: attrs[:username],
        email: attrs[:email],
        first_name: attrs[:first_name],
        last_name: attrs[:last_name]
      )
    end
  end

  private def self.create_categories
    ["Technology", "Lifestyle", "Travel", "Food", "Programming"].map do |name|
      Category.create!(name: name)
    end
  end

  private def self.create_posts(users : Array(User), categories : Array(Category))
    posts = [] of Post

    users.each do |user|
      rand(2..5).times do |i|
        category = categories.sample
        posts << Post.create!(
          title: "#{user.display_name}'s Post ##{i + 1}",
          content: "This is a sample blog post by #{user.full_name}. " * 10,
          user_id: user.id.not_nil!,
          category_id: category.id,
          published: rand < 0.8,  # 80% published
          views_count: rand(0_i64..500_i64)
        )
      end
    end

    posts
  end

  private def self.create_comments(users : Array(User), posts : Array(Post))
    comments = [] of Comment

    posts.select(&.published?).each do |post|
      rand(0..5).times do
        commenter = rand < 0.9 ? users.sample : nil  # 10% anonymous
        comments << Comment.create!(
          content: "Great post! " + ["I learned a lot.", "Thanks for sharing.", "Very helpful!"].sample,
          post_id: post.id.not_nil!,
          user_id: commenter.try(&.id)
        )
      end
    end

    comments
  end
end

# Run if executed directly
if PROGRAM_NAME.includes?("seeders")
  BlogEngine.setup
  Seeders.run
end
```

Run the seeder:

```shell
crystal src/seeders.cr
```

## Step 5: Add Performance Monitoring

Track query performance to identify issues:

```crystal
# src/monitoring.cr
require "./blog_engine"

module Monitoring
  def self.print_stats
    puts ""
    puts "Blog Statistics"
    puts "==============="
    puts ""

    # Basic counts
    puts "Content:"
    puts "  Users: #{User.count} (#{User.where(active: true).count} active)"
    puts "  Categories: #{Category.count}"
    puts "  Posts: #{Post.count} (#{Post.where(published: true).count} published)"
    puts "  Comments: #{Comment.count}"
    puts ""

    # Engagement
    puts "Engagement:"
    total_views = Post.where(published: true).sum(:views_count)
    avg_views = Post.where(published: true).count > 0 ?
                total_views / Post.where(published: true).count : 0
    puts "  Total views: #{total_views}"
    puts "  Average views per post: #{avg_views}"
    puts ""

    # Top content
    puts "Top Posts by Views:"
    Post.where(published: true)
        .order(views_count: :desc)
        .limit(5)
        .all
        .each do |post|
      author = post.user.try(&.display_name) || "Unknown"
      puts "  #{post.views_count} views - \"#{post.title}\" by #{author}"
    end
    puts ""

    # Most active users
    puts "Most Active Authors:"
    User.all
        .map { |u| {user: u, count: u.posts.where(published: true).count} }
        .sort_by { |h| -h[:count] }
        .first(5)
        .each do |h|
      puts "  #{h[:count]} posts - #{h[:user].full_name}"
    end
  end
end

# Run if executed directly
if PROGRAM_NAME.includes?("monitoring")
  BlogEngine.setup
  Monitoring.print_stats
end
```

## Step 6: Create the Complete Demo

Put everything together:

```crystal
# src/demo.cr
require "./blog_engine"
require "./seeders"
require "./monitoring"

puts "="*60
puts "CQL Blog Engine Demo"
puts "="*60
puts ""

# Setup
BlogEngine.setup
BlogEngine.migrate

# Seed data if database is empty
if User.count == 0
  Seeders.run
end

# Show statistics
Monitoring.print_stats

# Demonstrate queries
puts ""
puts "Recent Published Posts:"
puts "-"*40

Post.where(published: true)
    .order(created_at: :desc)
    .limit(5)
    .all
    .each do |post|
  author = post.user.try(&.full_name) || "Unknown"
  comment_count = post.comments.count
  puts ""
  puts "#{post.title}"
  puts "  by #{author}"
  puts "  #{post.word_count} words | #{post.views_count} views | #{comment_count} comments"
  puts "  #{post.excerpt(100)}"
end

puts ""
puts "="*60
puts "Demo complete!"
puts "="*60
```

Run the demo:

```shell
crystal src/demo.cr
```

## Production Considerations

### Database Configuration

For production, switch to PostgreSQL:

```crystal
# src/database.cr
adapter = if ENV["CRYSTAL_ENV"]? == "production"
  CQL::Adapter::Postgres
else
  CQL::Adapter::SQLite
end

uri = ENV["DATABASE_URL"]? || "sqlite3://./db/development.db"

BlogDB = CQL::Schema.define(:blog_db, adapter: adapter, uri: uri) do
end
```

### Environment Variables

```shell
# Production
export CRYSTAL_ENV=production
export DATABASE_URL=postgres://user:pass@host:5432/blog_production
```

### Security Checklist

1. **Input Validation**: All user input is validated
2. **Parameterized Queries**: CQL uses parameterized queries by default
3. **Authentication**: Add authentication before deploying (not covered in this tutorial)
4. **Authorization**: Ensure users can only modify their own content
5. **Rate Limiting**: Add rate limiting for API endpoints

### Performance Checklist

1. **Indexes**: Ensure indexes on frequently queried columns
2. **N+1 Queries**: Use eager loading for relationships
3. **Pagination**: Always paginate large result sets
4. **Caching**: Add caching for expensive queries
5. **Connection Pooling**: Configure appropriate pool sizes

## Summary

In this tutorial series, you built a complete blog engine:

1. **Part 1**: Set up the project and configured CQL
2. **Part 2**: Designed and created the database schema
3. **Part 3**: Built models with relationships
4. **Part 4**: Implemented CRUD operations
5. **Part 5**: Added validations, callbacks, transactions, and monitoring

## What's Next?

Continue learning with:

- [How-to Guides](../../how-to/README.md) - Task-specific instructions
- [Reference](../../reference/README.md) - API documentation
- [Explanation](../../explanation/README.md) - Conceptual deep-dives

### Ideas for Extending Your Blog

- Add user authentication
- Implement post tagging
- Add image uploads
- Create an RSS feed
- Build a REST API
- Add full-text search
- Implement caching

---

**Tutorial Navigation:**
- [Part 1: Project Setup](01-project-setup.md)
- [Part 2: Database Schema](02-database-schema.md)
- [Part 3: Models and Relationships](03-models-and-relationships.md)
- [Part 4: CRUD Operations](04-crud-operations.md)
- Part 5: Adding Features (current)

---

Congratulations on completing the Building a Blog tutorial series!
