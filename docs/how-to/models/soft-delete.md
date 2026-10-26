---
description: "Mark records as deleted with a deleted_at timestamp instead of removing their rows."
---

# Implement Soft Deletes

## Enable Soft Deletes

```crystal
AppDB = CQL::Schema.define(:app_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://./app.db") do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String
    column :email, String
    column :deleted_at, Time, null: true
    index [:deleted_at]               # every query filters on it
  end
end

class User
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::SoftDeletable # adds property deleted_at : Time?

  property name : String = ""
  property email : String = ""
end
```

## Delete and Restore

```crystal
user = User.find!(1)
user.delete!       # => true: UPDATE users SET deleted_at = ? WHERE users.id = ?
user.deleted?      # => true
user.deleted_at    # => 2026-10-26 10:30:00Z
user.delete!       # => false: already deleted, no callbacks, deleted_at kept

user.restore!      # => true: the same UPDATE, binding NULL
user.deleted?      # => false

User.delete!(1)                            # => Bool, through the instance delete!
User.delete_by!(email: "spam@example.com") # each match's delete!, in one transaction;
                                           # rows_affected counts the records it soft deleted
User.delete_all                            # => Int64, active rows soft deleted
User.restore!(1)                           # => Bool
User.restore_all                           # => Int64, no callbacks
```

The instance, `delete!(id)` and `delete_by!` run `before_destroy`/`after_destroy` callbacks and the `dependent:` strategies. `delete_all` does too when the model declares any; otherwise it sets `deleted_at` in bulk: one `SELECT` of the ids, then one `UPDATE` per chunk of the bind limit. `restore_all` works in bulk the same way.

Rows already soft deleted keep their first `deleted_at` and are not counted, also through `with_deleted.delete_all` and `delete_ids`.

{% hint style="info" %}
A soft-deleted record reports `persisted? == false`. `save` on it still updates its row, which stays deleted; call `restore!` to bring it back.
{% endhint %}

## Query Around Deleted Rows

```crystal
User.all                     # WHERE users.deleted_at IS NULL is added to every query
User.count                   # active rows only
User.find(1)                 # => nil when user 1 is soft deleted

User.with_deleted.all        # every row
User.with_deleted.find(1)
User.only_deleted.all        # WHERE users.deleted_at IS NOT NULL
User.count_with_deleted      # same as User.with_deleted.count
User.count_only_deleted      # same as User.only_deleted.count

# Both are scopes, so keep chaining
User.only_deleted.where(name: "Ada").order(deleted_at: :desc).all
```

## Delete Permanently

```crystal
user.force_delete!                                # DELETE FROM users WHERE users.id = ?
User.force_delete!(1)
User.force_delete_by!(email: "spam@example.com")
User.force_delete_all

# Purge rows soft deleted more than a year ago
User.only_deleted.where { deleted_at < 1.year.ago }.all.each(&.force_delete!)
```

`force_delete!` runs the destroy callbacks and `dependent:` strategies; the class methods do not.

## Cascade to Associations

`delete!` and `force_delete!` apply each association's `dependent:` strategy, as a hard delete does (see [When the Parent Is Deleted](../relationships/has-many.md#when-the-parent-is-deleted)):

```crystal
class Post
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::SoftDeletable

  property title : String = ""

  # Comment includes SoftDeletable too, so each comment's delete! sets its deleted_at
  has_many :comments, Comment, foreign_key: :post_id, dependent: :destroy
end

post.delete!    # soft deletes the comments, then the post, in one transaction
post.restore!   # restores only the post: restore the comments yourself
```

A `:restrict_with_error` association with records raises before `deleted_at` is set; the other strategies run in the same transaction as the `UPDATE`. `dependent: :destroy` skips children that are already soft deleted. `:nullify` and has_many's `:delete_all` (a hard delete, even of soft-deletable children) are not undone by `restore!`, so prefer `:destroy`.

## See Also

- [Delete Records](../data-operations/delete.md)
- [Set Up Has Many](../relationships/has-many.md)
- [Use Callbacks](use-callbacks.md)
- [Add Optimistic Locking](optimistic-locking.md)
- [Create Query Scopes](../querying/scopes.md)
