# Write Typed Queries

This guide shows you how to filter and order model queries with bare column names that the compiler checks: `where { (age >= 18) & (status == "active") }`.

The examples use these models:

```crystal
class Author
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :authors

  property name : String
  property age : Int32
  property status : String
  property score : Float64?
  property created_at : Time?

  has_one :profile, Profile, foreign_key: :author_id
  has_many :books, Book, foreign_key: :author_id

  def initialize(@name, @age, @status = "active", @score = nil)
  end
end
```

`Profile` has `country : String` and `Book` has `title`, `pages`, both with an `author_id` foreign key.

## Filter with bare column names

Start from `Model.query` and use `where { }`. Inside the block, each column name is a typed accessor of the model:

```crystal
Author.query.where { (age >= 18) & (status == "active") }
```

```sql
... WHERE (authors.age >= ?) AND (authors.status = ?)    -- params: [18, "active"]
```

Combine with `&` (AND), `|` (OR) and `.not`. Parenthesise each comparison, because `&` and `|` bind tighter than `>=` or `==` in Crystal:

```crystal
Author.query.where { (age < 18) | (age > 65) }
# WHERE (authors.age < ?) OR (authors.age > ?)

Author.query.where { (status == "banned").not }
# WHERE NOT (authors.status = ?)
```

Chained `where` calls are ANDed: `where { age > 1 }.where { status == "x" }` gives `WHERE (authors.age > ?) AND (authors.status = ?)`.

The block can take a parameter if you prefer: `where { |author| author.age < 30 }`. The model class also has `Author.where { age > 1 }`.

## Operators

| Operator | Columns | Example |
| --- | --- | --- |
| `==`, `!=`, `<`, `<=`, `>`, `>=` (and `eq`, `neq`, `lt`, `lte`, `gt`, `gte`) | all | `age >= 18` |
| `== nil`, `!= nil`, `null`, `not_null` | all | `score == nil` is `IS NULL` |
| `in`, `not_in` | all | `age.in([1, 2, 3])` |
| `between(min, max)` | all | `age.between(1, 9)` |
| `like`, `not_like`, `ilike`, `not_ilike` | `String` only | `name.like("A%")` |
| `json_eq`, `json_contains` | `JSON::Any` only | `data.json_eq("k", "v")` |

```crystal
Author.query.where { age.in([1, 2, 3]) & age.between(1, 9) & name.like("A%") }
Author.query.where { score.null }
# WHERE authors.score IS NULL
```

Values are always bound as parameters. Comparing two columns of the same type works too: `lt(other_column)`.

Integer literals fit wider or narrower integer columns, and an integer literal can compare against a float column: `id == 7` on an `Int64` column, `score > 1` on `Float64` (bound as `1.0`). A literal that does not fit raises `ArgumentError` naming the column ("3000000000 does not fit a Int32").

## What the compiler rejects

| Mistake | Result |
| --- | --- |
| `where { agee > 1 }` (unknown column) | compile error naming the model and the column |
| `where { age > "old" }` | compile error: cannot compare a Int32 column with String |
| `order_by(nope: :asc)` | compile error listing the model's columns |
| `joins(:books) { name_of_book == 1 }` | compile error: no such column |
| `joins(:nope)` | runtime `ArgumentError` listing the valid associations |

Because the checks happen at compile time, a typo never reaches the database.

## Order with order_by

```crystal
Author.query.order_by(created_at: :desc, name: :asc)
# ORDER BY authors.created_at DESC, authors.name ASC
```

Column names are checked at compile time. The untyped `order(name: :asc)` keeps working too.

## Join associations

`joins(:assoc)` and `left_joins(:assoc)` use the association declared on the model. The optional block adds typed conditions to the join and can reach the association's columns by name:

```crystal
Author.query.joins(:profile) { profile.country == "US" }
# INNER JOIN profiles ON (profiles.author_id = authors.id) AND (profiles.country = ?)

Author.query.joins(:books)
# INNER JOIN books ON books.author_id = authors.id

Book.query.joins(:author)
# INNER JOIN authors ON authors.id = books.author_id

Author.query.left_joins(:profile) { (profile.country == "US") & (age > 1) }
# LEFT JOIN profiles ON (profiles.author_id = authors.id) AND ((profiles.country = ?) AND (authors.age > ?))
```

`has_one`, `has_many` and `belongs_to` associations can be joined. Counts, `pluck` and `find_each` keep working across a join.

## Select columns and fetch

`to_a` is `all`. A partial `select` returns lightweight `Model::Row` records in which the unselected columns are `nil`, and keeps the chain:

```crystal
rows = Author.query
  .where { (age >= 18) & (status == "active") }
  .joins(:profile) { profile.country == "US" }
  .select(:id, :name)
  .order_by(age: :desc)
  .limit(20)
  .to_a

rows.first.name # String?
rows.first.age  # nil, because it was not selected
```

`select` with an unknown column raises `ArgumentError` naming the model and its columns. `preload` after a partial `select` is refused.

## The metadata behind it

For every model with a `db_context`, CQL generates:

- `Author::Columns`: one typed accessor per scalar getter, and one per association returning the target model's `Columns`.
- `Author.cql_columns`: the `Columns` proxy for the model's table (what the `where` block runs on).
- `Author.cql_association(:profile)`: the joined table name and a proc that builds the `ON` condition; it raises with the valid association names for an unknown one.
- `Author.cql_column(:name)` and `Author.cql_column_names`: the schema column, or an error naming the available columns; and the list of column names. Computed methods such as a `shout` helper are not columns.
- `Author::Row`: the record type for partial selects.

## Mix in raw SQL

Typed blocks combine with raw fragments: use `CQL.raw` inside the block, or the string form of `where`:

```crystal
Author.query.where { (age >= 18) & CQL.raw("lower(name) = ?", "ada") }
Author.query.where("lower(name) = :name", name: "ada")
```

See [Use Raw SQL Fragments Safely](raw-fragments.md).

## Related

- [Filter with Where Clauses](filter-records.md)
- [Build Complex Queries](complex-queries.md)
- [Use Raw SQL Fragments Safely](raw-fragments.md)
- [Query JSON and Geospatial Columns](json-and-geo-predicates.md)
- [The query DSL: before and after](../../explanation/dsl-before-after.md)
