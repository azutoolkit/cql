---
description: "Filter on values inside a JSON column and on distance from a point; every path, value and coordinate is bound as a parameter."
---

# Query JSON and Geospatial Columns

The examples use a `documents` table:

```crystal
AppDB = CQL::Schema.define(:app_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://./app.db") do
  table :documents do
    primary :id, Int64, auto_increment: true
    column :name, String
    column :data, JSON::Any
    column :location, String, null: true
  end
end

def documents_query # a fresh query for each example
  AppDB.query.from(:documents).select(:name)
end
```

## Compare a Value Inside a Document

`json_eq(path, value)` compares the value at a key, an index, or an array of them, read as text:

```crystal
documents_query.where { documents.data.json_eq(["profile", "country"], "US") }
```

{% tabs %}
{% tab title="PostgreSQL, CockroachDB" %}
```sql
SELECT documents.name FROM documents WHERE documents.data #>> $1::text[] = $2
-- params: ["{profile,country}", "US"]
```
{% endtab %}

{% tab title="MySQL" %}
```sql
SELECT documents.name FROM documents WHERE JSON_UNQUOTE(JSON_EXTRACT(documents.data, ?)) = ?
-- params: ["$.profile.country", "US"]
```
{% endtab %}

{% tab title="SQLite" %}
```sql
SELECT documents.name FROM documents WHERE CAST(json_extract(documents.data, ?) AS TEXT) = ?
-- params: ["$.profile.country", "US"]
```
{% endtab %}
{% endtabs %}

```crystal
documents_query.where { documents.data.json_eq(["tags", 0], "y") }.all(as: String) # SQLite path "$.tags[0]"
documents_query.where { documents.data.json_eq("age", 40) }.all(as: String)       # => ["grace"]; binds "40"
documents_query.where { documents.data.json_eq("ok", true) }                      # binds "true"; "1" on SQLite (json_extract gives 1/0)

# Keys may hold only word characters; indexes must not be negative
documents_query.where { documents.data.json_eq("a'] OR 1=1 --", "x") }
# ArgumentError: Invalid JSON path segment "a'] OR 1=1 --": use word characters or a non-negative index

documents_query.where(name: "n").where { documents.data.json_eq("k", "v") }.to_sql(for: CQL::Adapter::Postgres)
# ... WHERE (documents.name = $1) AND (documents.data #>> $2::text[] = $3)   params: ["n", "{k}", "v"]
```

## Test JSON Containment

`json_contains(value)` is true when the document contains `value`, which can be anything that serializes to JSON:

```crystal
documents_query.where { documents.data.json_contains({role: "admin"}) }
```

{% tabs %}
{% tab title="PostgreSQL, CockroachDB" %}
```sql
SELECT documents.name FROM documents WHERE documents.data @> $1::jsonb
-- params: ["{\"role\":\"admin\"}"]
```
{% endtab %}

{% tab title="MySQL" %}
```sql
SELECT documents.name FROM documents WHERE JSON_CONTAINS(documents.data, ?)
-- params: ["{\"role\":\"admin\"}"]
```
{% endtab %}

{% tab title="SQLite" %}
Generating the SQL raises `CQL::DialectError` ("SQLite does not support JSON containment").
{% endtab %}
{% endtabs %}

## Filter by Distance

`within_distance(longitude, latitude, meters)` keeps rows whose point lies within `meters` of the position:

```crystal
documents_query.where { documents.location.within_distance(-122.4, 37.8, 500) }
```

{% tabs %}
{% tab title="PostgreSQL, CockroachDB" %}
A PostGIS `geography`, so the distance is in meters. PostgreSQL needs the PostGIS extension.

```sql
SELECT documents.name FROM documents
WHERE ST_DWithin(documents.location::geography, ST_SetSRID(ST_MakePoint($1::float8, $2::float8), 4326)::geography, $3::float8)
-- params: [-122.4, 37.8, 500.0]
```
{% endtab %}

{% tab title="MySQL" %}
Needs MySQL 8.0.13+ and an SRID 4326 column. This form has not been run against a live MySQL server.

```sql
SELECT documents.name FROM documents
WHERE ST_Distance_Sphere(documents.location, ST_GeomFromText(CONCAT('POINT(', ?, ' ', ?, ')'), 4326, 'axis-order=long-lat')) <= ?
-- params: [-122.4, 37.8, 500.0]
```
{% endtab %}

{% tab title="SQLite" %}
Generating the SQL raises `CQL::DialectError` ("SQLite does not support geospatial distance filters").
{% endtab %}
{% endtabs %}

Out-of-range values raise `ArgumentError` when the condition is built, on every database:

```crystal
# A NaN coordinate fails the range check too
documents_query.where { documents.location.within_distance(181.0, 0.0, 1) } # longitude must be between -180 and 180
documents_query.where { documents.location.within_distance(0.0, -91.0, 1) } # latitude must be between -90 and 90
documents_query.where { documents.location.within_distance(1.0, 2.0, -1) }  # distance must not be negative
documents_query.where { documents.location.within_distance(0.0, 0.0, Float64::INFINITY) } # distance must be finite
```

## Use Them on Models

In the typed model DSL, `JSON::Any` columns offer `json_eq` and `json_contains`. `within_distance` is not on the typed columns; reach the column expression with `table_column`:

```crystal
# Document: a model over documents whose data getter is JSON::Any
Document.query.where { data.json_eq(["profile", "country"], "US") }
Document.where { Document.table_column(:location).within_distance(-122.4, 37.8, 500) }
```

For case-insensitive matching with `ilike` and `not_ilike`, see [Match Patterns](../querying/filter-records.md#match-patterns).

## See Also

- [Write Typed Queries](../querying/typed-where-dsl.md)
- [Use Raw SQL Fragments Safely](raw-fragments.md)
- [Filter with Where Clauses](../querying/filter-records.md)
- [Inspect Queries with to_sql and explain](../querying/explain-and-to-sql.md)
