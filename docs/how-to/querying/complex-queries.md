---
description: "Combine conditions, subqueries, aggregates, grouping, joins and raw SQL in one query."
---

# Build Complex Queries

## Chain Conditions

```crystal
Post.where(published: true)
  .where { views_count > 100 }
  .order(created_at: :desc)
  .limit(10)
  .all
# ... WHERE (posts.published = ?) AND (posts.views_count > ?) ORDER BY posts.created_at DESC LIMIT ?

User.where { (active == true) & ((role == "admin") | (role == "moderator")) }.all
# ... WHERE (users.active = ?) AND ((users.role = ?) OR (users.role = ?))
```

## Filter by a Subquery

```crystal
# ✅ One statement: pass a CQL::Query to in through the model's table_column
published_authors = AppDB.query.from(:posts).select(:user_id).where(published: true)
User.where { User.table_column(:id).in(published_authors) }.all
# ... WHERE users.id IN (SELECT posts.user_id FROM posts WHERE posts.published = ?)

# Two statements: collect the ids, then bind them (typed columns take an Array)
author_ids = Post.where(published: true).pluck(:user_id, as: Int64)
User.where { id.in(author_ids) }.all  # ... WHERE users.id IN (?, ?, ...)
```

## Aggregate

```crystal
User.count                                  # SELECT COUNT(*) FROM users
User.where(active: true).count              # SELECT COUNT(*) FROM users WHERE users.active = ?
Post.where(published: true).sum(:views_count) # SELECT SUM(posts.views_count) FROM posts WHERE ...
User.where(active: true).avg(:age)          # SELECT AVG(users.age) ...; average is the same
Post.min(:views_count)                      # min / max read numeric columns
Post.max(:views_count)
Post.order(created_at: :asc).first          # the oldest row: order instead of min on a Time column
```

## Group and Filter Groups

Model queries map every row to the model, so group on `CQL::Query` (`AppDB.query`) and give `all` the row shape:

```crystal
rows = AppDB.query
  .from(:posts)
  .select(:category_id, count: :id)
  .group(:category_id)
  .having { count(:id) > 5 }
  .all(as: {Int64, Int64})
# SELECT posts.category_id, COUNT(posts.id) FROM posts GROUP BY posts.category_id HAVING COUNT(posts.id) > ?
rows.each { |category_id, post_count| puts "#{category_id}: #{post_count}" }

# ❌ One COUNT query per user
User.where(active: true).all.map { |user| {user, Post.where(user_id: user.id!).count} }

# ✅ One grouped query, sorted in Crystal
counts = AppDB.query.from(:posts)
  .select(:user_id, count: :id)
  .where(published: true)
  .group(:user_id)
  .all(as: {Int64, Int64})
top_authors = counts.sort_by { |(_, posts)| -posts }.first(10)
```

## Order and Deduplicate

```crystal
Post.order(published: :desc, created_at: :desc).all
# ... ORDER BY posts.published DESC, posts.created_at DESC

Post.distinct(:category_id, as: Int64)                         # => [1, 2, 3]
Post.where(published: true).distinct_values(:category_id, as: Int64)
# SELECT DISTINCT posts.category_id FROM posts WHERE posts.published = ?
```

To read single columns or partial rows, see [Read Values Without Records](find-records.md#read-values-without-records) and [Select Columns](typed-where-dsl.md#select-columns).

`distinct_on` keeps the first row of each group, in the query's order:

```crystal
AppDB.query.from(:posts).select(:user_id, :title)
  .order(user_id: :asc, created_at: :desc)
  .distinct_on(:user_id)
```

{% tabs %}
{% tab title="PostgreSQL, CockroachDB" %}
```sql
SELECT DISTINCT ON (posts.user_id) posts.user_id, posts.title FROM posts ORDER BY posts.user_id ASC, posts.created_at DESC
```
{% endtab %}

{% tab title="SQLite, MySQL" %}
Generating the SQL raises `CQL::DialectError` ("SQLite does not support DISTINCT ON", and likewise on MySQL). Number the rows with `ROW_NUMBER()` in a CTE and keep row 1 instead, as in [Filter on a Window Result](../advanced-sql/window-functions.md#filter-on-a-window-result).
{% endtab %}
{% endtabs %}

## Query Associated Records

Start from the model, as in `Post.where(user_id: user.id!)`, to keep scopes and typed blocks: an association collection's `where`, `order` and `limit` return a plain `CQL::Query` (see [Read the Posts](../relationships/has-many.md#read-the-posts)). To join associations, use `User.query.joins(:posts)` and `left_joins` from [Join Associations](typed-where-dsl.md#join-associations).

## Fall Back to Raw SQL

For a fragment inside a query, see [Use Raw SQL Fragments Safely](../advanced-sql/raw-fragments.md). Run a whole statement on a pooled connection and map the rows yourself:

```crystal
rows = AppDB.exec_query do |conn|
  conn.query_all(<<-SQL, as: {String, Int64})
    SELECT u.name, COUNT(p.id) AS post_count
    FROM users u
    LEFT JOIN posts p ON p.user_id = u.id AND p.published = 1 -- SQLite stores booleans as 1/0
    GROUP BY u.id
    ORDER BY post_count DESC
    LIMIT 10
    SQL
end
```

## See Also

- [Filter with Where Clauses](filter-records.md)
- [Write Typed Queries](typed-where-dsl.md)
- [Create Query Scopes](scopes.md)
- [Use CTEs and Recursive CTEs](../advanced-sql/ctes.md)
- [Use Window Functions](../advanced-sql/window-functions.md)
- [Use Raw SQL Fragments Safely](../advanced-sql/raw-fragments.md)
