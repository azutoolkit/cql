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

`find?` is an alias of `find`.

`find` renders its `SELECT … WHERE id = ? LIMIT ?` once per model and reuses it, binding only the id, so repeated lookups skip query building. A model that overrides `self.query` (for example to add a tenant filter that changes per call), and any subclass of a model, gets its statement rendered on every call instead, so the override is always applied. The same goes for an array of ids. SoftDeletable's built-in `deleted_at IS NULL` filter is reused like the plain query.

## Find by ID (raise if not found)

```crystal
user = User.find!(1)  # Raises DB::NoResultsError if not found
puts user.name
```

## Find by Attribute

```crystal
user = User.find_by(email: "john@example.com")   # => User? (nil when no match)
puts user.try(&.name)

user = User.find_by!(email: "john@example.com")  # Raises DB::NoResultsError
```

## Find by Multiple Attributes

```crystal
post = Post.find_by(user_id: 1, published: true)
```

## Find First Record

```crystal
user = User.first          # => User?
user = User.first!         # Raises when the table is empty
puts user.try(&.name)
```

## Find Last Record

```crystal
user = User.last
puts user.try(&.name)
```

`last` fetches a single row: the one with the highest primary key, or, when the query is ordered, the first row of the reversed order (ties go to the higher primary key).

## Find All Records

```crystal
users = User.all
users.each { |u| puts u.name }
```

## Iterate Over Many Records

`each` loads the matching rows, releases the connection, then yields them, so the block may run other queries and `break` stops early. For large tables use `find_each`, which loads one batch at a time and pages by primary key:

```crystal
User.query.where(active: true).find_each(batch_size: 500) do |user|
  user.touch
end
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

## Find or Create

```crystal
user = User.find_or_create_by(email: "john@example.com", name: "John")
```

`find_or_create_by` looks the record up by all the given attributes and calls `create!` with them when nothing matches.

## Pluck Values

```crystal
emails = User.where(active: true).pluck(:email, as: String)   # => Array(String)
newest_id = User.order(id: :desc).pick(:id, as: Int64)         # => Int64?
ids = User.where(active: true).ids                             # => Array(Int64)
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
