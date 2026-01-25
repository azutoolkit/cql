# Use Cursor Pagination

This guide shows you how to implement cursor-based pagination for efficient navigation through large datasets.

## Why Cursor Pagination?

Cursor pagination is better than offset pagination for:
- Large datasets (offset becomes slow)
- Real-time data (new items don't shift pages)
- Infinite scroll interfaces
- API pagination

## Basic Cursor Pagination

Use the ID as a cursor:

```crystal
def fetch_posts(after : Int64?, limit : Int32 = 20)
  query = Post.published.order(id: :desc).limit(limit + 1)

  if after
    query = query.where { id < after }
  end

  items = query.all

  # Check if there are more items
  has_more = items.size > limit
  items = items.first(limit) if has_more

  {
    items: items,
    next_cursor: has_more ? items.last?.try(&.id) : nil,
    has_more: has_more
  }
end
```

## Usage

```crystal
# First page
result = fetch_posts(nil)
result[:items].each { |post| puts post.title }

# Next page
if cursor = result[:next_cursor]
  result = fetch_posts(cursor)
end
```

## Bidirectional Cursors

Support forward and backward navigation:

```crystal
def fetch_posts(after : Int64? = nil, before : Int64? = nil, limit : Int32 = 20)
  query = Post.published.limit(limit + 1)

  if after
    items = query.where { id < after }.order(id: :desc).all
    {
      items: items.first(limit),
      next_cursor: items.size > limit ? items[limit - 1].id : nil,
      prev_cursor: after,
      has_more: items.size > limit
    }
  elsif before
    items = query.where { id > before }.order(id: :asc).all
    items = items.reverse  # Restore descending order
    {
      items: items.first(limit),
      next_cursor: items.last?.try(&.id),
      prev_cursor: items.size > limit ? items.first.id : nil,
      has_more: items.size > limit
    }
  else
    items = query.order(id: :desc).all
    {
      items: items.first(limit),
      next_cursor: items.size > limit ? items[limit - 1].id : nil,
      prev_cursor: nil,
      has_more: items.size > limit
    }
  end
end
```

## Timestamp-Based Cursor

For chronologically ordered data:

```crystal
def fetch_activity(before : Time? = nil, limit : Int32 = 20)
  query = Activity.order(created_at: :desc).limit(limit + 1)

  if before
    query = query.where { created_at < before }
  end

  items = query.all
  has_more = items.size > limit
  items = items.first(limit) if has_more

  {
    items: items,
    next_cursor: has_more ? items.last?.try(&.created_at) : nil,
    has_more: has_more
  }
end
```

## Compound Cursor

When ordering by non-unique column:

```crystal
# Cursor contains both the sort value and ID for uniqueness
struct Cursor
  property views : Int64
  property id : Int64

  def self.parse(s : String) : self?
    parts = s.split(":")
    return nil unless parts.size == 2
    new(parts[0].to_i64, parts[1].to_i64)
  rescue
    nil
  end

  def to_s : String
    "#{@views}:#{@id}"
  end

  def initialize(@views, @id)
  end
end

def fetch_popular_posts(after : String? = nil, limit : Int32 = 20)
  query = Post.published.order(views_count: :desc, id: :desc).limit(limit + 1)

  if after && (cursor = Cursor.parse(after))
    query = query.where {
      (views_count < cursor.views) |
      ((views_count == cursor.views) & (id < cursor.id))
    }
  end

  items = query.all
  has_more = items.size > limit
  items = items.first(limit) if has_more

  next_cursor = if has_more && (last = items.last?)
    Cursor.new(last.views_count, last.id.not_nil!).to_s
  end

  {items: items, next_cursor: next_cursor, has_more: has_more}
end
```

## API Response Format

```crystal
def posts_api(params)
  result = fetch_posts(params["after"]?.try(&.to_i64))

  {
    data: result[:items].map(&.to_json),
    pagination: {
      next_cursor: result[:next_cursor],
      has_more: result[:has_more]
    }
  }
end
```

## Encode/Decode Cursors

For opaque cursors:

```crystal
require "base64"

def encode_cursor(id : Int64) : String
  Base64.strict_encode("cursor:#{id}")
end

def decode_cursor(cursor : String) : Int64?
  decoded = Base64.decode_string(cursor)
  if decoded.starts_with?("cursor:")
    decoded[7..].to_i64
  end
rescue
  nil
end
```

## Verify Cursor Pagination Works

```crystal
# Create test data
10.times do |i|
  Post.create!(title: "Post #{i + 1}", body: "...", published: true)
end

# Fetch pages
page1 = fetch_posts(nil, limit: 3)
page1[:items].size       # => 3
page1[:has_more]         # => true

page2 = fetch_posts(page1[:next_cursor], limit: 3)
page2[:items].size       # => 3
page2[:has_more]         # => true

# Items don't overlap
page1_ids = page1[:items].map(&.id)
page2_ids = page2[:items].map(&.id)
(page1_ids & page2_ids).empty?  # => true
```

## Related

- [Paginate Results](pagination.md)
- [Build Complex Queries](complex-queries.md)
- [Create Query Scopes](scopes.md)
