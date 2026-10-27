---
description: "Filter, order and join model queries with bare column names that the compiler checks."
---

# Write Typed Queries

The examples use a `User` with `name`, `email`, `role`, `status : String`, `age : Int32`, `score : Float64?` and `created_at : Time?`, which `has_one :profile` (`country : String`) and `has_many :posts`.

## Filter with Bare Column Names

```crystal
User.query.where { (age >= 18) & (status == "active") }
# ... WHERE (users.age >= ?) AND (users.status = ?)   params: [18, "active"]

User.query.where { (age < 18) | (age > 65) }   # ... WHERE (users.age < ?) OR (users.age > ?)
User.query.where { (status == "banned").not }  # ... WHERE NOT (users.status = ?)
User.query.where { age > 1 }.where { status == "x" } # ... WHERE (users.age > ?) AND (users.status = ?)

User.query.where { |user| user.age < 30 }      # the block may take the columns as a parameter
User.where { age > 1 }                         # the model class has where { } too
```

Parenthesise each comparison: `&` and `|` bind tighter than `>=` and `==` in Crystal.

## Use the Operators

```crystal
# ==, !=, <, <=, >, >= and eq, neq, lt, lte, gt, gte: every column
User.query.where { age.eq(3) | age.gte(9) }
# == nil, != nil, null, not_null: every column
User.query.where { score == nil }              # ... WHERE users.score IS NULL
User.query.where { score.not_null }            # ... WHERE users.score IS NOT NULL
# in, not_in (an Array), between: every column
User.query.where { age.in([1, 2, 3]) & age.between(1, 9) }
User.query.where { id.in([] of Int64) }  # ... WHERE 1 = 0: an empty list matches no row (not_in: every row)
# like, not_like, ilike, not_ilike, contains, starts_with, ends_with: String columns
User.query.where { name.like("A%") }           # ... WHERE users.name LIKE ?
User.query.where { name.contains("50%") }      # ... WHERE users.name LIKE ? ESCAPE '!': see Filter with Where Clauses
# json_eq, json_contains: JSON::Any columns; see Query JSON and Geospatial Columns

User.query.where { id == 7 }                   # an integer literal fits an Int64 column
User.query.where { score > 1 }                 # and a Float64 column: bound as 1.0
Post.query.where { views_count > id }          # another column of the same type: posts.views_count > posts.id
```

## Let the Compiler Catch Mistakes

```crystal
# ❌ Compile errors
User.query.where { agee > 1 }                  # undefined local variable or method 'agee' for User::Columns
User.query.where { age > "old" }               # CQL: cannot compare a Int32 column with String using `>`
User.query.order_by(nope: :asc)                # CQL order_by: User has no column `nope`. Columns: id, name, ...
User.query.joins(:posts) { posts.nope == 1 }   # undefined method 'nope' for Post::Columns

# ❌ Runtime ArgumentError
User.query.joins(:nope)             # User has no association :nope. Associations: posts, profile
User.query.select(:name, :nope)     # User has no column :nope in table users. Columns: id, name, ...
User.query.where { age == 3_000_000_000 } # ArgumentError: 3000000000 does not fit a Int32 column (users.age)
```

<details>

<summary>Full compiler output for the String comparison</summary>

```text
Showing last frame. Use --error-trace for full trace.

There was a problem expanding macro 'macro_140604030851904'

Code in src/active_record/dsl/column.cr:14:7

 14 | {% for name, sql in {"==" => "=", "!=" => "!=", "<" => "<", "<=" => "<=", ">" => ">", ">=" => ">=",
      ^
Called macro defined in src/active_record/dsl/column.cr:14:7

 14 | {% for name, sql in {"==" => "=", "!=" => "!=", "<" => "<", "<=" => "<=", ">" => ">", ">=" => ">=",

Which expanded to:

   147 |
   148 |         def >(other : U) : NoReturn forall U
 > 149 |           {% raise "CQL: cannot compare a #{T} column with #{U} using `>`; use a #{T} value or another #{T} column" %}
                      ^----
Error: CQL: cannot compare a Int32 column with String using `>`; use a Int32 value or another Int32 column
```

</details>

## Order with order_by

```crystal
User.query.order_by(created_at: :desc, name: :asc)
# ... ORDER BY users.created_at DESC, users.name ASC
```

The untyped `order(name: :asc)` works too, without the compile-time check.

## Join Associations

`joins(:assoc)` and `left_joins(:assoc)` take a `has_one`, `has_many` or `belongs_to` association. The optional block adds typed conditions to the `ON` clause and reaches the association's columns by name:

```crystal
User.query.joins(:profile) { profile.country == "US" }
# INNER JOIN profiles ON (profiles.user_id = users.id) AND (profiles.country = ?)

User.query.joins(:posts)  # INNER JOIN posts ON posts.user_id = users.id
Post.query.joins(:user)   # INNER JOIN users ON users.id = posts.user_id

User.query.left_joins(:profile) { (profile.country == "US") & (age > 1) }
# LEFT JOIN profiles ON (profiles.user_id = users.id) AND ((profiles.country = ?) AND (users.age > ?))

User.query.joins(:posts).count               # counts joined rows: one per post
User.query.joins(:profile).pluck(:name, as: String)
User.query.joins(:posts).find_each { |user| } # yields each user once
```

## Select Columns

```crystal
rows = User.query
  .where { (age >= 18) & (status == "active") }
  .joins(:profile) { profile.country == "US" }
  .select(:id, :name) # keeps the chain; returns User::Row records
  .order_by(age: :desc)
  .limit(20)
  .to_a               # to_a is all
# SELECT users.id, users.name FROM users INNER JOIN profiles ON ... WHERE ... ORDER BY users.age DESC LIMIT ?

rows.first.name # => "Ada" (String?)
rows.first.age  # => nil: not selected
User.query.select(:name).preload(:posts) # ArgumentError: preload is not supported after a partial select
```

## Mix in Raw SQL

Combine typed conditions with a SQL fragment through `CQL.raw` (bare `raw` does not compile in a model's block); see [Use Raw SQL Fragments Safely](../advanced-sql/raw-fragments.md#use-fragments-on-models-update-and-delete).

## Inspect the Generated Metadata

```crystal
User::Columns               # one typed accessor per column getter, one per association
User.cql_columns            # the User::Columns that where { } runs on
User.cql_column(:name)      # the schema column; ArgumentError listing the columns when unknown
User.cql_column_names       # => [:id, :name, :email, ...]; computed methods are not columns
User.cql_association(:profile) # => {:profiles, ON-condition proc}; ArgumentError when unknown
User::Row                   # the record type of a partial select
```

## See Also

- [Filter with Where Clauses](filter-records.md)
- [Build Complex Queries](complex-queries.md)
- [Use Raw SQL Fragments Safely](../advanced-sql/raw-fragments.md)
- [Query JSON and Geospatial Columns](../advanced-sql/json-and-geo-predicates.md)
