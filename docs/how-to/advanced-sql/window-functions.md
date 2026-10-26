---
description: "Add ROW_NUMBER, running totals, LAG and other window functions to a CQL::Query (AppDB.query) with window; QueryBuilder and model classes do not have it."
---

# Use Window Functions

The examples use a `staff(id, dept, name, salary)` table.

## Rank Rows Within a Group

```crystal
AppDB.query.from(:staff).select(:name)
  .window(:row_number, as: :position, partition_by: :dept, order_by: {salary: :desc})
# SELECT staff.name, ROW_NUMBER() OVER (PARTITION BY staff.dept ORDER BY staff.salary DESC) AS position FROM staff

AppDB.query.from(:staff).window(:row_number, as: :position, order_by: :id)
# SELECT ROW_NUMBER() OVER (ORDER BY staff.id ASC) AS position FROM staff   (no select: only the window column)
```

Window columns are added in the order you call them, mixed with any aggregates: `count(as: :n).window(...)` renders `SELECT COUNT(*) AS n, ROW_NUMBER() OVER (...) AS rn`.

## Arguments

```crystal
query = AppDB.query.from(:staff).select(:name)

query.window(:sum, :salary,         # the function, then its column
  as: :running,                     # required alias
  partition_by: :dept,              # a column or an array of columns
  order_by: {id: :asc},             # a column, an array (each ASC), or {column => :asc | :desc}
  rows: {:unbounded_preceding, 0})  # or range: a frame {start, end}
# offset: lag and lead only, not negative. buckets: ntile only (required), positive.

# No column:       row_number rank dense_rank percent_rank cume_dist ntile
# Column required: lag lead first_value last_value sum avg min max
# Column optional: count (COUNT(*) without one)

query.window(:rank, as: :r, partition_by: [:dept, :name], order_by: [:salary, :id])
# RANK() OVER (PARTITION BY staff.dept, staff.name ORDER BY staff.salary ASC, staff.id ASC) AS r
```

Each call adds one column to `query`. Column names resolve against the query's tables; an unknown one raises `ArgumentError`.

## Aggregate Over a Window

```crystal
query.window(:sum, :salary, as: :dept_total, partition_by: :dept)
# SUM(staff.salary) OVER (PARTITION BY staff.dept) AS dept_total

query.window(:count, as: :n) # COUNT(*) OVER () AS n
```

## Look at Neighbouring Rows

```crystal
query.window(:lag, :salary, offset: 2, as: :before, order_by: :id)
# LAG(staff.salary, 2) OVER (ORDER BY staff.id ASC) AS before
query.window(:lead, :salary, as: :after, order_by: :id)
# LEAD(staff.salary) OVER (ORDER BY staff.id ASC) AS after
query.window(:first_value, :name, as: :top, order_by: {salary: :desc})
# FIRST_VALUE(staff.name) OVER (ORDER BY staff.salary DESC) AS top
query.window(:ntile, buckets: 4, as: :quartile, order_by: :salary)
# NTILE(4) OVER (ORDER BY staff.salary ASC) AS quartile
```

## Set a Frame

Bounds are offsets (negative is preceding, `0` the current row, positive following) or `:unbounded_preceding` / `:unbounded_following`:

```crystal
query.window(:avg, :salary, as: :moving, order_by: :id, rows: {-2, 0})
# AVG(staff.salary) OVER (ORDER BY staff.id ASC ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving
query.window(:sum, :salary, as: :running, order_by: :id, rows: {:unbounded_preceding, 0})
# ... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
query.window(:sum, :salary, as: :ahead, order_by: :id, range: {0, :unbounded_following})
# ... RANGE BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING
query.window(:sum, :salary, as: :next_two, order_by: :id, rows: {1, 2})
# ... ROWS BETWEEN 1 FOLLOWING AND 2 FOLLOWING

# ArgumentError: both rows and range, a start of :unbounded_following, an end of :unbounded_preceding,
# a start after the end, or a range offset without order_by
```

## Run It

```crystal
AppDB.query.from(:staff).select(:name)
  .window(:sum, :salary, as: :running, order_by: :id, rows: {:unbounded_preceding, 0})
  .window(:sum, :salary, as: :dept_total, partition_by: :dept)
  .order(id: :asc)
  .all(as: {String, Int64, Int64}) # SQLite returns the window sums as Int64
# => [{"ada", 300, 600}, {"grace", 500, 600}, {"linus", 600, 600}, {"kim", 750, 200}, {"lee", 800, 200}]

AppDB.query.from(:staff).select(:name)
  .window(:lag, :salary, as: :previous, order_by: :id)
  .all(as: {String, Int64?}) # the first row has no previous one: nil
```

## Filter on a Window Result

SQL does not allow a window function in `WHERE`, so wrap the windowed query in a CTE and filter on its column:

```crystal
# ❌ A local variable named like the CTE hides it inside the block: undefined method 'rn' for CQL::Query
ranked = AppDB.query.from(:staff).select(:name, :dept)
  .window(:row_number, as: :rn, partition_by: :dept, order_by: {salary: :desc})
AppDB.query.with(:ranked, ranked).from(:ranked).where { ranked.rn <= 2 }

# ✅ The top two earners per department
ranked_staff = AppDB.query.from(:staff).select(:name, :dept)
  .window(:row_number, as: :rn, partition_by: :dept, order_by: {salary: :desc})

AppDB.query.with(:ranked, ranked_staff).from(:ranked).select(:name)
  .where { ranked.rn <= 2 }
  .order(name: :asc)
  .all(as: String) # => ["ada", "grace", "kim", "lee"]
```

{% hint style="info" %}
Window functions need MySQL 8.0+ and SQLite 3.25+; PostgreSQL and CockroachDB support them. Windows read plain table columns, not aggregates.
{% endhint %}

{% hint style="warning" %}
Aliases are checked as identifiers (`as: :"x; DROP TABLE staff"` raises `Invalid alias`). On MySQL, avoid window function names (`rank`, `row_number`) as aliases unless the schema sets `quote_identifiers: true`, which quotes them (`` AS `rank` ``).
{% endhint %}

## See Also

- [Use CTEs and Recursive CTEs](ctes.md)
- [Build Complex Queries](../querying/complex-queries.md)
- [Inspect Queries with to_sql and explain](../querying/explain-and-to-sql.md)
- [Write Typed Queries](../querying/typed-where-dsl.md)
