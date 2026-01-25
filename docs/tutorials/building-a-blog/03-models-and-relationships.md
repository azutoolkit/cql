# Part 3: Models and Relationships

In this part, you'll create Active Record models for your blog engine and define the relationships between them. You'll learn how to map database tables to Crystal structs and navigate between related records.

## What You'll Learn

- Creating Active Record models
- Defining model properties
- Setting up belongs_to relationships
- Setting up has_many relationships
- Adding custom model methods
- Navigating between related records

## Prerequisites

- Completed [Part 2: Database Schema](02-database-schema.md)

## Step 1: Create the User Model

```crystal
# src/models/user.cr
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :users

  property id : Int64?
  property username : String
  property email : String
  property first_name : String?
  property last_name : String?
  property active : Bool = true
  property created_at : Time?
  property updated_at : Time?

  # Relationships
  has_many :posts, Post, foreign_key: :user_id
  has_many :comments, Comment, foreign_key: :user_id

  def initialize(
    @username : String,
    @email : String,
    @first_name : String? = nil,
    @last_name : String? = nil,
    @active : Bool = true
  )
  end

  # Custom methods
  def full_name : String
    if first_name && last_name
      "#{first_name} #{last_name}"
    elsif first_name
      first_name.not_nil!
    else
      username
    end
  end

  def display_name : String
    first_name || username
  end
end
```

Key points:
- `include CQL::ActiveRecord::Model(Int64)` - Makes this an Active Record model with Int64 primary key
- `db_context BlogDB, :users` - Connects model to the `users` table in `BlogDB`
- `property` defines model attributes matching database columns
- `has_many` defines one-to-many relationships
- Custom methods add business logic

## Step 2: Create the Category Model

```crystal
# src/models/category.cr
struct Category
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :categories

  property id : Int64?
  property name : String
  property slug : String
  property created_at : Time?
  property updated_at : Time?

  # Relationships
  has_many :posts, Post, foreign_key: :category_id

  def initialize(@name : String, @slug : String? = nil)
    @slug ||= generate_slug(@name)
  end

  # Generate URL-friendly slug from name
  private def generate_slug(text : String) : String
    text.downcase
        .gsub(/[^a-z0-9\s-]/, "")
        .gsub(/\s+/, "-")
        .gsub(/-+/, "-")
        .strip("-")
  end
end
```

The `generate_slug` method automatically creates URL-friendly slugs from category names.

## Step 3: Create the Post Model

```crystal
# src/models/post.cr
struct Post
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :posts

  property id : Int64?
  property title : String
  property content : String
  property published : Bool = false
  property views_count : Int64 = 0_i64
  property user_id : Int64
  property category_id : Int64?
  property created_at : Time?
  property updated_at : Time?

  # Relationships
  belongs_to :user, User, foreign_key: :user_id
  belongs_to :category, Category, foreign_key: :category_id
  has_many :comments, Comment, foreign_key: :post_id

  def initialize(
    @title : String,
    @content : String,
    @user_id : Int64,
    @category_id : Int64? = nil,
    @published : Bool = false,
    @views_count : Int64 = 0_i64
  )
  end

  # Custom methods
  def published? : Bool
    published
  end

  def draft? : Bool
    !published
  end

  def word_count : Int32
    content.split.size
  end

  def reading_time_minutes : Int32
    (word_count / 200.0).ceil.to_i  # Assuming 200 words per minute
  end

  def excerpt(length : Int32 = 150) : String
    if content.size <= length
      content
    else
      content[0, length].rstrip + "..."
    end
  end

  def increment_views!
    @views_count += 1
    save
  end
end
```

Key points:
- `belongs_to` defines many-to-one relationships
- `category_id` is nilable (`Int64?`) because category is optional
- Custom methods provide useful functionality like word count and excerpts

## Step 4: Create the Comment Model

```crystal
# src/models/comment.cr
struct Comment
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :comments

  property id : Int64?
  property content : String
  property post_id : Int64
  property user_id : Int64?  # Nullable for anonymous comments
  property created_at : Time?
  property updated_at : Time?

  # Relationships
  belongs_to :post, Post, foreign_key: :post_id
  belongs_to :user, User, foreign_key: :user_id

  def initialize(
    @content : String,
    @post_id : Int64,
    @user_id : Int64? = nil
  )
  end

  # Custom methods
  def anonymous? : Bool
    user_id.nil?
  end

  def author_name : String
    if u = user
      u.display_name
    else
      "Anonymous"
    end
  end
end
```

## Step 5: Update the Main File

Update `blog_engine.cr` to require all models:

```crystal
# src/blog_engine.cr
require "./database"
require "./models/user"
require "./models/category"
require "./models/post"
require "./models/comment"

module BlogEngine
  VERSION = "0.1.0"

  def self.setup
    BlogDB.init
    puts "Database connected"
  end

  def self.migrate
    require "../migrations/*"

    migrator = BlogDB.migrator(MIGRATOR_CONFIG)
    pending = migrator.pending_migrations.size

    if pending > 0
      puts "Running #{pending} pending migration(s)..."
      migrator.up
      puts "Migrations complete"
    else
      puts "Database is up to date"
    end
  end
end
```

Note: Order matters! Models with dependencies must be required after their dependencies.

## Step 6: Test the Models

Create a test script:

```crystal
# src/test_models.cr
require "./blog_engine"

BlogEngine.setup

puts "Testing Models"
puts "=============="

# Create a user
alice = User.new(
  username: "alice",
  email: "alice@example.com",
  first_name: "Alice",
  last_name: "Johnson"
)

if alice.save
  puts "Created user: #{alice.full_name} (ID: #{alice.id})"
else
  puts "Failed to create user"
  exit 1
end

# Create a category
tech = Category.new(name: "Technology")
if tech.save
  puts "Created category: #{tech.name} (slug: #{tech.slug})"
end

# Create a post
post = Post.new(
  title: "Getting Started with Crystal",
  content: "Crystal is a wonderful programming language...",
  user_id: alice.id.not_nil!,
  category_id: tech.id,
  published: true
)

if post.save
  puts "Created post: #{post.title}"
  puts "  Word count: #{post.word_count}"
  puts "  Reading time: #{post.reading_time_minutes} min"
end

# Create a comment
comment = Comment.new(
  content: "Great article!",
  post_id: post.id.not_nil!,
  user_id: alice.id
)

if comment.save
  puts "Created comment by: #{comment.author_name}"
end

# Test relationships
puts ""
puts "Testing Relationships"
puts "====================="

# User -> Posts
puts "#{alice.full_name}'s posts:"
alice.posts.all.each do |p|
  puts "  - #{p.title}"
end

# Post -> User (author)
puts ""
puts "Post author: #{post.user.try(&.full_name)}"

# Post -> Category
puts "Post category: #{post.category.try(&.name)}"

# Post -> Comments
puts "Post comments: #{post.comments.all.size}"

# Comment -> User
puts "Comment author: #{comment.author_name}"

puts ""
puts "All tests passed!"
```

Run it:

```shell
crystal src/test_models.cr
```

## Understanding Relationships

### belongs_to

```crystal
belongs_to :user, User, foreign_key: :user_id
```

This creates a `user` method that returns the associated User (or nil):

```crystal
post = Post.find(1)
author = post.user  # Returns User?
```

### has_many

```crystal
has_many :posts, Post, foreign_key: :user_id
```

This creates a `posts` method that returns a query builder:

```crystal
user = User.find(1)
all_posts = user.posts.all           # Get all posts
published = user.posts.where(published: true).all  # Filter
count = user.posts.count             # Count posts
```

## Model Best Practices

1. **Keep models focused**: Business logic belongs in models, not controllers
2. **Use meaningful method names**: `published?` is clearer than `is_published`
3. **Validate early**: Add validations to catch errors before database operations
4. **Handle nil safely**: Use `try(&.method)` when accessing optional relationships
5. **Add useful computed properties**: Like `full_name`, `word_count`, etc.

## Summary

In this part, you:

1. Created four Active Record models: User, Category, Post, Comment
2. Defined properties matching database columns
3. Set up belongs_to and has_many relationships
4. Added custom methods for business logic
5. Tested model creation and relationship navigation

## Next Steps

In [Part 4: CRUD Operations](04-crud-operations.md), you'll learn how to create, read, update, and delete records efficiently, including bulk operations and querying patterns.

---

**Tutorial Navigation:**
- [Part 1: Project Setup](01-project-setup.md)
- [Part 2: Database Schema](02-database-schema.md)
- Part 3: Models and Relationships (current)
- [Part 4: CRUD Operations](04-crud-operations.md)
- [Part 5: Adding Features](05-adding-features.md)
