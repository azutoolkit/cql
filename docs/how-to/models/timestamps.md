# Use Timestamps

This guide shows you how to use automatic timestamps for tracking when records are created and updated.

## Add Timestamps to Schema

Use the `timestamps` helper in your table definition:

```crystal
schema.table :posts do
  primary :id, Int64, auto_increment: true
  column :title, String
  timestamps  # Adds created_at and updated_at columns
end
schema.posts.create!
```

This creates two columns:
- `created_at` - Set when record is first saved
- `updated_at` - Updated each time record is saved

Both columns get the dialect's current-timestamp default.

## Add to Model

Define the timestamp properties in your model:

```crystal
struct Post
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :posts

  property id : Int64?
  property title : String
  property created_at : Time?
  property updated_at : Time?

  def initialize(@title : String)
  end
end
```

## Automatic Timestamps

`save` and `save!` set `created_at` (new records only) and `updated_at` automatically, as long as the table has those columns:

```crystal
post = Post.new("My Post")
post.save!

post.created_at  # => 2024-01-15 10:30:00 UTC
post.updated_at  # => 2024-01-15 10:30:00 UTC

# Later update
post.title = "Updated Title"
post.save!

post.created_at  # => 2024-01-15 10:30:00 UTC (unchanged)
post.updated_at  # => 2024-01-15 11:45:00 UTC (updated)
```

Only `save`/`save!` do this. `Post.create!(title: "...")` inserts just the fields you pass, so the database default from `timestamps` fills `created_at` and `updated_at`, and the returned record is the row as stored (from `RETURNING` on PostgreSQL and CockroachDB, read back with a `SELECT` on SQLite and MySQL). `update!` writes the model's attributes as they are and does not touch `updated_at`, so use `save!` (or `touch`) when you want it refreshed.

## Touch Records

`touch` updates timestamp columns without running validations or callbacks:

```crystal
post.touch                          # updated_at = now
post.touch(:updated_at, :created_at)
post.touch!                         # same as touch(:updated_at)

Post.touch_all([1_i64, 2_i64])      # updated_at for many ids
```

`touch_all` sends one `UPDATE` per chunk of ids that fits the database's bind-parameter limit, so it takes any number of ids; the chunks are separate statements, so wrap the call in a transaction when it must be all-or-nothing.

`touch` raises `CQL::Error` on an unsaved record or an unknown column.

## Manual Timestamps with Callbacks

If you need more control, use callbacks:

```crystal
struct Post
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :posts

  property id : Int64?
  property title : String
  property created_at : Time?
  property updated_at : Time?

  before_create :set_created_at
  before_save :set_updated_at

  def initialize(@title : String)
  end

  private def set_created_at
    @created_at = Time.utc
    true
  end

  private def set_updated_at
    @updated_at = Time.utc
    true
  end
end
```

## Query by Timestamp

Filter records by their timestamps:

```crystal
# Records created today
Post.where { created_at > Time.utc.at_beginning_of_day }.all

# Records updated in last hour
Post.where { updated_at > 1.hour.ago }.all

# Records created between dates
Post.where { created_at.between(start_date, end_date) }.all

# Order by most recent
Post.order(created_at: :desc).all
```

## Add Timestamps to Existing Table

Create a migration:

```crystal
class AddTimestampsToPosts < CQL::Migration(20240115)
  def up
    schema.alter :posts do
      add_column :created_at, Time, null: true
      add_column :updated_at, Time, null: true
    end

    # Optionally set existing records to current time
    schema.exec("UPDATE posts SET created_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP WHERE created_at IS NULL")
  end

  def down
    schema.alter :posts do
      drop_column :created_at
      drop_column :updated_at
    end
  end
end
```

## Useful Timestamp Methods

Add helper methods to your model:

```crystal
struct Post
  # ... properties ...

  def created_today? : Bool
    created_at.try(&.date) == Time.utc.date
  end

  def recently_updated? : Bool
    updated_at.try { |t| t > 1.hour.ago } || false
  end

  def age : Time::Span?
    created_at.try { |t| Time.utc - t }
  end

  def formatted_created_at : String
    created_at.try(&.to_s("%B %d, %Y")) || "Unknown"
  end
end
```

## Verify It Works

```crystal
post = Post.create!(title: "Test")

post.created_at.nil?  # => false
post.updated_at.nil?  # => false

sleep 1
post.title = "Updated"
post.save!

post.created_at.not_nil! < post.updated_at.not_nil!  # => true
```

## Related

- [Define a Model](define-model.md)
- [Use Callbacks](use-callbacks.md)
- [Filter with Where Clauses](../querying/filter-records.md)
