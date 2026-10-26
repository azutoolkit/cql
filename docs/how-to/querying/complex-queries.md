# Build Complex Queries

Combine conditions, subqueries, aggregates, grouping, joins and raw SQL in one query.

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

## Select, Order and Deduplicate

```crystal
User.where(active: true).pluck(:name, as: String)  # => Array(String)
rows = User.where(active: true).select(:id, :name).all
rows.first.name                                    # => "Ada"; Array(User::Row), unselected columns are nil

Post.order(published: :desc, created_at: :desc).all
# ... ORDER BY posts.published DESC, posts.created_at DESC

Post.distinct(:category_id, as: Int64)                         # => [1, 2, 3]
Post.where(published: true).distinct_values(:category_id, as: Int64)
# SELECT DISTINCT posts.category_id FROM posts WHERE posts.published = ?

# PostgreSQL and CockroachDB: the first row of each group, in the query's order
AppDB.query.from(:posts).select(:user_id, :title)
  .order(user_id: :asc, created_at: :desc)
  .distinct_on(:user_id)
# SELECT DISTINCT ON (posts.user_id) posts.user_id, posts.title FROM posts ORDER BY ...
# SQLite and MySQL raise CQL::DialectError "... does not support DISTINCT ON" when SQL is generated
```

## Query Associated Records

```crystal
# The model's QueryBuilder keeps scopes and typed blocks
Post.where(user_id: user.id!, published: true).all
Post.where(user_id: user.id!).order(created_at: :desc).limit(5).all

# Collection methods (where, order, limit, offset) return a plain CQL::Query
user.posts.where(published: true).all(Post)
user.posts.order(created_at: :desc).limit(5).all(Post)
```

## Join Associations

`joins` and `left_joins` are on `QueryBuilder` (`User.query`), not on the model class:

```crystal
User.query.joins(:posts) { posts.published == true }.all
# SELECT users.id, ..., posts.id, ... FROM users INNER JOIN posts ON (posts.user_id = users.id) AND (posts.published = ?)

User.query.left_joins(:profile).where { age > 18 }.all
# ... FROM users LEFT JOIN profiles ON profiles.user_id = users.id WHERE users.age > ?
```

## Fall Back to Raw SQL

```crystal
User.where("lower(email) = ? AND age > ?", "ada@example.com", 18).all

# A whole statement: run it on a pooled connection and map the rows yourself
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
