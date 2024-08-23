# class Cql::Migrator

`Reference` < `Object`

The `Migrator` class is used to manage migrations and provides methods to apply, rollback, and redo migrations. The `Migrator` class also provides methods to list applied and pending migrations. **Example** Creating a new migrator

```crystal
schema = Cql::Schema.define(:northwind, "sqlite3://db.sqlite3") do |s|
  table :schema_migrations do
    primary :id, Int32
    column :name, String
    column :version, Int64, index: true, unique: true
    timestamps
  end
end
migrator = Cql::Migrator.new(schema)
```

**Example** Applying migrations

```crystal
migrator.up
```

## Constants

### Log

```crystal
::Log.for(self)
```

## Constructors

### def new`(schema : Schema)`

## Class Methods

### def migrations

### def migrations=`(migrations : Array(Migration.class))`

## Instance Methods

### def applied_migrations

Returns the applied migrations.

- **@return** \[Array(MigrationRecord)] **Example** Listing applied migrations

```crystal
migrator.applied_migrations
```

### def down`(steps : Int32 = Migrator.migrations.size)`

Rolls back the last migration.

- **@param** steps \[Int32] the number of migrations to roll back (default: 1) **Example** Rolling back migrations

```crystal
migrator.down
```

### def down_to`(version : Int64)`

Rolls back to a specific migration version.

- **@param** version \[Int64] the version to roll back to **Example** Rolling back to a specific version

```crystal
migrator.down_to(1_i64)
```

### def last

Returns the last migration. **Example** Listing the last migration

```crystal
migrator.last
```

@return \[Migration.class | Nil]

### def pending_migrations

Returns the pending migrations.

- **@return** \[Array(MigrationRecord)] **Example** Listing pending migrations

```crystal
migrator.pending_migrations
```

### def print_applied_migrations

Prints the applied migrations. **Example** Listing applied migrations

```crystal
migrator.print_applied_migrations
```

### def print_pending_migrations

Prints the pending migrations. **Example** Listing pending migrations

```crystal
migrator.print_pending_migrations
```

### def print_rolled_back_migrations`(m : Array(Migration.class))`

Prints the rolled back migrations.

- **@param** m \[Array(Migration.class)] the migrations to print
- **@return** \[Nil] **Example** Listing rolled back migrations

```crystal
migrator.print_rolled_back_migrations
```

### def redo

Redoes the last migration. **Example** Redoing migrations

```crystal
migrator.redo
```

### def repo

### def rollback`(steps : Int32 = 1)`

Rolls back the last migration.

- **@param** steps \[Int32] the number of migrations to roll back (default: 1) **Example** Rolling back migrations

```crystal
migrator.rollback
```

### def schema

### def up`(steps : Int32 = Migrator.migrations.size)`

Applies the pending migrations.

- **@param** steps \[Int32] the number of migrations to apply (default: all) **Example** Applying migrations

```crystal
migrator.up
```

### def up_to`(version : Int64)`

Applies migrations up to a specific version.

- **@param** version \[Int64] the version to apply up to **Example** Applying to a specific version

```crystal
migrator.up_to(1_i64)
```
