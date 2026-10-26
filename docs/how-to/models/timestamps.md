---
description: "Record when each row was created and last updated with created_at and updated_at."
---

# Use Timestamps

## Add the Columns and Properties

```crystal
AppDB = CQL::Schema.define(:app_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://./app.db") do
  table :posts do
    primary :id, Int64, auto_increment: true
    column :title, String
    timestamps          # created_at and updated_at, defaulting to the dialect's current timestamp
  end
end

class Post
  include CQL::ActiveRecord::Model(Int64)

  property title : String = ""
  property created_at : Time?
  property updated_at : Time?

  def initialize(@title : String = "")
  end
end
```

## Let save Stamp Them

```crystal
post = Post.new("Draft")
post.save!
post.created_at   # => 2026-10-26 10:30:00Z
post.updated_at   # => 2026-10-26 10:30:00Z

post.title = "Published"
post.save!
post.created_at   # => 2026-10-26 10:30:00Z (unchanged)
post.updated_at   # => 2026-10-26 11:45:00Z
```

`save`, `save!` and the instance `create!` set `created_at` on a new record and `updated_at` on every save, before validating, whenever the table has those columns. Other writes do not:

```crystal
Post.create!(title: "Hello")   # INSERTs only title; the column defaults fill both timestamps,
                               # and the returned record is the stored row
post.update!(title: "Edited")  # writes the attributes as they are; updated_at unchanged
```

`create!` reads the stored row back with `RETURNING` on PostgreSQL and CockroachDB, and with a `SELECT` on SQLite and MySQL.

## Touch a Record

`touch` writes the current time without validations or callbacks:

```crystal
post.touch                                    # updated_at = now
post.touch(:updated_at, :created_at)          # several columns
post.touch(:updated_at, time: 1.hour.ago)     # a given time
post.touch!                                   # same as touch(:updated_at)

Post.touch_all([1_i64, 2_i64])                # => 2, rows touched
Post.touch_all([1_i64, 2_i64], :created_at, :updated_at)
```

`touch` raises `CQL::Error` on an unsaved record or an unknown column. `touch_all` sends one `UPDATE` per chunk of ids that fits the bind-parameter limit, so it takes any number of ids.

{% hint style="warning" %}
The `touch_all` chunks are separate statements. Wrap the call in a transaction when it must be all-or-nothing.
{% endhint %}

## Query by Timestamp

```crystal
Post.where { created_at > Time.utc.at_beginning_of_day }.all
Post.where { updated_at > 1.hour.ago }.all
Post.where { created_at.between(1.week.ago, Time.utc) }.all
Post.order(created_at: :desc).limit(10).all
```

## Add Timestamps to an Existing Table

{% code title="db/migrations/20260115_add_timestamps_to_posts.cr" %}
```crystal
class AddTimestampsToPosts < CQL::Migration(20260115)
  def up
    schema.alter :posts do
      add_column :created_at, Time, null: true
      add_column :updated_at, Time, null: true
    end
    schema.exec("UPDATE posts SET created_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP")
  end

  def down
    schema.alter :posts do
      drop_column :created_at
      drop_column :updated_at
    end
  end
end
```
{% endcode %}

## See Also

- [Use Callbacks](use-callbacks.md)
- [Track Changes and Update Only Changed Columns](dirty-tracking.md)
- [Filter with Where Clauses](../querying/filter-records.md)
- [Add Columns](../migrations/add-columns.md)
- [Use Transactions](../data-operations/transactions.md)
