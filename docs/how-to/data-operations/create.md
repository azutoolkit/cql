# Create Records

This guide shows you how to create new records in the database.

## Create with new + save

Create an instance and save separately:

```crystal
user = User.new("John", "john@example.com")

if user.save
  puts "Created user #{user.id}"
else
  puts "Failed: #{user.errors.map(&.message).join(", ")}"
end
```

## Create with save!

Use `save!` to raise an exception on failure:

```crystal
user = User.new("John", "john@example.com")
user.save!  # Raises if validation fails
puts "Created user #{user.id}"
```

## Create in One Step

Use `create` to instantiate and save:

```crystal
user = User.create(name: "John", email: "john@example.com")

if user.persisted?
  puts "Created user #{user.id}"
else
  puts "Failed to create"
end
```

## Create! in One Step

Use `create!` to raise on failure:

```crystal
user = User.create!(
  name: "John",
  email: "john@example.com",
  age: 30
)
puts "Created user #{user.id}"
```

## Create Multiple Records

```crystal
users = ["Alice", "Bob", "Charlie"].map do |name|
  User.create!(
    name: name,
    email: "#{name.downcase}@example.com"
  )
end

puts "Created #{users.size} users"
```

## Create with Relationships

```crystal
user = User.create!(name: "John", email: "john@example.com")

post = Post.create!(
  title: "My First Post",
  body: "Hello world!",
  user_id: user.id.not_nil!
)

puts "Created post for user #{user.name}"
```

## Create with Default Values

Set defaults in your model:

```crystal
struct User
  property status : String = "pending"
  property role : String = "user"
end

user = User.create!(name: "John", email: "john@example.com")
user.status  # => "pending"
user.role    # => "user"
```

## Create with Timestamp

Timestamps are set automatically if configured:

```crystal
user = User.create!(name: "John", email: "john@example.com")
user.created_at  # => 2024-01-15 10:30:00 UTC
user.updated_at  # => 2024-01-15 10:30:00 UTC
```

## Handle Validation Errors

```crystal
user = User.new("", "invalid-email")

unless user.save
  user.errors.each do |error|
    puts "#{error.field}: #{error.message}"
  end
end
```

## Verify Creation

```crystal
user = User.create!(name: "John", email: "john@example.com")

user.id.nil?        # => false (has ID now)
user.persisted?     # => true
user.new_record?    # => false
```

## Related

- [Update Records](update.md)
- [Delete Records](delete.md)
- [Use Transactions](transactions.md)
