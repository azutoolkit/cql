---
description: "Stop a stale copy of a record from overwriting a newer update by checking a version column on every update."
---

# Add Optimistic Locking

## Add a Version Column

```crystal
AppDB = CQL::Schema.define(:app_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://./app.db") do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String
    lock_version :version   # Int32, NOT NULL, default 1
  end
end
```

On an existing table, add it in a migration; the default fills the existing rows (see [Add a Column With a Default](../migrations/add-columns.md#add-a-column-with-a-default)):

{% code title="db/migrations/20260115_add_version_to_users.cr" %}
```crystal
class AddVersionToUsers < CQL::Migration(20260115)
  def up
    schema.alter :users do
      add_column :version, Int32, default: 1, null: false
    end
  end

  def down
    schema.alter :users do
      drop_column :version
    end
  end
end
```
{% endcode %}

## Enable Locking on the Model

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::OptimisticLocking

  property name : String = ""
  property version : Int32 = 1          # Int32 whatever the primary key type

  optimistic_locking version_column: :version
end
```

{% hint style="warning" %}
Always pass `version_column:`. The macro defaults to `:lock_version`, while the `lock_version` schema helper names its column `:version`.
{% endhint %}

## Update and Handle Conflicts

`update!`, `update!(**attributes)` and `save` check the version and write the next one:

```crystal
first = User.find!(1)     # version 1
second = User.find!(1)    # version 1

first.name = "First"
first.save                # UPDATE users SET name = ?, version = ? WHERE (users.id = ?) AND (users.version = ?)
first.version             # => 2

second.name = "Second"
second.save               # raises CQL::OptimisticLockError: Record has been modified by another process
```

Reload and reapply the change, with a retry limit:

```crystal
def rename(user : User, name : String, attempts = 3) : Bool
  attempts.times do
    user.name = name
    begin
      user.update!
      return true
    rescue CQL::OptimisticLockError
      user.reload!          # latest values and version
    end
  end
  false
end

rename(second, "Second")  # => true
```

`update!` raises `CQL::Error` on an unsaved record or a `nil` version. The class method `User.update!(id, attributes)` writes the row directly and skips the check.

## Combine With Other Modules

`OptimisticLocking` combines with `SoftDeletable` and `DirtyTracking`; see [Track Changes](dirty-tracking.md#combine-with-other-modules) for the includes and what a versioned, tracked record's `update!` sends.

## See Also

- [Track Changes and Update Only Changed Columns](dirty-tracking.md)
- [Implement Soft Deletes](soft-delete.md)
- [Lock Rows](../data-operations/row-locking.md)
- [Use Transactions](../data-operations/transactions.md)
- [Define a Model](define-model.md)
