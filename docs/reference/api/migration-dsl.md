# Migration DSL Reference

Complete reference for the CQL Migration DSL (Domain Specific Language).

## Migration Class

Migrations inherit from `CQL::Migration(VERSION)` where VERSION is an integer (typically a timestamp, stored as `Int64`). The class registers itself with `CQL::Migrator` when it is defined, and the migrator exposes the database as `schema`:

```crystal
class CreateUsers < CQL::Migration(20250125001401)
  def up
    # Apply changes
  end

  def down
    # Rollback changes
  end
end
```

## Creating Tables

### schema.table

Defines a new table structure:

```crystal
class CreateUsers < CQL::Migration(1)
  def up
    schema.table :users do
      primary :id, Int64, auto_increment: true
      column :name, String, null: false
      column :email, String, null: false
      column :active, Bool, default: true
      timestamps
    end

    schema.users.create!

    schema.alter :users do
      create_index :idx_users_email, [:email], unique: true
    end
  end

  def down
    schema.users.drop!
  end
end
```

**Key methods:**
- `schema.table :name do ... end` - Define table structure
- `schema.table_name.create!` - Execute CREATE TABLE
- `schema.table_name.drop!` - Execute DROP TABLE

## Column Methods

### primary

Defines the primary key column:

```crystal
primary :id, Int64                        # Default auto_increment: true
primary :id, Int32, auto_increment: true
primary :uuid, String, auto_increment: false
```

**Parameters:**
- `name` - Column name (Symbol)
- `type` - Crystal type (Int32, Int64, String)
- `auto_increment` - Enable auto-increment (default: true)

### column

Adds a column to the table:

```crystal
column :name, String                      # Required string
column :bio, String, null: true           # Nullable
column :active, Bool, default: true       # With default
column :email, String, null: false, unique: true
column :score, Int32, default: 0
```

**Options:**
| Option | Type | Description |
|--------|------|-------------|
| `null` | Bool | Allow NULL values (default: false) |
| `default` | T | Default value |
| `unique` | Bool | Add unique constraint |
| `index` | Bool | Index the column; `create!` creates it after the table (see [index](#index)) |
| `size` | Int32 | Length of a `String` column: `VARCHAR(size)` on PostgreSQL, CockroachDB and MySQL. SQLite's `TEXT` and other types ignore it |
| `as` | String | Alias used when selecting the column |

### Type-Specific Column Methods

CQL provides helper methods for common column types:

```crystal
# String types
varchar :name, size: 255
text :description

# Numeric types
integer :age, null: false, default: 18
bigint :balance, default: 0
float :price, default: 0.0
double :rating
real :measurement

# Other types
boolean :active, default: true
timestamp :created_at
date :birthday
json :metadata
blob :avatar
interval :duration
lock_version                              # Int32 `version` column for optimistic locking
```

### Supported Types

| Crystal Type | PostgreSQL | CockroachDB | MySQL | SQLite |
|--------------|-----------|-------------|-------|--------|
| `Int32` | INTEGER | INT4 | INT | INTEGER |
| `Int64` | BIGINT | BIGINT | BIGINT | BIGINT |
| `Float32` | REAL | REAL | FLOAT | FLOAT |
| `Float64` | DOUBLE PRECISION | DOUBLE PRECISION | DOUBLE | DOUBLE |
| `String` | VARCHAR | VARCHAR | VARCHAR(255) | TEXT |
| `Bool` | BOOLEAN | BOOLEAN | TINYINT(1) | BOOLEAN |
| `Time` (`timestamp`, `timestamps`) | TIMESTAMP | TIMESTAMP | DATETIME(3) | TIMESTAMP |
| `Time` (`date`) | DATE | DATE | DATE | DATE |
| `Time::Span` | INTERVAL | INTERVAL | TIME | INTERVAL |
| `Slice(UInt8)` | BYTEA | BYTEA | BLOB | BLOB |
| `JSON::Any` | JSONB | JSONB | JSON | TEXT |

`UInt32` and `UInt64` are also mapped. See `CQL::DB_TYPE_MAPPING`. A `String` column declared with `size:` (or `varchar ..., size:`) is `VARCHAR(size)` on PostgreSQL, CockroachDB and MySQL; without it, `varchar` is the plain `String` type above. `change_column` takes no size, so it declares the plain type.

### timestamps

Adds `created_at` and `updated_at` columns:

```crystal
schema.table :posts do
  primary :id, Int64
  column :title, String
  timestamps
end
```

Both columns are timestamps with current timestamp as default.

## Index Methods

### index

`index [:cols], unique: bool, name: "idx_name"` inside a table block declares an index. `create!` and `schema.build` create it after the table with `CREATE INDEX IF NOT EXISTS` (plain `CREATE INDEX` on MySQL, which has no `IF NOT EXISTS` for indexes). `unique` defaults to `false`; without `name`, the index is named `idx_<table>_<columns>`.

```crystal
schema.table :users do
  column :name, String
  column :email, String
  index [:name, :email], unique: true # idx_users_name_email
end
```

### create_index / drop_index

Create and drop indexes in alter operations (the name comes first):

```crystal
schema.alter :users do
  create_index :email_idx, [:email], unique: true
  drop_index :email_idx
end
```

## Foreign Key Methods

### foreign_key

Creates a foreign key constraint:

```crystal
schema.table :posts do
  primary :id, Int64
  column :user_id, Int64, null: false
  column :category_id, Int64, null: true

  foreign_key [:user_id], references: :users, references_columns: [:id]
  foreign_key [:category_id], references: :categories, references_columns: [:id]
end
```

A single-column overload takes `column :user_id` instead of an array. `references_columns` may be a Symbol or an Array and defaults to the referenced table's primary key (`:id`).

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `columns` | Array(Symbol) | Local column(s) |
| `references` | Symbol | Target table |
| `references_columns` | Array(Symbol) | Target column(s) |
| `on_delete` | Symbol | `:cascade`, `:restrict`, `:set_null`, `:no_action` |
| `on_update` | Symbol | `:cascade`, `:restrict`, `:set_null`, `:no_action` |
| `name` | String (`Symbol` in `schema.alter`) | Optional constraint name; defaults to `fk_<table>_<columns>` |

### Composite Foreign Keys

```crystal
foreign_key [:order_id, :product_id],
  references: :order_items,
  references_columns: [:o_id, :p_id]
```

## Altering Tables

### schema.alter

Modifies an existing table:

```crystal
class AddPhoneToUsers < CQL::Migration(2)
  def up
    schema.alter :users do
      add_column :phone, String, null: true
      add_column :age, Int32, null: true, default: 18
    end
  end

  def down
    schema.alter :users do
      drop_column :phone
      drop_column :age
    end
  end
end
```

### Alter Operations

| Method | Description |
|--------|-------------|
| `add_column :name, Type, options` | Add a new column; takes the `column` options (`null:` defaults to `true` here) and emits its `DEFAULT`. `index: true` also creates `idx_<table>_<column>` |
| `drop_column :name` | Remove a column |
| `rename_column :old, :new` | Rename a column |
| `change_column :name, NewType` | Change column type |
| `create_index :name, [:cols]` | Create an index |
| `drop_index :name` | Drop an index |
| `foreign_key [:cols], references: :table` | Add foreign key |
| `drop_foreign_key :name` | Drop foreign key |
| `rename_table :new_name` | Rename the table |

`unique_constraint [:cols]` and `check_constraint "expression"` exist on tables (inside `schema.table`) but not in `schema.alter`.

`schema.alter` raises `CQL::Schema::Error` if the table is not registered in the schema. SQLite does not support `change_column`, adding a foreign key or dropping a foreign key to an existing table; these raise `CQL::SQLiteUnsupportedFeatureError` with a workaround message. `drop_column` on a column the table does not know only logs an error.

### Alter Examples

```crystal
schema.alter :users do
  # Columns
  add_column :phone, String, null: true
  drop_column :legacy_field
  rename_column :email, :user_email
  change_column :age, String

  # Indexes
  create_index :phone_idx, [:phone]
  drop_index :old_idx

  # Foreign keys
  foreign_key [:department_id], references: :departments, on_delete: :cascade
  drop_foreign_key :fk_old_reference
end
```

## Complete Example

```crystal
class CreateBlogSchema < CQL::Migration(1)
  def up
    # Create users table
    schema.table :users do
      primary :id, Int64, auto_increment: true
      column :email, String, null: false
      column :username, String, null: false
      column :role, String, default: "member"
      timestamps
    end
    schema.users.create!

    schema.alter :users do
      create_index :idx_users_email, [:email], unique: true
      create_index :idx_users_username, [:username], unique: true
    end

    # Create posts table
    schema.table :posts do
      primary :id, Int64, auto_increment: true
      column :user_id, Int64, null: false
      column :title, String, null: false
      column :body, String, null: false
      column :published, Bool, default: false
      column :views_count, Int64, default: 0
      timestamps

      foreign_key [:user_id], references: :users, references_columns: [:id]
    end
    schema.posts.create!

    schema.alter :posts do
      create_index :idx_posts_user_id, [:user_id]
      create_index :idx_posts_published, [:published]
    end
  end

  def down
    schema.posts.drop!
    schema.users.drop!
  end
end
```

## Migration Execution

```crystal
migrator = schema.migrator                                      # auto_sync: true by default; writes the schema file after up/down
migrator = schema.migrator(CQL::MigratorConfig.new(auto_sync: false))

# Apply migrations (version order; one transaction on SQLite and PostgreSQL)
migrator.up                    # Apply all pending
migrator.up(1)                 # Apply the oldest pending migration

# Rollback migrations (newest applied first; one transaction on SQLite and PostgreSQL)
migrator.down                  # Rollback ALL applied migrations
migrator.down(1)               # Rollback the newest applied migration
migrator.rollback              # Alias for down(1)

# Other operations
migrator.redo                  # rollback (1) then up
migrator.up_to(version)        # Apply pending migrations up to and including version (Int64)
migrator.down_to(version)      # Rollback applied migrations newer than version; version stays applied

# Status
migrator.applied_migrations    # Array(CQL::MigrationRecord): id, name, version
migrator.pending_migrations    # Array of migration classes
migrator.last                  # Last applied migration class, or nil
migrator.print_applied_migrations
migrator.print_pending_migrations

# Schema file
migrator.update_schema_file
migrator.verify_schema_consistency   # Bool
migrator.bootstrap_schema
```

`up_to` and `down_to` raise `CQL::Migrator::Error` when no registered migration has `version`. Steps count only the migrations that can run: `up(n)` counts pending migrations and `down(n)` counts applied ones.

`CQL::MigratorConfig` takes `schema_file_path`, `schema_name`, `schema_symbol`, `migration_table_name` (default `:cql_schema_migrations`) and `auto_sync`. With `auto_sync` on, the schema file is rewritten from the database after `up`/`down`; creating the migrator does not write it.

## See Also

- [Create a Migration](../../how-to/migrations/create-migration.md)
- [Run Migrations](../../how-to/migrations/run-migrations.md)
- [Add Columns](../../how-to/migrations/add-columns.md)
