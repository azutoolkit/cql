# Paginate Results

This guide shows you how to paginate query results for display in pages.

## Basic Pagination

Use `limit` and `offset`:

```crystal
page = 1
per_page = 10

posts = Post.order(created_at: :desc)
            .limit(per_page)
            .offset((page - 1) * per_page)
            .all
```

## Pagination Helper

Create a reusable pagination method:

```crystal
def paginate(query, page : Int32 = 1, per_page : Int32 = 10)
  offset = (page - 1) * per_page
  query.limit(per_page).offset(offset).all
end

# Usage
posts = paginate(Post.where(published: true), page: 2, per_page: 20)
```

## Pagination Info

Get total count for pagination UI:

```crystal
def paginated_results(query, page : Int32 = 1, per_page : Int32 = 10)
  total = query.count
  total_pages = (total / per_page.to_f).ceil.to_i
  offset = (page - 1) * per_page

  {
    items: query.limit(per_page).offset(offset).all,
    page: page,
    per_page: per_page,
    total: total,
    total_pages: total_pages,
    has_next: page < total_pages,
    has_prev: page > 1
  }
end

# Usage
result = paginated_results(Post.published, page: 2)
puts "Page #{result[:page]} of #{result[:total_pages]}"
puts "Showing #{result[:items].size} of #{result[:total]} items"
```

## Cursor-Based Pagination

For better performance with large datasets:

```crystal
def cursor_paginate(last_id : Int64?, limit : Int32 = 10)
  query = Post.order(id: :desc).limit(limit)

  if last_id
    query = query.where { id < last_id }
  end

  items = query.all
  next_cursor = items.last?.try(&.id)

  {items: items, next_cursor: next_cursor}
end

# First page
result = cursor_paginate(nil)

# Next page
result = cursor_paginate(result[:next_cursor])
```

## Timestamp-Based Pagination

For chronological data:

```crystal
def paginate_by_time(before : Time?, limit : Int32 = 10)
  query = Post.order(created_at: :desc).limit(limit)

  if before
    query = query.where { created_at < before }
  end

  items = query.all
  next_cursor = items.last?.try(&.created_at)

  {items: items, next_cursor: next_cursor}
end
```

## Keyset Pagination

More efficient for large datasets:

```crystal
def keyset_paginate(after_id : Int64?, limit : Int32 = 10)
  query = Post.where(published: true)
              .order(views_count: :desc, id: :desc)
              .limit(limit)

  if after_id
    # Get the reference record
    ref = Post.find(after_id)
    if ref
      query = query.where {
        (views_count < ref.views_count) |
        ((views_count == ref.views_count) & (id < after_id))
      }
    end
  end

  query.all
end
```

## Web API Example

```crystal
def list_posts(params)
  page = (params["page"]? || "1").to_i
  per_page = [(params["per_page"]? || "10").to_i, 100].min  # Max 100

  query = Post.published.order(created_at: :desc)
  result = paginated_results(query, page, per_page)

  {
    posts: result[:items].map(&.to_json),
    meta: {
      page: result[:page],
      per_page: result[:per_page],
      total: result[:total],
      total_pages: result[:total_pages]
    }
  }
end
```

## Verify Pagination Works

```crystal
# Create 25 posts
25.times do |i|
  Post.create!(title: "Post #{i + 1}", body: "...", published: true)
end

# Test pagination
page1 = Post.order(id: :asc).limit(10).offset(0).all
page2 = Post.order(id: :asc).limit(10).offset(10).all
page3 = Post.order(id: :asc).limit(10).offset(20).all

page1.size  # => 10
page2.size  # => 10
page3.size  # => 5

page1.first.title  # => "Post 1"
page2.first.title  # => "Post 11"
page3.first.title  # => "Post 21"
```

## Related

- [Filter with Where Clauses](filter-records.md)
- [Build Complex Queries](complex-queries.md)
- [Create Query Scopes](scopes.md)
