# Safety Guardrails

CQL makes the unsafe version of a query hard to write. This page explains each guardrail and where the responsibility passes back to you; for the steps, see [Use Raw SQL Fragments Safely](../how-to/advanced-sql/raw-fragments.md) and [Write Typed Queries](../how-to/querying/typed-where-dsl.md).

| Layer | Protects against | Where it stops |
| :--- | :--- | :--- |
| Values are bound as parameters | A value rewriting the statement | The text of a raw fragment or of `Schema#exec` |
| Identifiers are resolved, validated or quoted | A name smuggling SQL into the statement's structure | Names your own code and schema define |
| Typed queries and associations are checked by the compiler | Unknown columns, mismatched types and keys | The live database |
| An opt-in mapping check | Models that drifted from the schema | Runs only when switched on, after other top-level code |

## Values Never Become SQL Text

A value passed to `where`, `insert`, `update`, `delete` or the typed DSL never becomes part of the SQL text. The statement holds a placeholder and the value travels separately:

```crystal
sql, values = AppDB.query.from(:users).where(name: "admin' OR '1'='1").to_sql
sql    # => "SELECT users.id, ... FROM users WHERE users.name = ?"
values # => ["admin' OR '1'='1"]
```

The hostile string stays a string, which is why `to_sql` returns SQL and parameters as a pair.

Raw fragments follow the same rule. `where("lower(email) = ?", email)`, `where("age > :age", age: 18)` and `raw(...)` inside a `CQL::Query` `where { }` block (`CQL.raw(...)` in a model's typed block) bind every value. Arrays expand to `IN (?, ?)` lists, and placeholders inside quoted text and comments are left alone. A mistake raises `ArgumentError` instead of dropping a value: a wrong number of values, named values for a `?` fragment, an empty array, or `?` and `:name` mixed in one fragment.

**Your side of the contract:** the text of a fragment must be a literal in your source. Binding protects the values, not the fragment.

```crystal
# ✅ The value is bound
User.query.where("lower(email) = ?", params["email"].downcase)

# ❌ User input becomes SQL
User.query.where("lower(email) = '#{params["email"]}'")
```

## Identifiers Cannot Be Bound

Table, column, alias and constraint names are part of the statement's structure, so a driver cannot take them as parameters. CQL handles them in three ways.

### Resolved Against the Schema

Column names given to `where(attr: value)`, `order`, `where_like` and similar methods are looked up in the query's tables. An unknown name raises `ArgumentError` ("Column 'bogus' not found in any tables/aliases: users") before any SQL exists, so `order(params["sort"])` with a bogus value fails instead of injecting. You still handle the error and keep an allow list: a real column the user should not sort by is still a real column.

### Validated With `CQL::Identifier`

Names that are not schema columns, such as aliases and constraint names, must look like a plain identifier:

```crystal
CQL::Identifier::PATTERN                      # => /\A[A-Za-z_][A-Za-z0-9_]*\z/
CQL::Identifier.valid?("n")                   # => true
CQL::Identifier.valid?("n; DROP TABLE users") # => false
CQL::Identifier.validate!("total", "alias")   # => "total"
CQL::Identifier.validate!("a b", "alias")
# ArgumentError: Invalid alias "a b": only letters, digits and underscores are allowed, and it must not start with a digit
```

`validate_qualified!` also accepts one `schema.name` qualifier. CQL validates:

- aliases: aggregates (`count(:id, as: :n)`), subqueries (`from(subquery, as: :recent)`) and window functions;
- CTE names;
- DDL names: index, foreign key, unique and check constraint names, rename targets, and the table and column names a foreign key references, in `CREATE`/`DROP INDEX`, `ADD`/`DROP FOREIGN KEY`, `RENAME TABLE`/`COLUMN` and the constraints of `CREATE TABLE`. `DROP INDEX` also accepts a schema qualifier.

A name with a hyphen, dot, space or non-ASCII character fails early with a message instead of producing broken SQL; create such an object with a plain name and rename it in the database by hand.

### Quoted, When You Opt In

With `quote_identifiers: true`, table, column and alias names in queries and DML are wrapped by the dialect's `quote_identifier`, which doubles any embedded quote character:

```crystal
AppDB = CQL::Schema.define(:app_db, adapter: CQL::Adapter::MySql, uri: ENV["DATABASE_URL"], quote_identifiers: true) do
  table :orders do
    primary :id, Int64
    column :order, Int32
  end
end

AppDB.query.from(:orders).select(:order).where(order: 1).to_sql
# => {"SELECT `orders`.`order` FROM `orders` WHERE `orders`.`order` = ?", [1]}
```

| Dialect | `quote_identifier("order")` |
| :--- | :--- |
| PostgreSQL, SQLite, CockroachDB | `"order"` |
| MySQL | `` `order` `` |

Quoting lets reserved words such as `order` work as names. It is off by default so existing SQL does not change, and it covers queries and DML, not DDL, whose names rely on validation.

## Raw SQL Is a Deliberate Exit

`Schema#exec(sql)` sends a string to the database as it is, for DDL and statements you write by hand. If its text is built from user input, nothing stops an injection, so prefer the query builder or a fragment with bound values, and review every `exec` call site.

## The Compiler Catches Shape Mistakes

Some mistakes cannot be compiled at all:

| Code | Compile error |
| :--- | :--- |
| `User.query.where { agee > 1 }` | `undefined local variable or method 'agee' for User::Columns` |
| `User.query.where { age > "old" }` | ``CQL: cannot compare a Int32 column with String using `>`; use a Int32 value or another Int32 column`` |
| `User.query.order_by(nope: :asc)` | ``CQL order_by: User has no column `nope`. Columns: id, name, ...`` |
| `belongs_to :user, User, :user_id` with `user_id : Int32?` and `User` keyed by `Int64` | ``CQL belongs_to error in Post: foreign key `:user_id` type Int32 does not match User.id! primary key type Int64. Change `:user_id` to Int64 or update the target model primary key type.`` |
| `where("name = ?", :not_bindable)` | `CQL: Symbol cannot be bound as a SQL parameter (use a DB::Any type: String, Int, Float, Bool, Time, Bytes, nil)` |

A missing foreign key getter and a non-literal association name are reported the same way, even when the target model is defined later in the program.

## An Opt-In Check Compares Models With the Schema

The compiler does not compare a model with its schema definition. With `CQL_VALIDATE_SCHEMA_MAPPINGS=1`, each model's getter types are compared with its schema's column types, and a mismatch raises a `CQL schema mapping error`. The check is emitted at the end of the program, after all other top-level code, so an application that starts a blocking server never reaches it; run it from a program that only requires the models, such as a CI step. It is opt-in because models may legitimately omit columns or hold `nil` before an id is assigned. See [Dump and Validate Your Schema](../how-to/migrations/schema-dump-and-validation.md).

## Bound Values Stay Out of Logs and Errors

- The native PostgreSQL driver keeps passwords and bound values out of the messages it builds; a server error shows the server's own wording only for error classes known to be value-free.
- `CQL::Telemetry.capture_params` is off by default, so `event.params` is `nil` unless you opt in. See [Telemetry](../how-to/observability/telemetry.md).
- The [SQL log](../how-to/observability/query-profiler.md#log-sql) leaves bound values out of its lines unless `logging.include_params` is on (then `logging.max_param_length` truncates each value). The error line of a failed statement also drops everything from the first to the last quote of the driver's message; unquoted text, such as an encoding error or `RAISE EXCEPTION` output, is kept.
- The profiler keeps the parameters of recorded queries in memory, but the metrics JSON (`CQL::Performance.metrics.to_json`) includes them only when `logging.include_params` is on.

## What CQL Does Not Do

- It does not sanitize the text of raw fragments or of `Schema#exec`.
- It does not check authorization. A well-formed query for the wrong tenant is still a valid query.
- It does not validate identifiers from your own code and schema definitions, only the places above where a name could come from outside.

## Further Reading

- `SECURITY_AUDIT.md` in the repository root records the 2025 audit of SQL generation and a short update for 0.0.589; its findings have not been re-audited line by line since.
- `spec/security/ddl_identifier_spec.cr` and `spec/security/sql_injection_spec.cr` show the rules as executable examples.
- [Filter with Where Clauses](../how-to/querying/filter-records.md)
