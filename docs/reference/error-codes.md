# Error Codes

Every error class CQL defines, what raises it, and its message. CQL's own classes inherit from `CQL::Error < Exception`, except `CQL::ActiveRecord::Validations::ValidationError`, which inherits from `Exception`.

```crystal
begin
  user.save!
rescue ex : CQL::ActiveRecord::Validations::ValidationError
  ex.message                    # => "name must be present,email must match the pattern /@/"
rescue ex : CQL::RecordNotSaved # a before_* callback returned false
rescue ex : CQL::Error          # anything else CQL raises
end
```

## Core errors (`src/exceptions.cr`)

| Class | Raised by | Message and fields |
| :--- | :--- | :--- |
| **`CQL::Error`** | Raised directly for model and table misuse; see the next table | free text |
| **`CQL::RecordInvalid`** | `save!` when `save` returned `false` and the record has validation errors (a `before_validation` / `after_validation` callback halted an invalid record) | `"Record invalid: name: name must be present, email: ..."`; `validation_errors`, `error_messages`, `error_fields` |
| **`CQL::RecordNotSaved`** | `save!` when a callback halted and there are no validation errors | `"Failed to save the record"` |
| **`CQL::OptimisticLockError`** | `update!` on a model with `optimistic_locking`, and `Update#with_optimistic_lock(...).commit`, when no row matched the version | `"Record has been modified by another process"`; `model_class`, `id`, `expected_version`, `actual_version` (CQL leaves them `nil`) |
| **`CQL::DialectError`** | SQL generation for a feature the adapter lacks; see [Dialect errors](#dialect-errors) | `"SQLite does not support DISTINCT ON\n\nWorkaround:\n..."`; `dialect`, `feature`, `workaround` |
| **`CQL::SQLiteUnsupportedFeatureError`** < `DialectError` | SQLite: `back(...)` on insert, update or delete; `change_column`; `drop_foreign_key` | `"SQLite does not support ALTER COLUMN syntax"` |
| **`CQL::MySqlUnsupportedFeatureError`** < `DialectError` | MySQL: a table with `check_constraint` | `"MySQL does not support CHECK constraints (...)"` |

`CQL::Error` messages raised directly:

| Message | Raised by | Example |
| :--- | :--- | :--- |
| `Unknown column: <name>` | `Model.update!(id, attrs)` / `update!(**attrs)` with a column the table lacks; `touch` on a model without `updated_at` | `User.update!(1_i64, {:nope => "x".as(DB::Any)})` |
| `No attributes to update` | `Model.update!(id, {} of Symbol => DB::Any)` | |
| `Column <name> cannot be null` | `Model.update!(id, attrs)` setting `nil` on a `NOT NULL` column | |
| `Invalid type for column <name>: expected <T>, got <U>` | `Model.update!(id, attrs)` with a wrongly typed value | |
| `Cannot touch on a new record object` | `touch` on an unsaved record | `User.new.touch` |
| `Primary key overflow: <id> exceeds Int32 range` | `create!` on a `Model(Int32)` | |
| `Record must be persisted for optimistic locking`, `Version value missing for optimistic locking` | `update!` on an `optimistic_locking` model | |
| `Specified version column '<c>' not found in table '<t>'`, `No version column found in table '<t>' ...`, `Current version value is required for optimistic locking` | `Update#with_optimistic_lock` | |
| `Table name cannot be empty` / `cannot contain spaces` / `cannot start with a number` | `schema.table`, `CQL::Table.new` | `CQL::Table.new(:"1users", AppDB)` |

### Dialect errors

| Feature | Raises on | Error |
| :--- | :--- | :--- |
| `lock(...)` (row locking) | SQLite | `DialectError` |
| `explain(analyze: true)` | SQLite | `DialectError` |
| `distinct_on` | SQLite, MySQL | `DialectError` |
| `json_contains` | SQLite | `DialectError` |
| `within_distance` | SQLite | `DialectError` |
| `full(...)` join | MySQL | `DialectError` |
| `Insert#get` / `get!` | SQLite, MySQL | `DialectError` (`INSERT ... RETURNING`) |
| `dialect.structure_dump` | CockroachDB | `DialectError` |
| `schema.alter`, `schema.build`, a table's `create!` / `drop!` / `truncate!`, `Migrator.new`, `up`, `down`, `pending_migrations` inside an open transaction | MySQL, CockroachDB | `DialectError` (`"MySQL does not support schema changes inside a transaction"`), raised before any DDL runs |
| `back(...)` on insert, update, delete | SQLite | `SQLiteUnsupportedFeatureError` |
| `change_column`, `drop_foreign_key` in `schema.alter` | SQLite | `SQLiteUnsupportedFeatureError` |
| `foreign_key` in `schema.alter` | SQLite | `DB::Error` (`SQLite does not support adding foreign keys to an existing table ...`) |
| `check_constraint` | MySQL | `MySqlUnsupportedFeatureError` |

## Active Record errors

| Class | Raised by | Message |
| :--- | :--- | :--- |
| **`CQL::ActiveRecord::Validations::ValidationError`** < `Exception` | `validate!`, `save`, `save!` and the instance `create!` on an invalid record. Class-level `Model.create!(**attrs)` does not validate. | the error messages joined by `,` |
| **`CQL::ActiveRecord::SchemaMappingError`** | `Model.schema` when no `CQL::Schema.define` block, or more than one, declares the inferred table; with `CQL_VALIDATE_SCHEMA_MAPPINGS=1`, after the program's other top-level code has run, when the table is missing, a getter type differs from the column type, or the primary key column differs | ``CQL schema mapping error in User: schema column `users.age` type Int32 does not match model getter `age` type Int64. ...`` |
| **`CQL::ActiveRecord::Relations::BaseRelation::RelationError`** | Instance `delete!` / `force_delete!` with a `has_many ..., dependent: :restrict_with_error` that has records, or a `dependent: :destroy` child whose `delete!` returns `false`; a `DB::Error` inside an association operation | `"Cannot delete record because dependent posts exist"`, `"... could not be deleted"`, `"Database operation failed: ..."` |
| **`...::AssociationNotFound`** < `RelationError` | `first` / `last` on an empty `has_many` collection; updating a missing `has_one` / `belongs_to` target | `"No records found in collection"`, `"No profile to update"` |
| **`...::InvalidAssociation`** < `RelationError` | Reading a `belongs_to ..., optional: false` whose key is `nil` or `0`; clearing a non-optional `belongs_to` | `"Required association user foreign key is nil or 0"` |
| **`...::UnsavedRecord`** < `RelationError` | Association operations on an unsaved owner | `"Cannot operate on unsaved record"` |

## Schema and migration errors

| Class | Raised by | Message |
| :--- | :--- | :--- |
| **`CQL::Schema::Error`** | `schema.alter :name` for a table not in the schema | `"Table 'users' not found"` |
| **`CQL::Schema::InvalidURIError`** < `Schema::Error` | `Schema.define` / `Schema.new`: unparseable URI, no path, a PostgreSQL URI with no host part, a MySQL or CockroachDB URI with an empty host, an unknown scheme | `"Invalid URI format"`, `"Missing host in MySQL URI"`, `"Unsupported database type: oracle"` |
| **`CQL::Migrator::Error`** | `update_schema_file` (run by `auto_sync`, `bootstrap_schema`, `up`, `down`) when the dump fails | `"Schema update failed: <cause>"` |
| **`CQL::SchemaDump::Error`** | `SchemaDump` for an unknown adapter or a failed connection; reaches you wrapped in `Migrator::Error` | `"Failed to connect to database: ..."` |
| `KeyError` | `schema.tables[:name]` for an unknown table | `"Missing hash key: :name"` |

A failing statement inside `up` or `down` raises the driver's own exception. On SQLite and PostgreSQL the whole `up` / `down` run rolls back; on MySQL and CockroachDB each statement commits on its own. There is no `IrreversibleMigration` class: raise any exception from `down`.

## Native PostgreSQL driver errors

All inherit from `CQL::Postgres::Error < CQL::Error`. Messages never contain credentials or bound values.

| Class | Raised when |
| :--- | :--- |
| `ProtocolError` | The bytes on the wire do not follow protocol 3.0 |
| `UnrecognizedStartupReply` < `ProtocolError` | The first reply is not a protocol message (e.g. CockroachDB answering HTTP/2) |
| `UnsupportedProtocol` | The server speaks no protocol version the connection may use |
| `AuthenticationError` | The authentication exchange cannot complete |
| `TLSRefused` | `sslmode` requires TLS and the server refused it or the handshake / certificate check failed |
| `ConnectionLost` | The socket failed or the connection was already closed |
| `QueryTimeout` | No answer within the read timeout; the statement is canceled on the server |
| `PoolTimeout` / `PoolClosed` | The `AsyncEngine` pool had no free connection in time / is closed |
| `TransactionClosed` | A `TransactionScope` was used after its transaction ended |
| `WrongFiber` / `StreamClosed` | A `RowStream` was read by another fiber / after its block ended or its statement failed |
| `UnsupportedValue` | A valid PostgreSQL value Crystal cannot represent (infinite or far-out dates) |
| `ServerError` | The server sent an ErrorResponse; fields `severity`, `sqlstate`, `server_message`, `detail`, `hint`, `position`, `schema`, `table`, `column`, `constraint`, `routine`; `stale_plan?` |

`ServerError.from` picks a subclass by SQLSTATE, then by SQLSTATE class:

| Subclass | SQLSTATE | Parent |
| :--- | :--- | :--- |
| `IntegrityViolation` | class `23` | `ServerError` |
| `UniqueViolation` / `ForeignKeyViolation` / `NotNullViolation` / `CheckViolation` | `23505` / `23503` / `23502` / `23514` | `IntegrityViolation` |
| `TransactionRollback` | class `40` | `ServerError` |
| `SerializationFailure` / `DeadlockDetected` | `40001` / `40P01` | `TransactionRollback` |
| `SyntaxOrAccessError` | class `42` | `ServerError` |
| `UndefinedTable` / `UndefinedColumn` | `42P01` / `42703` | `SyntaxOrAccessError` |
| `InvalidAuthorization` | class `28` | `ServerError` |
| `QueryCanceled` | `57014` | `ServerError` |
| `LocalCancel` | a cancel the driver issued itself | `QueryCanceled` |

`message` keeps the server's wording only for value-free SQLSTATE classes (`08 0A 23 25 28 3D 53 54 55 57 58`); otherwise it is a fixed title such as `"ERROR: syntax error (SQLSTATE 42601)"`. See the [native PostgreSQL driver guide](../how-to/postgres-native/README.md).

## crystal-db and standard errors

| Class | Raised by | Message |
| :--- | :--- | :--- |
| `DB::NoResultsError` | `find!`, `find_by!` (class and `QueryBuilder`); `Insert#get!`; reading a `belongs_to ..., optional: false` whose target is gone | `"No records found with id=999"`, ``"No records found with conditions: {email: "x"}"``, `"The insert returned no row"` |
| `NilAssertionError` | `first!` with no matching row | |
| `Exception` | `QueryBuilder#last!` / `Model.last!` with no matching row | `"No records found"` |
| `DB::ConnectionRefused` | Opening a connection fails (crystal-db's first connect; the native driver maps transport and TLS failures to it) | |
| `DB::PoolTimeout`, `DB::PoolRetryAttemptsExceeded` | A saturated pool; a failed lazy reconnect | |
| `DB::Error` | `foreign_key` in `schema.alter` on SQLite | |
| `URI::Error` | `CQL.build_schema` with a `db` URL `URI.parse` rejects, such as `sqlite3://:memory:` | `"Invalid URI: bad port at character 11"` |
| Driver errors (`SQLite3::Exception`, MySQL and `pg` errors, `CQL::Postgres::ServerError`) | A statement the database rejects | |

## `ArgumentError`

There is no `ConfigurationError`, `TableNotFound` or `ColumnNotFound` class. These raise `ArgumentError`:

| Raised by | Message |
| :--- | :--- |
| `CQL.configure` validation | see [Configuration Reference](configuration.md#validation-messages) |
| `insert.into`, `update.table`, `delete.from` / `using` with an unknown table | `"Table users not found"` |
| `query.from` with an unknown table | `"Table 'users' not found in schema"` |
| An unknown column in `values` or `set` / in `where` or `select` | `"Column nope not found in users"` / `"Column 'nope' not found in any tables/aliases: users"` |
| A table, column, index, constraint or foreign key name with characters other than letters, digits and `_` | ``"Invalid foreign key name "bad name": only letters, digits and underscores are allowed, ..."`` |
| `lock(skip_locked: true, nowait: true)`; `lock(:other)` | `"Use skip_locked or nowait, not both"`, `"Unknown lock mode :other (use :update or :share)"` |
| `do_update` / `do_nothing` without `on_conflict`, or `on_conflict` without columns | `"Call on_conflict(...) before do_update"` |
| `Insert#get` without `back` | ``"Insert#get needs the columns to return; call `back` first"`` |
| `foreign_key` with mismatched column counts | `"Number of columns (...) must match number of referenced columns (...)"` |
| An index name longer than 63 characters | ``"Index name "..." is longer than 63 characters; give the index a shorter name"`` |
| `find_each` / `find_in_batches` / `insert_all` with `batch_size <= 0` | `"batch_size must be positive, got 0"` |
| `preload` after a partial `select` | `"preload is not supported after a partial select"` |
| A scope called with the wrong arguments or returning a non-query | `"Scope 'active' expects no arguments ..."` |
| `CQL::Schema.new(..., source:)` with a source bound to another adapter | `"the connection source speaks ..."` |
| Native PostgreSQL driver: unsupported `sslmode`, libpq-only options, `sslrootcert` without `verify-full`, non-numeric pool options | `"the sslcert option is not supported by this driver"` |

## Compile-time errors

The compiler stops with these messages; there is no runtime class.

| Message starts with | Cause |
| :--- | :--- |
| `CQL belongs_to error in Post:` | Name or foreign key not a symbol literal; foreign key getter missing; key type differs from the target primary key type |
| `CQL has_many error in User:` | Name or `foreign_key` not a symbol literal; unsupported `dependent` (allowed: `destroy delete_all nullify restrict_with_error`); target lacks the key; key type mismatch |
| `CQL has_one error in User:` | Unsupported `dependent` (allowed: `destroy delete nullify`) |
| `CQL many_to_many error in Post:` | Unsupported `dependent` (allowed: `destroy delete_all nullify`) |
| `CQL association error in User:` | The target model type does not exist |
| `CQL has_many error ...: foreign key ... is the primary key of ...` | Shared primary keys are not supported |
| `CQL validation error in User:` | Unsupported predicate; `validate` on an unknown attribute; missing `confirmation` target |
| `CQL order_by: User has no column` | `order_by` with an unknown column |
| `CQL: cannot compare a String column with an integer` | A typed `where { }` comparison with the wrong value type |

## Defined, not raised by CQL

Available to rescue or raise in your own code.

| Class | Message format |
| :--- | :--- |
| `CQL::RecordNotFound` | free text |
| `CQL::RecordNotFoundError.new(model_class, id)` | `"Couldn't find User with id=1"` |
| `CQL::ValidationError.new(errors : Hash(String, Array(String)))` | `"Validation failed: name is blank"` |
| `CQL::ConnectionError.new(message)` | `"Database connection error: refused"` |
| `CQL::QueryError.new(message, sql, params)` | `"Query error: bad\nSQL: SELECT 1\nParams: [1]"` |
| `CQL::TransactionError.new(message, state)` | `"Transaction error: bad (state: open)"` |
| `CQL::MigrationError.new(message, version, direction)` | `"Migration error (version: 1) during up: bad"` |
| `CQL::AttributeError.new(name, message)` | `"Attribute 'name': bad"` |
| `CQL::PersistenceError.new(operation, message, model_class)` | `"Persistence error during save for User: bad"` |
| `CQL::CallbackError.new(name, type, message)` | `"Callback before_save 'x' failed: bad"` |
| `CQL::Schema::VersionConflictError`, `CQL::Schema::ConnectionError` | free text |

## See Also

- [Fix Connection Errors](../how-to/troubleshooting/connection-errors.md)
- [Fix Migration Errors](../how-to/troubleshooting/migration-errors.md)
- [Fix Schema Mapping Errors](../how-to/troubleshooting/schema-mapping-errors.md)
- [Fix Validation Errors](../how-to/troubleshooting/validation-errors.md)
- [Database Support](database-support.md)
- [Configuration Reference](configuration.md)
