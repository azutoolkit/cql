# Use Transactions

This guide shows you how to use database transactions to ensure multiple operations succeed or fail together.

## Basic Transaction

Wrap operations in a transaction block:

```crystal
User.transaction do
  user = User.create!(name: "John", email: "john@example.com")
  Profile.create!(user_id: user.id.not_nil!, bio: "Hello")
end
# Both records created, or neither
```

## Automatic Rollback on Error

If any operation fails, all changes are rolled back:

```crystal
User.transaction do
  user = User.create!(name: "John", email: "john@example.com")
  raise "Something went wrong!"  # Triggers rollback
  Profile.create!(user_id: user.id.not_nil!, bio: "Hello")
end
# Neither record is created
```

## Handle Transaction Errors

```crystal
begin
  User.transaction do
    user = User.create!(name: "John", email: "john@example.com")
    # ... more operations
  end
  puts "Transaction successful"
rescue ex
  puts "Transaction failed: #{ex.message}"
end
```

## Transfer Between Records

Classic use case - moving money between accounts:

```crystal
def transfer(from_id : Int64, to_id : Int64, amount : BigDecimal)
  Account.transaction do
    from = Account.find!(from_id)
    to = Account.find!(to_id)

    raise "Insufficient funds" if from.balance < amount

    from.balance -= amount
    to.balance += amount

    from.save!
    to.save!
  end
end
```

## Create Related Records

```crystal
def create_post_with_comments(author : User, title : String, comments : Array(String))
  Post.transaction do
    post = Post.create!(
      title: title,
      body: "Post body",
      user_id: author.id.not_nil!
    )

    comments.each do |comment_text|
      Comment.create!(
        body: comment_text,
        post_id: post.id.not_nil!,
        user_id: author.id
      )
    end

    post
  end
end
```

## Nested Operations

All nested operations are part of the same transaction:

```crystal
User.transaction do
  user = User.create!(name: "John", email: "john@example.com")

  # These are all part of the same transaction
  3.times do |i|
    Post.create!(
      title: "Post #{i + 1}",
      body: "Content",
      user_id: user.id.not_nil!
    )
  end
end
```

## Manual Rollback

Raise an exception to trigger rollback:

```crystal
User.transaction do
  user = User.create!(name: "John", email: "john@example.com")

  if some_condition_fails
    raise "Validation failed"  # Rolls back the transaction
  end

  # Continue with more operations
end
```

## Transaction with Return Value

Return a value from the transaction:

```crystal
result = User.transaction do
  user = User.create!(name: "John", email: "john@example.com")
  profile = Profile.create!(user_id: user.id.not_nil!)
  {user: user, profile: profile}
end

puts "Created user: #{result[:user].name}"
```

## Cleanup Operations

Ensure cleanup happens even on failure:

```crystal
begin
  User.transaction do
    # Operations that might fail
    user = User.create!(name: "John", email: "john@example.com")
    external_api.create_account(user)  # Might fail
  end
rescue ex
  # Handle or log the error
  Log.error { "Transaction failed: #{ex.message}" }
  raise ex
end
```

## Verify Transaction Behavior

```crystal
initial_count = User.count

begin
  User.transaction do
    User.create!(name: "Test", email: "test@example.com")
    raise "Rollback!"
  end
rescue
end

User.count == initial_count  # => true (rolled back)
```

## Related

- [Create Records](create.md)
- [Update Records](update.md)
- [Add Optimistic Locking](../models/optimistic-locking.md)
