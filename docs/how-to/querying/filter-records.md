# Filter with Where Clauses

Filter model queries with hash conditions, typed blocks and SQL fragments; every value is bound as a parameter.

## Match Values

```crystal
User.where(active: true).all
# SELECT users.id, ... FROM users WHERE users.active = ?

User.where(active: true, role: "admin").all        # ... WHERE (users.active = ?) AND (users.role = ?)
User.where(active: true).where(role: "admin").all  # chained calls are ANDed the same way
User.where(age: 18..65).all                        # ... WHERE users.age BETWEEN ? AND ?
User.where(role: ["admin", "moderator"]).all       # ... WHERE users.role IN (?, ?)
User.where(deleted_at: nil).all                    # ... WHERE users.deleted_at IS NULL
```

{% hint style="warning" %}
A `nil` value in `where`, `find_by`, `exists?`, `delete_by!` or `update_by` matches the rows whose column is NULL. Reject a `nil` that comes from untrusted input before you filter on it.
{% endhint %}

## Compare with a Block

Inside the block, bare names are the model's typed columns, so `age > "old"` or an unknown column fails to compile:

```crystal
User.where { age >= 18 }.all                           # ... WHERE users.age >= ?
User.where { status != "banned" }.all                  # ... WHERE users.status != ?
User.where { age.between(18, 65) }.all                 # ... WHERE users.age BETWEEN ? AND ?
User.where { role.in(["admin", "moderator"]) }.all     # ... WHERE users.role IN (?, ?)
User.where { role.not_in(["admin", "moderator"]) }.all # ... WHERE NOT (users.role IN (?, ?))

User.where { created_at > 1.week.ago }.all
Post.where { published_at.between(start_date, end_date) }.all

User.where { deleted_at != nil }.all                   # ... WHERE users.deleted_at IS NOT NULL
User.where { deleted_at.null }.all                     # IS NULL; deleted_at.not_null is IS NOT NULL
```

## Combine Conditions

Parenthesise each comparison, because `&` and `|` bind tighter than `==` in Crystal:

```crystal
User.where { (role == "admin") | (role == "moderator") }.all
# ... WHERE (users.role = ?) OR (users.role = ?)

User.where { (age > 18) & (active == true) }.all
# ... WHERE (users.age > ?) AND (users.active = ?)

User.where { (status == "banned").not }.all
# ... WHERE NOT (users.status = ?)

User.where(active: true).where { age > 18 }.all
# ... WHERE (users.active = ?) AND (users.age > ?)
```

## Match Patterns

```crystal
User.where { name.like("%ada%") }.all          # ... WHERE users.name LIKE ?
User.where { email.like("%@example.com") }.all
User.where { name.not_like("test%") }.all      # ... WHERE users.name NOT LIKE ?
User.where { name.ilike("%ADA%") }.all         # case-insensitive:
# SQLite, MySQL: LOWER(users.name) LIKE LOWER(?)   PostgreSQL: users.name ILIKE $1
User.where_like(:name, "%ada%").all            # LIKE without a block
```

## Add a SQL Fragment

```crystal
# ❌ ArgumentError: Cannot mix ? and :name placeholders in one fragment
User.where("lower(email) = ? AND age > :age", "ada@example.com", age: 18)

# ✅ Positional ? values, in order
User.where("lower(email) = ? AND age > ?", "ada@example.com", 18).all

# ✅ Named :name values
User.where("lower(email) = :email AND age > :age", email: "ada@example.com", age: 18).all
# ... WHERE lower(email) = ? AND age > ?   params: ["ada@example.com", 18]
```

The fragment itself must be a literal you wrote; see [Use Raw SQL Fragments Safely](../advanced-sql/raw-fragments.md).

## Order, Limit and Count

```crystal
User.where(active: true).order(created_at: :desc).limit(10).all
# ... WHERE users.active = ? ORDER BY users.created_at DESC LIMIT ?

User.where(active: true).count # SELECT COUNT(*) FROM users WHERE users.active = ?
```

## See Also

- [Write Typed Queries](typed-where-dsl.md)
- [Find Records](find-records.md)
- [Build Complex Queries](complex-queries.md)
- [Create Query Scopes](scopes.md)
- [Use Raw SQL Fragments Safely](../advanced-sql/raw-fragments.md)
