# Find Records

Look up model records by primary key or by attributes, and read single values without loading records.

## Find by Primary Key

```crystal
User.find(1)    # => User? (nil when no row matches); find? is the same method
User.find!(1)   # => User; raises DB::NoResultsError "No records found with id=1"
# SELECT users.id, users.name, ... FROM users WHERE users.id = ? LIMIT ?

User.find(1).try(&.name) || "Unknown"
```

{% hint style="info" %}
**`find`** renders its statement once per model and rebinds only the id. A model, or a subclass, that overrides `self.query` (for example with a per-request tenant filter) is rendered on every call, so the override always applies.
{% endhint %}

## Find by Attributes

```crystal
User.find_by(email: "ada@example.com")   # => User?
# SELECT users.id, ... FROM users WHERE users.email = ? LIMIT ?
User.find_by!(email: "ada@example.com")  # raises DB::NoResultsError when nothing matches

Post.find_by(user_id: 1_i64, published: true)
# ... WHERE (posts.user_id = ?) AND (posts.published = ?) LIMIT ?

User.find_by(deleted_at: nil)            # ... WHERE users.deleted_at IS NULL LIMIT ?
User.exists?(email: "ada@example.com")   # => true; SELECT users.id FROM users WHERE users.email = ? LIMIT ?
```

## First, Last and All

```crystal
User.first                            # => User?; ... FROM users LIMIT ? (no ORDER BY)
User.first!                           # raises NilAssertionError when no row matches
User.last                             # => User?; ... ORDER BY users.id DESC LIMIT ?
User.last!                            # raises "No records found" when no row matches

User.order(created_at: :desc).first   # newest
User.order(created_at: :asc).last     # newest too: the order reversed, ties to the higher id
# ... ORDER BY users.created_at DESC, users.id DESC LIMIT ?

User.all                              # => Array(User)
User.where(active: true).to_a         # to_a is all
```

## Iterate Over Records

```crystal
# Loads the matching rows, releases the connection, then yields:
# the block may run other queries, and break stops early
User.where(active: true).each { |user| puts user.name }

# Loads 500 rows per query, paging by primary key
User.where(active: true).find_each(batch_size: 500) { |user| user.touch }
# SELECT ... WHERE users.active = ? ORDER BY users.id ASC LIMIT ?
```

## Find or Create

```crystal
# Find or build: the new record is not saved
user = User.find_by(email: "ada@example.com") || User.new("Ada", "ada@example.com")

# Looks up by all the given attributes and calls create! with them when nothing matches
user = User.find_or_create_by(email: "ada@example.com", name: "Ada")
# SELECT ... WHERE (users.email = ?) AND (users.name = ?) LIMIT ?
# INSERT INTO users (email, name) VALUES (?, ?)
```

## Read Values Without Records

```crystal
User.where(active: true).pluck(:email, as: String)  # => ["ada@example.com", ...]
# SELECT users.email FROM users WHERE users.active = ?
User.order(id: :desc).pick(:id, as: Int64)          # => Int64? (the newest id)
User.where(active: true).ids                        # => Array(Int64)
```

## See Also

- [Filter with Where Clauses](filter-records.md)
- [Write Typed Queries](typed-where-dsl.md)
- [Build Complex Queries](complex-queries.md)
- [Paginate Results](pagination.md)
- [Define a Model](../models/define-model.md)
