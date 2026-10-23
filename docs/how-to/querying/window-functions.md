# Use Window Functions

This guide shows you how to add window functions (`ROW_NUMBER`, running totals, `LAG`, ...) to a `CQL::Query` with `window`.

The examples use a `staff(dept, name, salary)` table.

## Rank rows within a group

```crystal
AppDB.query.from(:staff).select(:name)
  .window(:row_number, as: :position, partition_by: :dept, order_by: {salary: :desc})
```

```sql
SELECT staff.name, ROW_NUMBER() OVER (PARTITION BY staff.dept ORDER BY staff.salary DESC) AS position FROM staff
```

Without a preceding `select(...)`, only the window column is selected. Window columns are added in the order you call them, mixed with any aggregates.

## Arguments

```crystal
query.window(function, column = nil, as: :alias,
  partition_by: nil, order_by: nil, offset: nil, buckets: nil, rows: nil, range: nil)
```

- `function`: `row_number`, `rank`, `dense_rank`, `percent_rank`, `cume_dist`, `ntile`, `lag`, `lead`, `first_value`, `last_value`, `count`, `sum`, `avg`, `min`, `max`.
- `partition_by`: a column or an array of columns.
- `order_by`: a column, an array of columns (ascending), or a hash of `column => :asc | :desc`.
- `column`: required by `sum`, `avg`, `min`, `max` and the value functions (`count` without one renders `COUNT(*)`); ranking functions such as `row_number` reject it.
- Column names are resolved against the query's tables; an unknown name raises `ArgumentError`.

```crystal
query.window(:rank, as: :r, partition_by: [:dept, :name], order_by: [:salary, :id])
# RANK() OVER (PARTITION BY staff.dept, staff.name ORDER BY staff.salary ASC, staff.id ASC) AS r
```

## Aggregates over a window

```crystal
query.window(:sum, :salary, as: :dept_total, partition_by: :dept)
# SUM(staff.salary) OVER (PARTITION BY staff.dept) AS dept_total

query.window(:count, as: :n)
# COUNT(*) OVER () AS n
```

## Look at neighbouring rows

`lag` and `lead` take `offset:`; `ntile` takes `buckets:`:

```crystal
query.window(:lag, :salary, offset: 2, as: :before, order_by: :id)
# LAG(staff.salary, 2) OVER (ORDER BY staff.id ASC) AS before

query.window(:first_value, :name, as: :top, order_by: {salary: :desc})
# FIRST_VALUE(staff.name) OVER (ORDER BY staff.salary DESC) AS top

query.window(:ntile, buckets: 4, as: :quartile, order_by: :salary)
# NTILE(4) OVER (ORDER BY staff.salary ASC) AS quartile
```

`offset:` only applies to `lag`/`lead` and must not be negative; `buckets:` only applies to `ntile` and must be positive.

## Frames

Use `rows:` or `range:` with a `{start, end}` pair. Integers are offsets (negative means preceding, `0` is the current row); `:unbounded_preceding` and `:unbounded_following` are the open ends:

```crystal
query.window(:avg, :salary, as: :moving, order_by: :id, rows: {-2, 0})
# AVG(staff.salary) OVER (ORDER BY staff.id ASC ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving

query.window(:sum, :salary, as: :running, order_by: :id, rows: {:unbounded_preceding, 0})
# ... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW

query.window(:sum, :salary, as: :ahead, order_by: :id, range: {0, :unbounded_following})
# ... RANGE BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING

query.window(:sum, :salary, as: :next_two, order_by: :id, rows: {1, 2})
# ... ROWS BETWEEN 1 FOLLOWING AND 2 FOLLOWING
```

Invalid frames raise `ArgumentError`: both `rows` and `range`, a start of `:unbounded_following`, an end of `:unbounded_preceding`, a start after the end, or a `range` with an offset but no `order_by`.

## Run it

```crystal
rows = AppDB.query.from(:staff).select(:name)
  .window(:sum, :salary, as: :running, order_by: :id, rows: {:unbounded_preceding, 0})
  .window(:sum, :salary, as: :dept_total, partition_by: :dept)
  .order(id: :asc)
  .all(as: {String, Int64, Int64})
```

On SQLite the window sums come back as `Int64`.

## Filter on a window result

SQL does not allow a window function in `WHERE`. Wrap the windowed query in a CTE and filter on its column. This selects the top two earners per department:

```crystal
ranked = AppDB.query.from(:staff).select(:name, :dept)
  .window(:row_number, as: :rn, partition_by: :dept, order_by: {salary: :desc})

top = AppDB.query.with(:ranked, ranked).from(:ranked).select(:name)
  .where { ranked.rn <= 2 }
  .order(name: :asc)

top.all(as: String)
```

See [Use CTEs and Recursive CTEs](ctes.md).

## Dialect notes

- Window functions need MySQL 8.0+ and SQLite 3.25+; PostgreSQL and CockroachDB support them.
- Window aliases are checked as identifiers (`as: :"x; DROP TABLE staff"` raises `Invalid alias`). With `quote_identifiers: true` the alias is quoted: `... OVER (ORDER BY "staff"."id" ASC) AS "position"`.
- On MySQL, avoid window function names (`rank`, `row_number`, ...) as aliases unless `quote_identifiers` is on.
- Windows read plain table columns, not aggregates.
- `window` is defined on `CQL::Query` (`schema.query`), not on model query builders.

## Related

- [Use CTEs and Recursive CTEs](ctes.md)
- [Build Complex Queries](complex-queries.md)
- [The query DSL: before and after](../../explanation/dsl-before-after.md)
