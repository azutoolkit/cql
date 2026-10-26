# Update Records

Change one record with `save`, write columns directly with `update!`, or update many rows with one statement.

## Change Attributes and Save

```crystal
user = User.find!(1)
user.name = "Ada Lovelace"
user.save   # => true
# UPDATE users SET name = ?, email = ?, age = ?, active = ?, status = ?, role = ?, created_at = ?, updated_at = ? WHERE users.id = ?

user.updated_at # refreshed by save

post = Post.find!(1)
post.views_count += 1
post.save!
```

`save` validates, runs the save and update callbacks, sets `updated_at` and writes every column. An invalid record
raises, as on create:

```crystal
user.email = "invalid"
user.valid?                               # => false
user.errors.map(&.message).join(", ")     # => "is not an email"
user.save                                 # raises CQL::ActiveRecord::Validations::ValidationError
```

## Write Columns Without Validations or Callbacks

```crystal
# Instance: assigns the attributes, then writes every column
user.update!(name: "New Name", email: "new@example.com")  # => user

# Class: writes only the named columns of one row
User.update!(1, name: "Direct Update")                     # => DB::ExecResult
# UPDATE users SET name = ? WHERE users.id = ?

User.update!(1, age: "31")      # CQL::Error: Invalid type for column age: expected Int32, got String
User.update!(1, age: 31_i64)    # CQL::Error: Invalid type ... expected Int32, got Int64
User.update!(1, nickname: "x")  # CQL::Error: Unknown column: nickname

user.touch                      # => true; UPDATE users SET updated_at = ? WHERE users.id = ?
User.touch_all([1_i64, 2_i64])  # => 2
```

{% hint style="warning" %}
`update!` skips validations and callbacks, and neither form refreshes `updated_at`. `update!(email: "bad")` stores the bad value; use `save` when the model's rules must hold.
{% endhint %}

## Update Many Rows

```crystal
AppDB.update.table(:users).set(active: false).where(role: "guest").commit.rows_affected  # => rows changed (Int64)
# UPDATE users SET active = ? WHERE users.role = ?

AppDB.update.table(:users).set(active: false).where { users.age > 100 }.commit
# UPDATE users SET active = ? WHERE users.age > ?

User.update_by({:role => "guest"} of Symbol => DB::Any, {:active => false} of Symbol => DB::Any)
# UPDATE users SET active = ? WHERE users.role = ?

User.update_all({:active => true} of Symbol => DB::Any)
# UPDATE users SET active = ?   (every row)
```

One statement, no validations, no callbacks, no `updated_at`. Each returns a `DB::ExecResult`.

## Update Only Changed Columns

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::DirtyTracking
end

user = User.find!(1)
user.name = "New Name"
user.save!   # UPDATE users SET name = ?, updated_at = ? WHERE users.id = ?
user.save!   # nothing changed: no UPDATE
```

For read-modify-write updates that race, such as the `views_count` increment above, add a lock version column; see
[Add Optimistic Locking](../models/optimistic-locking.md).

## See Also

- [Create Records](create.md)
- [Delete Records](delete.md)
- [Use Transactions](transactions.md)
- [Track Changes and Update Only Changed Columns](../models/dirty-tracking.md)
- [Add Optimistic Locking](../models/optimistic-locking.md)
- [Add Validations](../models/add-validations.md)
