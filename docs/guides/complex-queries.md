# Complex Queries in CQL

CQL provides a powerful, type-safe query builder that allows you to compose sophisticated SQL queries using idiomatic Crystal code. This guide demonstrates how to build complex queries using `Model.query` and the `CQL::Query` interface.

---

## Advanced Filtering

Combine multiple conditions, logical operators, and expressions:

```crystal
# Multiple AND/OR conditions
users = User.query.where { (age >= 18) & (active == true) }
                 .where { (name.like("A%")) | (email.like("%@gmail.com")) }
                 .all(User)

# Nested conditions
admins = User.query.where { (role == "admin") & ((status == "active") | (status == "pending")) }
                   .all(User)

# IN and NOT IN
moderators = User.query.where { role.in(["admin", "moderator"]) }
                       .all(User)

excluded = User.query.where { id.not_in([1, 2, 3]) }
                     .all(User)
```

---

## Complex Joins

Join multiple tables, use aliases, and filter on joined data:

```crystal
# Join with conditions
users_with_posts = User.query.join(Post) { users.id == posts.user_id }
                            .where { posts.published == true }
                            .all(User)

# Multiple joins with aliases
User.query.from(users: :u)
         .join({posts: :p}) { u.id == p.user_id }
         .join({comments: :c}) { p.id == c.post_id }
         .where { c.created_at > 1.week.ago }
         .all(User)
```

---

## Grouping, Aggregation, and Having

Use grouping and aggregate functions for reporting and analytics:

```crystal
# Group by and aggregate
role_stats = User.query.select { [role, CQL.count(id).as("total")] }
                      .group_by(:role)
                      .all(User)

# Group by multiple columns
stats = Post.query.select { [user_id, CQL.count(id).as("post_count")] }
                  .group_by(:user_id)
                  .having { CQL.count(id) > 5 }
                  .all(Post)

# Aggregates: sum, avg, min, max
summary = Order.query.select { [CQL.sum(:total).as("total_sum"), CQL.avg(:total).as("avg_total")] }
                     .where { status == "paid" }
                     .all(Order)
```

---

## Subqueries

Use subqueries for advanced filtering and data retrieval:

```crystal
# Users with more than 5 posts
users = User.query.where { id.in(
  Post.query.select(:user_id)
      .group_by(:user_id)
      .having { CQL.count(id) > 5 }
) }.all(User)

# Users with recent activity in posts or comments
users = User.query.where { id.in(
  Post.query.select(:user_id)
      .where { created_at > 1.week.ago }
      .union(
        Comment.query.select(:user_id)
               .where { created_at > 1.week.ago }
      )
) }.all(User)
```

---

## Common Table Expressions (CTEs)

Use CTEs for reusable subqueries and complex data transformations:

```crystal
# Users with their post and comment counts
User.query.with(:user_stats) {
  User.query.select { [id,
                      CQL.count(posts.id).as("post_count"),
                      CQL.count(comments.id).as("comment_count")] }
      .left_join(Post) { users.id == posts.user_id }
      .left_join(Comment) { users.id == comments.user_id }
      .group_by(:id)
}
.select { [users.*, user_stats.*] }
.join(:user_stats) { users.id == user_stats.id }
.all(User)
```

---

## Pagination with Complex Queries

Combine pagination with other query methods:

```crystal
# Paginated search with sorting
page = 2
per_page = 20
users = User.query.where { name.like("%search%") }
                .order(:name)
                .offset((page - 1) * per_page)
                .limit(per_page)
                .all(User)
```

---

## Best Practices for Complex Queries

- Use table aliases for clarity in multi-join queries.
- Use block syntax for complex conditions to improve readability.
- Use `.select` to limit columns and improve performance.
- Use `.group_by` and aggregates for reporting.
- Use subqueries and CTEs for advanced analytics and filtering.
- Always test and inspect generated SQL with `.to_sql` for correctness and performance.

---

For more details on the query interface, see the [Querying guide](./active-record-with-cql/querying.md).
