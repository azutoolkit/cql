# Safety Guardrails

CQL tries to make the unsafe version of a query hard to write. This page explains the guardrails it applies, why each one exists, and where the responsibility passes back to you.

There are four layers, from the one that protects the most code to the one that protects the least:

1. Values are bound as parameters.
2. Identifiers that reach SQL are looked up in the schema, validated, or quoted.
3. Mistakes in types and relationships are caught when the program compiles.
4. Optional startup checks catch models that have drifted from the database.

## Values Are Always Bound

A value you pass to `where`, `insert`, `update`, `delete` or the typed DSL never becomes part of the SQL text. The generated statement holds a placeholder and the value travels separately:

```crystal
sql, params = MyDB.query.from(:users).where(name: "admin' OR '1'='1").to_sql
# sql    contains `users.name = ?` (a placeholder, SQLite and MySQL style)
# params => ["admin' OR '1'='1"]
```

The hostile string is just a string. This is why `to_sql` returns a pair of SQL and parameters, and why the specs assert on both.

The same holds for raw fragments. `where("lower(name) = ? AND age > :age", "ada", age: 18)` and `raw(...)` inside a `where { }` block bind every value; arrays expand to `IN (?, ?)` lists and quoted text and comments in the fragment are skipped. A value passed in the wrong placeholder style raises instead of being dropped.

**Your side of the contract:** the text of a raw fragment must be a literal in your source. Binding protects the values, not the fragment. Never build the fragment with string interpolation of user input.

```crystal
# Safe: the value is bound.
User.query.where("lower(email) = ?", params["email"].downcase)

# Unsafe: user input becomes SQL.
User.query.where("lower(email) = '#{params["email"]}'")
```

## Identifiers Cannot Be Bound

Table names, column names, aliases and constraint names are part of the statement's structure. A database driver cannot take them as parameters, so CQL handles them in three ways.

### 1. Resolve Them Against the Schema

Column names given to `where(attr: value)`, `order`, `where_like` and friends are looked up in the tables of the query. A name that is not a known column raises `ArgumentError` ("Column '...' not found") instead of reaching SQL, so `order(params[:sort])` with a bogus value fails rather than injects. An unknown name is still an error you should handle, and a known column the user should not sort by is still a column you must not expose. Check against an allow list of your own.

### 2. Validate Them With `CQL::Identifier`

Names that are not columns of your schema, such as aliases and constraint names, must look like a plain identifier:

```crystal
CQL::Identifier::PATTERN        # /\A[A-Za-z_][A-Za-z0-9_]*\z/
CQL::Identifier.valid?("n")     # => true
CQL::Identifier.valid?("n; DROP TABLE users") # => false
CQL::Identifier.validate!("total", "alias")   # => "total"
CQL::Identifier.validate!("a b", "alias")
# raises ArgumentError: Invalid alias "a b": only letters, digits and underscores are allowed, ...
```

`validate!` returns the name unchanged or raises `ArgumentError` naming the kind of identifier. `validate_qualified!` also accepts one `schema.name` qualifier.

CQL applies it to:

- aliases: aggregate aliases (`count(:id, as: :n)`), subquery aliases (`from(subquery, as: :alias)`), window function aliases;
- CTE names;
- DDL names: index names, foreign key names, unique and check constraint names, rename targets, and the foreign key table and column names, for `CREATE`/`DROP INDEX`, `ADD`/`DROP FOREIGN KEY`, `RENAME TABLE`/`COLUMN` and the constraints emitted by `CREATE TABLE`. `DROP INDEX` also accepts a schema qualifier.

A name with a hyphen, dot, space or non-ASCII character used to produce broken unquoted SQL. It now fails early with a message. If you need such a name, create it with a plain identifier and rename the object in the database by hand.

### 3. Quote Them (Opt-in)

With `quote_identifiers: true`, table, column and alias names in queries and DML are wrapped by the dialect's `quote_identifier`, which doubles any embedded quote character:

```crystal
MyDB = CQL::Schema.define(:my_db, adapter: CQL::Adapter::MySql, uri: uri, quote_identifiers: true) do
  # ...
end
```

| Dialect | `quote_identifier("order")` |
| --- | --- |
| PostgreSQL, SQLite, CockroachDB | `"order"` |
| MySQL | `` `order` `` |

Quoting lets reserved words work as names, for example a column called `order` or a window alias such as `rank` on MySQL. It is off by default so existing generated SQL does not change, and it covers queries and DML, not DDL. DDL names rely on validation instead.

## Raw SQL Is a Deliberate Exit

`Schema#exec(sql)` sends a string to the database as it is. It is meant for DDL and statements you write by hand. If you pass it text built from user input, nothing stops an injection. Prefer the query builder or a raw fragment with bound values, and treat every `exec` call site as one to review.

## Compile-Time Safety

Some mistakes cannot be written at all:

- **Typed `where`.** In `Model.query.where { age >= 18 }` the bare names are typed to the model's columns. An unknown column or a value of the wrong type is a compile error, and `order_by(created_at: :desc)` is checked at compile time too.
- **Relationships.** A `belongs_to` whose foreign key type differs from the target's primary key fails with a CQL-specific message rather than a deep macro trace:

  ```text
  CQL belongs_to error in Post: foreign key `:user_id` type Int32 does not match User.id! primary key type Int64.
  ```

  A missing foreign key getter and a non-literal association name are reported the same way. The check also works when the target model is defined later, as long as it is required before compilation finishes.
- **Raw fragment values.** A value that cannot be bound as a parameter (a type outside `DB::Any`) is rejected by the compiler.

## Startup Checks

Compile-time checks cannot see the database. For that, set `CQL_VALIDATE_SCHEMA_MAPPINGS=1` and each model's getters are compared with the schema column types at boot. See [Dump and Validate Your Schema](../how-to/migrations/schema-dump-and-validation.md). It is opt-in because models may legitimately omit columns or hold `nil` before an id is assigned.

## Other Places Data Is Protected

- The native PostgreSQL driver keeps bound values and passwords out of its error messages and telemetry. `CQL::Telemetry.capture_params` is off by default, so `event.params` is `nil` unless you opt in (see [Telemetry](../how-to/performance/telemetry.md)).
- The [SQL log](../how-to/performance/query-profiler.md#log-sql) leaves bound values out of its lines, including the error line of a failed statement, unless `logging.include_params` is on (then `logging.max_param_length` truncates each value). Keep it off where parameters may hold secrets. The profiler still keeps the parameters of recorded queries in memory.

## What CQL Does Not Do

- It does not sanitize the text of raw fragments or of `Schema#exec`.
- It does not check authorization. A well-formed query for the wrong tenant is still a valid query.
- It does not validate identifiers that come from your own code and schema definitions, only the places listed above where a name could plausibly come from outside.

## Further Reading

- `SECURITY_AUDIT.md` in the repository root tracks the audit of SQL generation. It records the 2025 review and a short update for 0.0.589; its findings have not been re-audited line by line.
- `spec/security/ddl_identifier_spec.cr` shows the validation rules as executable examples.
- [Filter Records](../how-to/querying/filter-records.md)
