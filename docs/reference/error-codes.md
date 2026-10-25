# Error Codes

Common CQL errors and their meanings. Everything CQL defines inherits from `CQL::Error`, except `CQL::ActiveRecord::Validations::ValidationError`, which inherits from `Exception`. Classes marked "defined, not raised by CQL" exist in `src/exceptions.cr` for applications to raise or rescue but are not raised by the library itself.

## Validation Errors

### ValidationError

Raised when model validations fail: by `validate!`, and by `save`, `save!` and `create!`, which validate first.

```crystal
begin
  user.validate!
rescue CQL::ActiveRecord::Validations::ValidationError => ex
  puts ex.message  # Contains validation error messages
end
```

**Common causes:**
- Required field is empty
- Value doesn't match format
- Value outside allowed range

**Solution:** Check `model.errors` for specific field errors (each has `field` and `message`). Use `valid?` to check without raising.

## Locking Errors

### OptimisticLockError

Raised when a concurrent update is detected.

```crystal
begin
  user.update!
rescue CQL::OptimisticLockError
  user.reload!  # Get latest version
  # Re-apply changes and retry
end
```

**Common causes:**
- Another process updated the record
- Version column mismatch

**Solution:** Reload the record and retry the operation.

## Record Errors

### DB::NoResultsError

Raised by `find!` and `find_by!` when no row matches. `find` and `find_by` return `nil` instead.

```crystal
begin
  user = User.find!(999)
rescue DB::NoResultsError
  puts "User not found"
end
```

**Solution:** Use `find` (returns nil) instead, or handle the exception.

`CQL::RecordNotFound` and `CQL::RecordNotFoundError` (with `model_class` and `id`) are defined but not raised by CQL.

### RecordInvalid and RecordNotSaved

`save!` raises these when `save` returns `false`. `CQL::RecordInvalid` (with `error_messages` and `error_fields`) is raised if the record has validation errors; `CQL::RecordNotSaved` ("Failed to save the record") otherwise, typically because a `before_*` callback halted the save.

```crystal
begin
  user.save!
rescue ex : CQL::RecordNotSaved
  puts "Failed: #{ex.message}"
end
```

Validation failures themselves raise `Validations::ValidationError` before `save` can return `false`, so `RecordInvalid` is rarely seen in practice.

**Solution:** Check `valid?` before saving, or use the non-bang `save`, which returns `false` when a `before_*` callback halts.

## Database Errors

### DB::ConnectionRefused

Raised by crystal-db when a connection cannot be opened (the native PostgreSQL driver maps transport and TLS failures to it).

**Common causes:**
- Database server not running
- Wrong connection string
- Network issues

**Solution:** Verify connection settings and database availability. See [Fix Connection Errors](../how-to/troubleshooting/connection-errors.md).

### CQL::Schema::InvalidURIError

Raised by `Schema.define` / `Schema.new` for a URI that is malformed, has no host (PostgreSQL, MySQL, CockroachDB) or an unsupported scheme.

### CQL::Postgres errors

The native PostgreSQL/CockroachDB driver raises subclasses of `CQL::Postgres::Error`:

| Error | Raised when |
|-------|-------------|
| `AuthenticationError` | Authentication could not complete |
| `TLSRefused` | The server refused or failed TLS that `sslmode` requires |
| `ConnectionLost` | The socket failed or was closed |
| `PoolTimeout` / `PoolClosed` | The async engine's pool had no free connection in time / was closed |
| `QueryTimeout` | A statement exceeded its time limit |
| `TransactionClosed` | A transaction scope was used after its transaction ended |
| `ServerError` | The server sent an ErrorResponse; has `sqlstate`, `detail`, `constraint`, ... |

`ServerError` has subclasses chosen by SQLSTATE: `UniqueViolation` (23505), `ForeignKeyViolation` (23503), `NotNullViolation` (23502), `CheckViolation` (23514), `SerializationFailure` (40001), `DeadlockDetected` (40P01), `UndefinedTable` (42P01), `UndefinedColumn` (42703) and `QueryCanceled` (57014), with the parents `IntegrityViolation`, `TransactionRollback`, `SyntaxOrAccessError` and `InvalidAuthorization` for the rest of their classes. See the [native PostgreSQL driver guide](../how-to/postgres-native/README.md).

### Dialect errors

`CQL::DialectError` (with `dialect`, `feature` and an optional `workaround`) is raised when the adapter cannot express a feature. `CQL::SQLiteUnsupportedFeatureError` and `CQL::MySqlUnsupportedFeatureError` are its subclasses, for example `change_column` or adding a foreign key to an existing SQLite table.

### QueryError, TransactionError, PersistenceError, AttributeError, CallbackError, ConnectionError

Defined, not raised by CQL. `CQL::QueryError` carries `sql` and `params`, `CQL::TransactionError` a `transaction_state`, `CQL::ConnectionError` prefixes its message with "Database connection error:". Query failures from the database surface as the driver's own exceptions (`DB::Error` subclasses, or `CQL::Postgres::ServerError`).

## Migration Errors

### CQL::Migrator::Error

Raised when the schema file cannot be written ("Schema update failed: ...") with `auto_sync` on.

### CQL::Schema::Error

Raised by `schema.alter :table` when the table is not registered in the schema ("Table 'users' not found").

### Database errors during a migration

A failing statement in `up` or `down` raises the driver's exception. Earlier migrations of the run stay applied, because migration statements run outside the migrator's transaction.

**Common causes:**
- Table already exists (only for tables created outside CQL; `create!` uses `IF NOT EXISTS`)
- Column already exists
- Foreign key constraint violation
- Invalid SQL syntax

`CQL::MigrationError` (with `migration_version` and `direction`) is defined, not raised by CQL.

### Irreversible migrations

There is no `IrreversibleMigration` class. Raise any exception from `down`:

```crystal
def down
  raise "Cannot rollback: data would be lost"
end
```

**Solution:** Handle the rollback manually or skip it.

## Schema Errors

### SchemaMappingError

Raised when strict schema mapping validation is enabled and a model getter type does not match the schema column type, or the model's primary key column differs from the table's declared primary key (``table `labels` declares primary key `label_no`, but the model maps `id` to `id` ``).

Enable strict validation with:

```bash
CQL_VALIDATE_SCHEMA_MAPPINGS=1 crystal run src/app.cr
```

**Common causes:**
- Model property type differs from the column type in `CQL::Schema.define`
- `db_context` points at the wrong table
- A schema was changed but the model was not updated
- The table's `primary` column is not `id` and the model lacks `db_context ..., primary_key: :column`

**Solution:** Update the model property type or the schema column type so they agree.

### Unknown tables and columns

There are no `TableNotFound` or `ColumnNotFound` classes. A table or column missing from the database surfaces as the driver's error (`CQL::Postgres::UndefinedTable` / `UndefinedColumn` on the native driver). A table missing from the *schema definition* raises `KeyError` from `schema.tables[...]`, or `CQL::Schema::Error` from `schema.alter`.

**Solution:** Ensure migrations have run, check spelling, and keep the schema definition in sync.

## Compile-Time Association Errors

### CQL belongs_to error

Raised at compile time when a `belongs_to` declaration is malformed or type-unsafe.

**Common causes:**
- Association name is not a symbol literal
- Foreign key is not a symbol literal
- The model does not define the foreign key getter/property
- Foreign key type does not match the target model primary key type

**Solution:** Add a typed foreign key property and make it match the target model primary key type.

### CQL has_many error

Raised at compile time when a `has_many` declaration is malformed or type-unsafe.

**Common causes:**
- Association name is not a symbol literal
- `foreign_key` is not a symbol literal
- `dependent` option is unsupported
- Target model does not define the foreign key getter/property
- Target foreign key type does not match the parent model primary key type

**Solution:** Add the target foreign key property and make it match the parent model primary key type.

### CQL has_one error / CQL many_to_many error

Raised at compile time when the `dependent` option is unsupported: `has_one` accepts `:destroy`, `:delete` and
`:nullify`; `many_to_many` accepts `:destroy`, `:delete_all` and `:nullify`.

**Solution:** Use one of the listed values, or leave `dependent` out.

### RelationError when deleting

`delete!` (and `force_delete!`) raise `CQL::ActiveRecord::Relations::BaseRelation::RelationError` and delete nothing:

- "Cannot delete record because dependent posts exist" when a `has_many ..., dependent: :restrict_with_error`
  association still has records.
- "Cannot delete record because dependent posts could not be deleted" when a `has_many` or `has_one` with
  `dependent: :destroy` calls a child's `delete!` and it returns false: a `before_destroy` callback halted it, or the
  child's row was already gone.

**Solution:** Delete or reassign the associated records first, fix the halting callback, or choose another `dependent`
strategy.

## Configuration Errors

There is no `ConfigurationError` class. Invalid settings raise `ArgumentError`:

- `CQL.configure` validates when the block ends: empty `db`, `schema_dir` or `schema_file`, a `schema_file` not ending in `.cr`, a `timezone` other than `:utc`/`:local`, a non-positive pool size, an invalid `ssl.mode`, or an unsupported SQLite `journal_mode`/`synchronous` value
- `config.adapter` raises `ArgumentError` for a URL that is not `postgres://`, `postgresql://`, `cockroachdb://`, `mysql://` or `sqlite3://`
- The native PostgreSQL driver raises `ArgumentError` for an unsupported `sslmode`, unsupported libpq options, or non-numeric pool options

**Solution:** Review the message; it names the offending setting.

## Debugging Tips

### Enable Logging

```crystal
Log.setup do |c|
  c.bind("cql.*", :debug, Log::IOBackend.new)
end

# Or let CQL print formatted SQL (`config.sql_logging = true` takes effect when CQL.build_schema runs)
CQL::Performance.enable_sql_logging
```

### Print Error Details

```crystal
begin
  # operation
rescue ex
  puts "Error type: #{ex.class}"
  puts "Message: #{ex.message}"
  puts "Backtrace: #{ex.backtrace.first(5).join("\n")}"
end
```

### Check Validation Errors

```crystal
unless model.valid?
  model.errors.each do |error|
    puts "#{error.field}: #{error.message}"
  end
end
```
