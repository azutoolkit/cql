# Test Models

Write effective tests for your CQL Active Record models.

## Prerequisites

- CQL application with models
- Crystal spec testing framework
- Test database configured

## Basic Model Tests

```crystal
require "spec"
require "../src/models/*"

describe User do
  describe "#valid?" do
    it "is valid with valid attributes" do
      user = User.new("John", "john@example.com")
      user.valid?.should be_true
    end

    it "is invalid without email" do
      user = User.new("John", "")
      user.valid?.should be_false
    end

    it "is invalid with malformed email" do
      user = User.new("John", "invalid-email")
      user.valid?.should be_false
    end
  end
end
```

## Testing Persistence

```crystal
describe User do
  describe "#save" do
    it "persists to database" do
      user = User.new("John", "john@example.com")
      user.save.should be_true
      user.id.should_not be_nil
    end

    it "sets timestamps" do
      user = User.new("John", "john@example.com")
      user.save
      user.created_at.should_not be_nil
    end
  end

  describe ".find" do
    it "retrieves a saved user" do
      user = User.create!(name: "John", email: "john@example.com")
      found = User.find(user.id.not_nil!)
      found.should_not be_nil
      found.not_nil!.name.should eq("John")
    end
  end
end
```

## Testing Callbacks

```crystal
describe Post do
  describe "callbacks" do
    it "generates slug before save" do
      post = Post.new(title: "Hello World", body: "Content")
      post.save
      post.slug.should eq("hello-world")
    end

    it "normalizes title" do
      post = Post.new(title: "  HELLO  ", body: "Content")
      post.save
      post.title.should eq("Hello")
    end
  end
end
```

## Testing Relationships

```crystal
describe Post do
  describe "relationships" do
    it "belongs to user" do
      user = User.create!(name: "John", email: "john@example.com")
      post = Post.create!(user_id: user.id.not_nil!, title: "Test", body: "Body")

      post.user.id.should eq(user.id)
    end

    it "has many comments" do
      post = Post.create!(user_id: 1, title: "Test", body: "Body")
      Comment.create!(post_id: post.id.not_nil!, body: "Nice!")
      Comment.create!(post_id: post.id.not_nil!, body: "Great!")

      post.comments.count.should eq(2)
    end
  end
end
```

## Testing Scopes

```crystal
describe Post do
  describe "scopes" do
    before_each do
      Post.create!(title: "Published", body: "...", published: true)
      Post.create!(title: "Draft", body: "...", published: false)
    end

    it ".published returns only published posts" do
      Post.published.count.should eq(1)
      Post.published.first.not_nil!.title.should eq("Published")
    end

    it ".drafts returns only draft posts" do
      Post.drafts.count.should eq(1)
    end
  end
end
```

## Test Helpers

Create helpers for common operations:

```crystal
module TestHelpers
  def create_user(name = "Test User", email = "test@example.com")
    User.create!(name: name, email: email)
  end

  def create_post(user : User, title = "Test Post")
    Post.create!(user_id: user.id.not_nil!, title: title, body: "Content")
  end
end

Spec.before_each do
  extend TestHelpers
end
```

## Factory Pattern

```crystal
module Factory
  def self.user(attrs = {} of Symbol => String)
    User.create!(
      name: attrs[:name]? || "Test User #{rand(1000)}",
      email: attrs[:email]? || "test#{rand(1000)}@example.com"
    )
  end

  def self.post(user : User? = nil, attrs = {} of Symbol => String)
    user ||= self.user
    Post.create!(
      user_id: user.id.not_nil!,
      title: attrs[:title]? || "Test Post",
      body: attrs[:body]? || "Test content"
    )
  end
end

# Usage
user = Factory.user(name: "John")
post = Factory.post(user, title: "My Post")
```

## Database Cleanup

Clean up between tests:

```crystal
Spec.before_each do
  # Truncate tables
  MyDB.exec("TRUNCATE users, posts, comments RESTART IDENTITY CASCADE")
end

# Or use transactions
Spec.around_each do |example|
  MyDB.transaction do
    example.run
    raise Rollback.new  # Always rollback
  end
end
```

## Running Tests

```bash
# Run all tests
crystal spec

# Run specific file
crystal spec spec/models/user_spec.cr

# Run with verbose output
crystal spec --verbose
```

## See Also

- [Set Up Test Databases](test-database.md)
- [Add Validations](../models/add-validations.md)
- [Use Callbacks](../models/use-callbacks.md)
