# Track Changes and Update Only Changed Columns

This guide shows you how to make a model remember which attributes changed since it was loaded or saved, so that `update!` and `save` send only those columns.

## When to Use

Use dirty tracking when:
- Several writers update different columns of the same row, and a full-row UPDATE would overwrite what the others wrote
- You want to skip the UPDATE (and keep `updated_at`) when a record is saved without changes
- You want to inspect what changed before saving, for example to audit it

Without it, `update!` and `save` write every column of the record.

## Enable Dirty Tracking

Include the module after `CQL::ActiveRecord::Model` (included first, it fails to compile, because `Model`'s `save` and `update!` would replace its own):

```crystal
class Person
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::DirtyTracking

  db_context schema: AppDB, table: :people

  property name : String = ""
  property email : String = ""
  property age : Int32 = 0
  property created_at : Time? = nil
  property updated_at : Time? = nil
end
```

## Inspect Changes

A record loaded from the database, created or saved starts clean:

```crystal
person = Person.find_by!(name: "Ada")
person.changed?                   # => false

person.name = "Ada Lovelace"
person.changed?                   # => true
person.attribute_changed?(:name)  # => true
person.attribute_changed?(:email) # => false
person.changes                    # => {:name => {"Ada", "Ada Lovelace"}}
```

Changes are found by comparing values with the ones last loaded or saved, so assignments through setters, `attributes(...)` and instance variables all count, and setting an attribute back to its saved value is not a change. A record that was never loaded or saved (`Person.new`) counts every attribute as changed. Attributes are named by their column, so a property mapped with `@[DB::Field(key: "...")]` is asked about by its column name.

## Save Only What Changed

`update!`, `update!(**attributes)` and `save` send only the changed columns:

```crystal
person = Person.find!(1)
person.age = 37
person.save
# UPDATE people SET age = ?, updated_at = ? WHERE people.id = ?
```

A column another writer changed meanwhile is left as they wrote it. When nothing changed, no UPDATE is sent and `updated_at` is not touched; callbacks still run, and if a `before_save` callback changes the record, its UPDATE is stamped as usual. After a successful save the record is clean again, except for what an `after_save`/`after_create` callback changed, which the next `save` sends. `reload!` also leaves the record clean.

## Combine With Other Modules

- **Optimistic locking**: include both. A locked `update!` of a changed record still sends every column (the version check covers the whole row) and leaves the record clean; an unchanged one sends nothing and keeps its version.
- **Soft deletes**: include both, in either order. `delete!` and `restore!` write `deleted_at` themselves, so `changes` may list it until the next save or `reload!`.

## Limits

The saved values are what this record last loaded or saved. If a transaction rolls back after a save, or something else writes the row (another record, `Model.update!(id, ...)`, raw SQL), the record still believes its values are saved: call `reload!` before changing and saving it again.

## Cost

A tracked record keeps a copy of its column values (one hash per record), so loading many tracked records allocates more than loading untracked ones. Models without the module are unchanged.
