# Find Records

This guide shows you how to find records by their primary key or attributes.

## Find by ID

```crystal
user = User.find(1)
if user
  puts "Found: #{user.name}"
else
  puts "Not found"
end
```

## Find by ID (raise if not found)

```crystal
user = User.find!(1)  # Raises if not found
puts user.name
```

## Find by Attribute

```crystal
user = User.find_by(email: "john@example.com")
puts user.try(&.name)
```

## Find by Multiple Attributes

```crystal
post = Post.find_by(user_id: 1, published: true)
```

## Find First Record

```crystal
user = User.first
puts user.try(&.name)
```

## Find Last Record

```crystal
user = User.last
puts user.try(&.name)
```

## Find All Records

```crystal
users = User.all
users.each { |u| puts u.name }
```

## Find with Order

```crystal
# First by creation date
oldest = User.order(created_at: :asc).first

# Last by creation date
newest = User.order(created_at: :desc).first
```

## Check if Record Exists

```crystal
exists = User.exists?(email: "john@example.com")
puts "User exists: #{exists}"
```

## Find or Initialize

```crystal
user = User.find_by(email: "john@example.com")
user ||= User.new("John", "john@example.com")
```

## Safe Navigation

Use `try` for safe access:

```crystal
user = User.find(1)
name = user.try(&.name) || "Unknown"
```

## Verify Find Works

```crystal
User.create!(name: "John", email: "john@example.com")

User.find_by(name: "John")  # => User instance
User.find_by(name: "Jane")  # => nil
```

## Related

- [Filter with Where Clauses](filter-records.md)
- [Build Complex Queries](complex-queries.md)
- [Paginate Results](pagination.md)
