# Delete Records

This guide shows you how to delete records from the database.

## Delete a Single Record

```crystal
user = User.find(1)
user.try(&.delete!)
puts "User deleted"
```

## Delete with delete!

Raises if record doesn't exist:

```crystal
user = User.find!(1)
user.delete!
```

## Delete with destroy!

`destroy!` triggers callbacks:

```crystal
user = User.find!(1)
user.destroy!  # Runs before_destroy and after_destroy callbacks
```

## Delete by ID

```crystal
User.delete!(1)
```

## Delete with Conditions

```crystal
# Delete all inactive users
User.where(active: false).delete!

# Delete posts older than a year
Post.where { created_at < 1.year.ago }.delete!
```

## Delete All Records

```crystal
# Delete all comments
Comment.delete_all

# Delete all with condition
User.where(role: "guest").delete_all
```

`delete_all` on a query returns the number of rows deleted. When the model declares no `before_destroy` or
`after_destroy` callbacks and no `dependent:` associations (or many_to_many), it reads the matching ids with one SELECT
and deletes them with one `DELETE ... WHERE id IN (...)` per chunk of the database's bind-parameter limit, without
loading records (a soft-deletable model sets `deleted_at` with an UPDATE instead). These statements are not wrapped in a
transaction; open one if the delete must be all or nothing. Otherwise it loads each record and calls its `delete!`, all
in one transaction, so the callbacks and the [association strategies](../relationships/has-many.md#when-the-parent-is-deleted)
run and an error (such as a `restrict_with_error` association with records) deletes nothing. An override of the instance
`delete!` alone does not count: declare a destroy callback if that code must run.

## Soft Delete (if enabled)

If using soft deletes:

```crystal
user = User.find!(1)
user.delete!         # Sets deleted_at timestamp
user.deleted?        # => true

user.restore!        # Restores the record
user.deleted?        # => false

user.force_delete!   # Permanently removes from database
```

## Cascade Delete

With foreign key cascade:

```crystal
# If posts have: on_delete: :cascade
user = User.find!(1)
user.delete!  # Also deletes all user's posts
```

## Delete Related Records First

Without cascade, delete children first:

```crystal
user = User.find!(1)
user.posts.all.each(&.delete!)
user.delete!
```

## Delete with Transaction

Ensure atomic deletion:

```crystal
User.transaction do
  user = User.find!(1)
  user.posts.all.each(&.delete!)
  user.comments.all.each(&.delete!)
  user.delete!
end
```

## Check Before Delete

```crystal
user = User.find!(1)

if user.posts.count > 0
  puts "Cannot delete user with posts"
else
  user.delete!
end
```

## Verify Deletion

```crystal
user = User.find!(1)
user.delete!

User.find(1)  # => nil
```

## Related

- [Create Records](create.md)
- [Update Records](update.md)
- [Implement Soft Deletes](../models/soft-delete.md)
