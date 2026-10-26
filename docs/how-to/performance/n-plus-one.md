---
description: "Load associations and counts for a whole collection in a fixed number of queries, not one query per record."
---

# Avoid N+1 Queries

## Spot the Pattern

```crystal
# ❌ 1 query for the posts, then 1 query per post on first access to post.user
posts = Post.all
posts.each { |post| puts post.user.try(&.name) }
# SELECT posts.id, posts.title, posts.user_id FROM posts
# SELECT users.id, users.name, ... FROM users WHERE users.id = ? LIMIT ?   <- once per post
```

With 100 posts this runs 101 queries. Calling `user.posts` for every user does the same in the other direction.

## Preload Associations

```crystal
# ✅ 2 queries: posts, then SELECT ... FROM users WHERE users.id IN (?, ?)
posts = Post.preload(:user).all
posts.each { |post| puts post.user.try(&.name) }

# ✅ One extra query per association
# SELECT ... FROM posts WHERE posts.user_id IN (?, ?)
# SELECT ... FROM profiles WHERE profiles.user_id IN (?, ?)
users = User.preload(:posts, :profile).all
users.each { |user| puts user.posts.size }  # no query
```

{% hint style="info" %}
**`preload`** handles `has_many`, `belongs_to` and `has_one`, splits the `IN` list at the database's bind limit, and shares one instance per `belongs_to` target. It skips associations declared with `cache: false` and ignores `many_to_many`; [Optimize Queries](optimize-queries.md) lists its other limits.
{% endhint %}

## Filter Through a Join

```crystal
# SELECT posts.id, ... FROM posts INNER JOIN users ON (users.id = posts.user_id) AND (users.active = ?)
posts = Post.query.joins(:user) { user.active == true }.all
```

The join filters rows but does not populate `post.user`. Use `left_joins` to keep posts without a match.

## Load by Hand

For `many_to_many` or a relation CQL does not model, load the targets once and index them:

```crystal
posts = Post.all
users_by_id = User.where(id: posts.compact_map(&.user_id).uniq).all.index_by(&.id)

posts.each { |post| puts users_by_id[post.user_id]?.try(&.name) }  # 2 queries in total
```

## Count Per Parent

```crystal
# ❌ One COUNT per post: SELECT COUNT(*) FROM comments WHERE comments.post_id = ?
posts.each { |post| puts post.comments.count }

# ✅ SELECT comments.post_id, COUNT(comments.id) FROM comments GROUP BY comments.post_id
counts = AppDB.query
  .from(:comments)
  .select(:post_id, count: :id)
  .group(:post_id)
  .all(as: {Int64, Int64})
  .to_h

posts.each { |post| puts counts[post.id!]? || 0 }
```

For a count read on every page, keep it in a column. Add it with raw DDL so it gets its default, as
[Add a Column With a Default](../migrations/add-columns.md#add-a-column-with-a-default) explains:

```crystal
# Migration: add the column, then declare it
schema.exec "ALTER TABLE posts ADD COLUMN comments_total INTEGER DEFAULT 0 NOT NULL"
schema.posts.integer :comments_total, default: 0  # declares only; runs no SQL

# In the Post model: property comments_total : Int32 = 0
def add_comment(post : Post, body : String)
  Comment.create!(post_id: post.id!, body: body)
  post.comments_total = post.comments.count.to_i32
  post.save!
end

Post.order(comments_total: :desc).limit(10).all  # no COUNT queries
```

{% hint style="warning" %}
`has_many :comments` already defines `comments_count`, which runs a COUNT query each call. A counter column named `comments_count` is shadowed by it, so give the column another name.
{% endhint %}

## Find and Verify

```crystal
CQL::Telemetry.log_queries  # debug lines on the "cql.telemetry" log source
# [select] 0.01ms SELECT users.id, ... FROM users WHERE users.id = ? LIMIT ? (2 params)   <- repeated per post

CQL::Performance.enable_development_mode!  # the N+1 detector
CQL::Performance.metrics.issues_by_type(:n_plus_one).each { |issue| puts issue.message }
# N+1 pattern detected: Query repeated 10 times
```

The detector, its window and its severities are in [Profile Queries and Detect N+1](../observability/query-profiler.md).

Once fixed, guard the query count in a spec (`Factory` is from [Set Up Test Databases and Factories](../testing/test-database.md#build-records-with-factories)):

{% code title="spec/n_plus_one_spec.cr" %}
```crystal
require "./spec_helper"

def count_queries(&) : Int32
  count = 0
  CQL::Telemetry.subscribe("query_count") { count += 1 }
  yield
  count
ensure
  CQL::Telemetry.unsubscribe("query_count")
end

describe "Post list" do
  it "loads posts and their authors in two queries" do
    3.times { Factory.post }
    count_queries { Post.preload(:user).all.each(&.user) }.should eq(2)
  end
end
```
{% endcode %}

Without `preload(:user)` the block runs 4 queries (the posts, then one per post) and the example fails.

## See Also

- [Optimize Queries](optimize-queries.md)
- [Profile Queries and Detect N+1](../observability/query-profiler.md)
- [Telemetry](../observability/telemetry.md)
- [Set Up Has Many](../relationships/has-many.md)
- [Add Columns](../migrations/add-columns.md)
