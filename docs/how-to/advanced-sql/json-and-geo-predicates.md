# Query JSON and Geospatial Columns

Filter on values inside a JSON column (`json_eq`, `json_contains`), on distance from a point (`within_distance`), and case-insensitively (`ilike`). Every path, value and coordinate is bound as a parameter.

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
# PostgreSQL: WHERE documents.data #>> $1::text[] = $2                    params: ["{profile,country}", "US"]
# MySQL:      WHERE JSON_UNQUOTE(JSON_EXTRACT(documents.data, ?)) = ?    params: ["$.profile.country", "US"]
# SQLite:     WHERE CAST(json_extract(documents.data, ?) AS TEXT) = ?    params: ["$.profile.country", "US"]

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
# PostgreSQL, CockroachDB: WHERE documents.data @> $1::jsonb   params: ["{\"role\":\"admin\"}"]
# MySQL:                   WHERE JSON_CONTAINS(documents.data, ?)
# SQLite:                  CQL::DialectError "SQLite does not support JSON containment"
```

## Filter by Distance

`within_distance(longitude, latitude, meters)` keeps rows whose point lies within `meters` of the position:

```crystal
documents_query.where { documents.location.within_distance(-122.4, 37.8, 500) }
# PostgreSQL, CockroachDB (PostGIS geography, so meters):
#   WHERE ST_DWithin(documents.location::geography, ST_SetSRID(ST_MakePoint($1::float8, $2::float8), 4326)::geography, $3::float8)
# MySQL 8.0.13+, an SRID 4326 column:
#   WHERE ST_Distance_Sphere(documents.location, ST_GeomFromText(CONCAT('POINT(', ?, ' ', ?, ')'), 4326, 'axis-order=long-lat')) <= ?
# params: [-122.4, 37.8, 500.0]
# SQLite: CQL::DialectError "SQLite does not support geospatial distance filters"

# ArgumentError when the condition is built (a NaN coordinate fails the range check):
documents_query.where { documents.location.within_distance(181.0, 0.0, 1) } # longitude must be between -180 and 180
documents_query.where { documents.location.within_distance(0.0, -91.0, 1) } # latitude must be between -90 and 90
documents_query.where { documents.location.within_distance(1.0, 2.0, -1) }  # distance must not be negative
documents_query.where { documents.location.within_distance(0.0, 0.0, Float64::INFINITY) } # distance must be finite
```

## Match Case-Insensitively

```crystal
AppDB.query.from(:customers).select(:name).where { customers.name.ilike("ad%") }
# PostgreSQL, CockroachDB: customers.name ILIKE $1                 (not_ilike: NOT ILIKE)
# MySQL, SQLite:           LOWER(customers.name) LIKE LOWER(?)     (not_ilike: NOT LIKE)
```

## Use Them on Models

In the typed model DSL, `JSON::Any` columns offer `json_eq` and `json_contains`, and `String` columns offer `like`, `not_like`, `ilike` and `not_ilike`. `within_distance` is not on the typed columns; reach the column expression with `table_column`:

```crystal
# Document: a model over documents whose data getter is JSON::Any
Document.query.where { data.json_eq(["profile", "country"], "US") }
User.query.where { name.ilike("a%") }
Document.where { Document.table_column(:location).within_distance(-122.4, 37.8, 500) }
```

{% hint style="info" %}
`within_distance` on PostgreSQL needs the PostGIS extension. The MySQL distance form has not been run against a live MySQL server.
{% endhint %}

## See Also

- [Write Typed Queries](../querying/typed-where-dsl.md)
- [Use Raw SQL Fragments Safely](raw-fragments.md)
- [Filter with Where Clauses](../querying/filter-records.md)
- [Inspect Queries with to_sql and explain](../querying/explain-and-to-sql.md)
