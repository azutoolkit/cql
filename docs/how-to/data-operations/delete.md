# Delete Records

Delete one record with its callbacks, or many rows with one statement, and soft delete when rows must stay.

## Delete One Record

```crystal
user = User.find!(1)
user.delete!     # => true
# DELETE FROM users WHERE users.id = ?
user.id          # => nil, cleared after the delete
user.destroyed?  # => true
user.delete!     # => false: no id any more

User.find(1)     # => nil
```

`delete!` runs `before_destroy` / `after_destroy` and the associations' `dependent:` strategies. It returns `false`
when the record has no id, a `before_destroy` callback returns `false`, or no row matched. A `restrict_with_error`
association that has records raises and deletes nothing.

## Delete Without Loading Records

```crystal
User.delete!(1)                    # => DB::ExecResult; DELETE FROM users WHERE users.id = ?
User.delete_by!(email: "a@x.com")  # => DB::ExecResult
Comment.delete_all                 # => DB::ExecResult; DELETE FROM comments (every row)
```

These run no callbacks and no `dependent:` strategies.

## Delete the Rows a Query Matches

```crystal
User.where(active: false).delete_all              # => 2 (Int64)
# SELECT users.id FROM users WHERE users.active = ?
# DELETE FROM users WHERE users.id IN (?, ?)

Post.where { created_at < 1.year.ago }.delete_all
```

Without destroy callbacks or `dependent:` associations (or `many_to_many`), this reads the ids and deletes them with one
`DELETE ... IN` per chunk of the bind limit, outside any transaction; wrap it in one if it must be all or nothing.
Otherwise it loads each record and calls its `delete!`, all in one transaction, so callbacks and the
[association strategies](../relationships/has-many.md#when-the-parent-is-deleted) run.

## Delete Children First

```crystal
User.transaction do
  user = User.find!(1)
  user.posts.delete_all   # => 2; DELETE FROM posts WHERE posts.user_id = ? (no callbacks)
  user.delete!
end

# Or refuse
user.posts.exists? ? puts("Cannot delete user with posts") : user.delete!
```

A foreign key declared with `on_delete: :cascade` lets the database delete the children. SQLite enforces foreign keys
only when the connection enables them: `uri: "sqlite3://./app.db?foreign_keys=true"`.

## Soft Delete

With `include CQL::ActiveRecord::SoftDeletable` and a nullable `deleted_at` column:

```crystal
user = User.find!(1)
user.delete!          # => true; UPDATE users SET deleted_at = ? WHERE users.id = ?
user.deleted?         # => true; the id stays
User.find(1)          # => nil: default queries skip deleted rows
User.with_deleted.find(1)
User.only_deleted.count

user.restore!         # => true; deleted_at = NULL
User.restore!(1)      # by id
user.force_delete!    # DELETE FROM users WHERE users.id = ?

User.delete_all       # soft deletes every active row (Int64)
User.restore_all
User.force_delete_all
```

```crystal
# ❌ A soft-deleted record is not persisted?, so save INSERTs a second row
user.delete!
user.save             # => true; user.id is now the new row's, also marked deleted

# ✅ Restore it first
user.restore!
user.save
```

{% hint style="warning" %}
`dependent:` strategies still run on a soft delete, and `restore!` does not undo them.
{% endhint %}

## See Also

- [Create Records](create.md)
- [Update Records](update.md)
- [Use Transactions](transactions.md)
- [Implement Soft Deletes](../models/soft-delete.md)
- [Set Up Has Many](../relationships/has-many.md)
