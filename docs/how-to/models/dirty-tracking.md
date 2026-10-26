# Track Changes and Update Only Changed Columns

Make a model remember its saved values, so it reports what changed and `update!` and `save` send only those columns.

## Enable Dirty Tracking

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::DirtyTracking   # after Model, or compilation fails

  property name : String = ""
  property email : String = ""
  property age : Int32 = 0
  property created_at : Time?
  property updated_at : Time?

  def initialize
  end
end
```

Without the module, `update!` and `save` write every column of the record.

## Inspect Changes

```crystal
user = User.find_by!(name: "Ada")  # loaded, created and saved records start clean
user.changed?                      # => false

user.name = "Ada Lovelace"
user.changed?                      # => true
user.attribute_changed?(:name)     # => true
user.attribute_changed?(:email)    # => false
user.changes                       # => {:name => {"Ada", "Ada Lovelace"}}
user.changed_columns               # => {:name => "Ada Lovelace"}, what an UPDATE would set

user.name = "Ada"
user.changed?                      # => false: back to the saved value
```

Changes are found by comparing values, so setters, `attributes(...)` and instance variable writes all count. A record that was never loaded or saved (`User.new`) counts every attribute as changed. Attributes are named by column, so ask about a property mapped with `@[DB::Field(key: "...")]` by its column name.

## Save Only What Changed

```crystal
user = User.find!(1)
user.age = 37
user.save        # UPDATE users SET age = ?, updated_at = ? WHERE users.id = ?

user.save        # nothing changed: no UPDATE, updated_at kept; callbacks still run
user.update!(email: "ada@example.com") # UPDATE users SET email = ? WHERE users.id = ?
```

A column another writer changed meanwhile is left as they wrote it. After a successful save the record is clean again, except for what an `after_save` or `after_create` callback changed, which the next `save` sends. When a `before_save` callback changes an otherwise clean record, its `UPDATE` is stamped as usual. `reload!` and `clear_changes!` also leave the record clean.

{% hint style="warning" %}
The saved values are what this record last loaded or saved. After a rolled-back transaction, or a write through another record, `User.update!(id, ...)` or raw SQL, call `reload!` before changing and saving it again.
{% endhint %}

## Combine With Other Modules

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::OptimisticLocking
  include CQL::ActiveRecord::SoftDeletable     # either order with DirtyTracking
  include CQL::ActiveRecord::DirtyTracking
  # ...
end
```

- **Optimistic locking:** a changed record's `update!` still sends every column, because the version check covers the whole row, and leaves the record clean. An unchanged one sends nothing and keeps its version.
- **Soft deletes:** `delete!` and `restore!` write `deleted_at` themselves, so `changes` may list it until the next `save` or `reload!`.

Each tracked record keeps a copy of its column values (one hash), so loading many of them allocates more than untracked records do.

## See Also

- [Update Records](../data-operations/update.md)
- [Add Optimistic Locking](optimistic-locking.md)
- [Implement Soft Deletes](soft-delete.md)
- [Use Timestamps](timestamps.md)
- [Use Callbacks](use-callbacks.md)
