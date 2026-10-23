# Query JSON and Geospatial Columns

This guide shows you how to filter on values inside a JSON column (`json_eq`, `json_contains`), on distance from a point (`within_distance`), and case-insensitively (`ilike`).

The examples use a `documents(name, data, location)` table where `data` is a `JSON::Any` column and `location` holds a point.

```crystal
AppDB = CQL::Schema.define(:app, adapter: CQL::Adapter::SQLite, uri: "sqlite3://./app.db") do
  table :documents do
    primary :id, Int32
    column :name, String
    column :data, JSON::Any
    column :location, String, null: true
  end
end
```

## Compare a value inside a JSON document

`json_eq(path, value)` compares the value at a key or index path, read as text:

```crystal
AppDB.query.from(:documents).select(:name)
  .where { documents.data.json_eq(["profile", "country"], "US") }
```

The path is a single key (`"theme"`) or an array of keys and non-negative indexes (`["tags", 0]`). Each key may only contain word characters (letters, digits, `_`); anything else raises `ArgumentError` ("Invalid JSON path segment"), because keys become part of the path syntax.

The path is always bound as a parameter, and so is the value. Generated SQL per dialect:

| Dialect | SQL | Params |
| --- | --- | --- |
| PostgreSQL | `documents.data #>> $1::text[] = $2` | `["{profile,country}", "US"]` |
| MySQL | `JSON_UNQUOTE(JSON_EXTRACT(documents.data, ?)) = ?` | `["$.theme", "dark"]` for `json_eq("theme", "dark")` |
| SQLite | `CAST(json_extract(documents.data, ?) AS TEXT) = ?` | `["$.tags[0]", "a"]` for `json_eq(["tags", 0], "a")` |

Numbers and booleans are compared as text: `json_eq("age", 30)` binds `"30"` and `json_eq("ok", true)` binds `"true"`. On SQLite, where `json_extract` yields `1`/`0` for booleans, `true` and `false` still match correctly.

Run it:

```crystal
AppDB.query.from(:documents).select(:name)
  .where { documents.data.json_eq("age", 40) }
  .all(as: String)
```

It combines with other conditions; parameters keep their order (`["n", "{k}", "v"]` for `where(name: "n").where { documents.data.json_eq("k", "v") }` on PostgreSQL).

## Test JSON containment

`json_contains(json)` is true when the document contains the given JSON. Pass anything that serializes to JSON:

```crystal
AppDB.query.from(:documents).select(:name)
  .where { documents.data.json_contains({role: "admin"}) }
```

| Dialect | SQL | Params |
| --- | --- | --- |
| PostgreSQL | `documents.data @> $1::jsonb` | `["{\"role\":\"admin\"}"]` |
| MySQL | `JSON_CONTAINS(documents.data, ?)` | the JSON text |
| SQLite | not supported | raises `CQL::DialectError` ("SQLite does not support JSON containment") |

## Filter by distance

`within_distance(longitude, latitude, meters)` keeps rows whose point is within `meters` of the given position:

```crystal
AppDB.query.from(:documents).select(:name)
  .where { documents.location.within_distance(-122.4, 37.8, 500) }
```

PostgreSQL and CockroachDB use `ST_DWithin` on geography (so the distance is in meters):

```sql
SELECT documents.name FROM documents WHERE ST_DWithin(documents.location::geography, ST_SetSRID(ST_MakePoint($1::float8, $2::float8), 4326)::geography, $3::float8)
```

with params `[-122.4, 37.8, 500.0]`. MySQL uses `ST_Distance_Sphere` with an explicit long-lat point:

```sql
... WHERE ST_Distance_Sphere(documents.location, ST_GeomFromText(CONCAT('POINT(', ?, ' ', ?, ')'), 4326, 'axis-order=long-lat')) <= ?
```

Inputs are validated when the condition is built, raising `ArgumentError` for a longitude outside -180..180, a latitude outside -90..90, a distance that is negative, infinite or `NaN`, and non-finite coordinates.

Dialect notes:

- SQLite does not support it: `CQL::DialectError` ("SQLite does not support geospatial distance filters").
- PostgreSQL needs PostGIS for `ST_DWithin`. CockroachDB generates the same SQL.
- The MySQL form needs MySQL 8.0.13+ and expects an SRID 4326 column. It is not verified against a live MySQL server.

## Case-insensitive matching with ilike

```crystal
AppDB.query.from(:customers).select(:name)
  .where { customers.name.ilike("ad%") }
```

`not_ilike` is the negation. The pattern is bound as a parameter.

| Dialect | SQL for `ilike("ad%")` |
| --- | --- |
| PostgreSQL, CockroachDB | `customers.name ILIKE $1` (`NOT ILIKE` for `not_ilike`) |
| MySQL, SQLite | `LOWER(customers.name) LIKE LOWER(?)` (`NOT LIKE` for `not_ilike`) |

On SQLite, `where { users.name.ilike("aDA") }` matches a row named `Ada`.

## Models

In the typed model DSL, JSON columns (`JSON::Any`) offer `json_eq` and `json_contains`, and `String` columns offer `like`, `not_like`, `ilike` and `not_ilike`:

```crystal
Document.query.where { data.json_eq(["profile", "country"], "US") }
Author.query.where { name.ilike("a%") }
```

`within_distance` is a method of the untyped column expression and is not part of the typed column proxy. On a model, reach the expression with `table_column`: `Place.where { Place.table_column(:location).within_distance(-122.4, 37.8, 500) }` (this form is not covered by a spec). See [Write Typed Queries](typed-where-dsl.md).

## Related

- [Write Typed Queries](typed-where-dsl.md)
- [Use Raw SQL Fragments Safely](raw-fragments.md) for operators CQL has no method for
- [Filter with Where Clauses](filter-records.md)
