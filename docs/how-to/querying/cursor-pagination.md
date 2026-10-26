# Use Cursor Pagination

Page through large or changing result sets by filtering past the last row seen (`WHERE id < ?`) instead of skipping rows with `OFFSET`.

## Use the Built-in Helpers

```crystal
Post.after_cursor(last_seen_id, limit: 20)
# ... WHERE posts.id > ? ORDER BY posts.id ASC LIMIT ?

Post.before_cursor(first_seen_id, limit: 20)
# ... WHERE posts.id < ? ORDER BY posts.id DESC LIMIT ?, returned in ascending order

Post.paginate_by(:views_count, 500, limit: 20)
# ... WHERE posts.views_count > ? ORDER BY posts.views_count ASC LIMIT ?
```

Each returns an `Array(Post)`. The cursor helpers use the model's primary key column (`Post.primary_key_column`, `:id` unless `db_context` sets `primary_key:`). All three read the whole table, order ascending and compare strictly, so they suit unique columns. For descending feeds, filters or non-unique sort keys, build the query yourself.

## Page a Descending Feed

```crystal
def fetch_posts(after : Int64? = nil, limit : Int32 = 20)
  query = Post.where(published: true).order(id: :desc).limit(limit + 1) # one extra row: is there more?
  query = query.where { id < after } if after
  items = query.all
  has_more = items.size > limit
  items = items.first(limit)
  {items: items, next_cursor: has_more ? items.last.id : nil}
end
# ... WHERE (posts.published = ?) AND (posts.id < ?) ORDER BY posts.id DESC LIMIT ?

# With 25 posts, ids 1-20 published:
page1 = fetch_posts(limit: 3)                     # ids [20, 19, 18], next_cursor: 18
page2 = fetch_posts(page1[:next_cursor], limit: 3) # ids [17, 16, 15], next_cursor: 15
```

## Go Back a Page

```crystal
def previous_posts(before : Int64, limit : Int32 = 20)
  Post.where(published: true).where { id > before }.order(id: :asc).limit(limit).all.reverse
end

previous_posts(17_i64, limit: 3).map(&.id) # => [20, 19, 18]
```

## Order by a Non-Unique Column

Add the primary key as a tiebreaker, and carry both values in the cursor:

```crystal
def fetch_popular(after : {Int64, Int64}? = nil, limit : Int32 = 20)
  query = Post.where(published: true).order(views_count: :desc, id: :desc).limit(limit + 1)
  if cursor = after
    views, last_id = cursor
    query = query.where { (views_count < views) | ((views_count == views) & (id < last_id)) }
  end
  items = query.all
  has_more = items.size > limit
  items = items.first(limit)
  last = items.last?
  {items: items, next_cursor: has_more && last ? {last.views_count, last.id!} : nil}
end
# ... WHERE (posts.published = ?) AND ((posts.views_count < ?) OR ((posts.views_count = ?) AND (posts.id < ?)))
#     ORDER BY posts.views_count DESC, posts.id DESC LIMIT ?
```

The same shape pages a timeline: use `created_at` in place of `views_count`.

## Encode Cursors for an API

```crystal
require "base64"

def encode_cursor(cursor : {Int64, Int64}) : String
  Base64.urlsafe_encode(cursor.join(":"))
end

def decode_cursor(token : String) : {Int64, Int64}?
  views, id = Base64.decode_string(token).split(":", 2)
  {views.to_i64, id.to_i64}
rescue ArgumentError | IndexError | Base64::Error
  nil # a tampered or truncated token reads as "no cursor"
end

token = encode_cursor({1700_i64, 18_i64}) # => "MTcwMDoxOA=="
fetch_popular(decode_cursor(token), limit: 20)
```

{% hint style="success" %}
Back the cursor's sort columns with an index in the same order (here `[:views_count, :id]`), so the database can seek to the cursor instead of sorting the table. See [Create Indexes](../migrations/indexes.md).
{% endhint %}

## See Also

- [Paginate Results](pagination.md)
- [Write Typed Queries](typed-where-dsl.md)
- [Build Complex Queries](complex-queries.md)
- [Create Indexes](../migrations/indexes.md)
