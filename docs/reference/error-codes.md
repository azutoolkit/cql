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

### TableNotFound

Raised when referencing a table that doesn't exist.

**Solution:** Ensure migrations have run and table exists.

### ColumnNotFound

Raised when referencing a column that doesn't exist.

**Solution:** Check column name spelling and run migrations.

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
