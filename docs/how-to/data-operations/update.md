# Update Records

This guide shows you how to update existing records in the database.

## Update with save

Change attributes and save:

```crystal
user = User.find(1)
if user
  user.name = "Updated Name"
  user.save
  puts "Updated!"
end
```

## Update with save!

Raise on failure:

```crystal
user = User.find!(1)
user.name = "Updated Name"
user.save!  # Raises if validation fails
```

## Update with update!

Update multiple attributes at once:

```crystal
user = User.find!(1)
user.update!(
  name: "New Name",
  email: "new@example.com",
  age: 31
)
```

## Bulk Update

Update multiple records matching a condition with one `UPDATE` statement (no validations or callbacks):

```crystal
# Update all inactive users
AppDB.update.table(:users).set(active: true).where(active: false).commit

# Update with specific value
AppDB.update.table(:posts).set(published: true).where(user_id: 1).commit
```

`User.update_all(attrs)` updates every row of the table.

## Increment a Value

```crystal
post = Post.find!(1)
post.views_count += 1
post.save!
```

## Conditional Update

```crystal
user = User.find!(1)

if user.status == "pending"
  user.status = "active"
  user.activated_at = Time.utc
  user.save!
end
```

## Update Only Changed Fields

By default `save` writes every column. Include `CQL::ActiveRecord::DirtyTracking` (see [Dirty Tracking](../models/dirty-tracking.md)) to send only the changed ones:

```crystal
user = User.find!(1)
user.name = "New Name"  # Only name changed
user.save!              # With DirtyTracking: UPDATE users SET name = ?, updated_at = ? WHERE users.id = ?
```

## Update with Validation

Validations run on update:

```crystal
user = User.find!(1)
user.email = "invalid"

unless user.valid?
  puts user.errors.map(&.message).join(", ")
end
user.save  # raises CQL::ActiveRecord::Validations::ValidationError for an invalid record
```

## Update Timestamps

If your model has timestamps, `updated_at` is set automatically:

```crystal
user = User.find!(1)
user.name = "Updated"
user.save!

user.updated_at  # => Current time
```

## Update Without Callbacks

To skip callbacks (use carefully):

```crystal
# Direct update bypasses validations and callbacks
User.update!(1, name: "Direct Update")
```

## Verify Update

```crystal
user = User.find!(1)
original_name = user.name

user.name = "New Name"
user.save!

User.find!(1).name  # => "New Name"
```

## Related

- [Create Records](create.md)
- [Delete Records](delete.md)
- [Add Validations](../models/add-validations.md)
