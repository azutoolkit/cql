# Paginate Results

Split results into numbered pages with `limit` and `offset`, or with the built-in `page` helpers.

## Page a Query

```crystal
page, per_page = 2, 10

Post.where(published: true)
  .order(created_at: :desc, id: :desc) # a unique last key keeps pages stable
  .limit(per_page)
  .offset((page - 1) * per_page)
  .all
# ... WHERE posts.published = ? ORDER BY posts.created_at DESC, posts.id DESC LIMIT ? OFFSET ?
# params: [true, 10, 10]
```

## Use the Built-in Helpers

```crystal
Post.page(2)                # => Array(Post): rows 11-20 (1-based pages, 10 per page)
Post.page(3, per_page: 25)  # rows 51-75; SELECT ... FROM posts LIMIT ? OFFSET ?
Post.per_page(5)            # the first 5 rows; SELECT ... FROM posts LIMIT ?
```

They read the whole table with no `WHERE` and no `ORDER BY`. To page a filtered or ordered query, use `limit` and `offset` as above.

## Return Page Metadata

```crystal
def paginate(query, page : Int32 = 1, per_page : Int32 = 10)
  total = query.count # SELECT COUNT(*) ..., without the ORDER BY
  {
    items:       query.limit(per_page).offset((page - 1) * per_page).all,
    page:        page,
    total:       total,
    total_pages: (total / per_page).ceil.to_i,
  }
end

# With 25 posts, ids 1-20 published:
result = paginate(Post.where(published: true).order(id: :asc), page: 2, per_page: 8)
result[:items].map(&.id)  # => [9, 10, 11, 12, 13, 14, 15, 16]
result[:total]            # => 20
result[:total_pages]      # => 3
result[:page] < result[:total_pages] # => true: there is a next page
```

## Read Page Parameters Safely

```crystal
def list_posts(params : Hash(String, String))
  # to_i raises ArgumentError on text that is not a number; use to_i? with a default to avoid it
  page = (params["page"]? || "1").to_i.clamp(1, nil)
  per_page = (params["per_page"]? || "10").to_i.clamp(1, 100)
  result = paginate(Post.where(published: true).order(created_at: :desc, id: :desc), page, per_page)

  {
    posts: result[:items].map(&.title),
    meta:  {page: page, per_page: per_page, total: result[:total], total_pages: result[:total_pages]},
  }
end

list_posts({"page" => "2", "per_page" => "500"})[:meta]
# => {page: 2, per_page: 100, total: 20, total_pages: 1}
```

## Switch to a Cursor for Deep Pages

`OFFSET n` makes the database read and skip `n` rows on every page. For large tables or feeds that change while users page, filter past the last row seen instead:

```crystal
Post.where(published: true).where { id < last_seen_id }.order(id: :desc).limit(20).all
# ... WHERE (posts.published = ?) AND (posts.id < ?) ORDER BY posts.id DESC LIMIT ?
```

See [Use Cursor Pagination](cursor-pagination.md) for `has_more`, compound keys and the built-in cursor helpers.

## See Also

- [Use Cursor Pagination](cursor-pagination.md)
- [Filter with Where Clauses](filter-records.md)
- [Build Complex Queries](complex-queries.md)
- [Create Query Scopes](scopes.md)
