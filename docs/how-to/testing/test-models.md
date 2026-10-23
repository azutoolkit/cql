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

    it "reports which field failed" do
      user = User.new("John", "invalid-email")
      user.errors.map(&.field).should contain(:email)
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

    it "raises for an invalid record" do
      user = User.new("John", "invalid-email")
      expect_raises(CQL::ActiveRecord::Validations::ValidationError) do
        user.save!
      end
    end
  end

  describe ".find" do
    it "retrieves a saved user" do
      user = User.create!(name: "John", email: "john@example.com")
      found = User.find(user.id!)
      found.should_not be_nil
      found.not_nil!.name.should eq("John")
    end

    it "returns nil for a missing id" do
      User.find(0).should be_nil
      expect_raises(DB::NoResultsError) { User.find!(0) }
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
      post = Post.create!(user_id: user.id!, title: "Test", body: "Body")

      post.user.try(&.id).should eq(user.id)
    end

    it "has many comments" do
      user = User.create!(name: "John", email: "john@example.com")
      post = Post.create!(user_id: user.id!, title: "Test", body: "Body")
      Comment.create!(post_id: post.id!, body: "Nice!")
      Comment.create!(post_id: post.id!, body: "Great!")

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
      Post.published.first!.title.should eq("Published")
    end

    it ".draft returns only draft posts" do
      Post.draft.count.should eq(1)
    end
  end
end
```

## Test Helpers

Create helpers for common operations:

```crystal
module TestHelpers
  def self.create_user(name = "Test User", email = "test@example.com")
    User.create!(name: name, email: email)
  end

  def self.create_post(user : User, title = "Test Post")
    Post.create!(user_id: user.id!, title: title, body: "Content")
  end
end

# In a spec
user = TestHelpers.create_user
post = TestHelpers.create_post(user)
```

## Factory Pattern

```crystal
module Factory
  def self.user(name : String = "Test User #{rand(1000)}", email : String = "test#{rand(100000)}@example.com")
    User.create!(name: name, email: email)
  end

  def self.post(user : User? = nil, title : String = "Test Post", body : String = "Test content")
    user ||= self.user
    Post.create!(user_id: user.id!, title: title, body: body)
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
    raise DB::Rollback.new  # Always rollback
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
