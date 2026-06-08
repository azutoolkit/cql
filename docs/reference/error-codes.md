# Error Codes

Common CQL errors and their meanings.

## Validation Errors

### ValidationError

Raised when model validations fail.

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

**Solution:** Check `model.errors` for specific field errors.

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

### RecordNotFound

Raised when `find!` cannot locate a record.

```crystal
begin
  user = User.find!(999)
rescue CQL::RecordNotFound
  puts "User not found"
end
```

**Solution:** Use `find` (returns nil) instead, or handle the exception.

### RecordInvalid

Raised when `save!` or `create!` fails validation.

```crystal
begin
  User.create!(name: "", email: "")
rescue CQL::RecordInvalid => ex
  puts "Failed: #{ex.message}"
end
```

**Solution:** Check validations before saving, or use non-bang methods.

## Database Errors

### ConnectionError

Raised when database connection fails.

**Common causes:**
- Database server not running
- Wrong connection string
- Network issues
- Authentication failure

**Solution:** Verify connection settings and database availability.

### QueryError

Raised when a SQL query fails.

**Common causes:**
- Syntax error in raw SQL
- Reference to non-existent column
- Type mismatch

**Solution:** Check the SQL being generated and table structure.

## Migration Errors

### MigrationError

Raised when a migration fails.

**Common causes:**
- Table already exists
- Column already exists
- Foreign key constraint violation
- Invalid SQL syntax

**Solution:** Check migration status and database state.

### IrreversibleMigration

Raised when attempting to rollback an irreversible migration.

```crystal
def down
  raise "Cannot rollback: data would be lost"
end
```

**Solution:** Manually handle the rollback or skip it.

## Schema Errors

### SchemaMappingError

Raised when strict schema mapping validation is enabled and a model getter type does not match the schema column type.

Enable strict validation with:

```bash
CQL_VALIDATE_SCHEMA_MAPPINGS=1 crystal run src/app.cr
```

**Common causes:**
- Model property type differs from the column type in `CQL::Schema.define`
- `db_context` points at the wrong table
- A schema was changed but the model was not updated

**Solution:** Update the model property type or the schema column type so they agree.

### TableNotFound

Raised when referencing a table that doesn't exist.

**Solution:** Ensure migrations have run and table exists.

### ColumnNotFound

Raised when referencing a column that doesn't exist.

**Solution:** Check column name spelling and run migrations.

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

## Configuration Errors

### ConfigurationError

Raised for invalid configuration settings.

**Common causes:**
- Missing required configuration
- Invalid adapter name
- Malformed connection string

**Solution:** Review configuration settings.

## Debugging Tips

### Enable Logging

```crystal
Log.setup do |c|
  c.bind("cql.*", :debug, Log::IOBackend.new)
end
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
