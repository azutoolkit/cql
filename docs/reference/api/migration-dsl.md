# Migration DSL Reference

Complete reference for the CQL Migration DSL (Domain Specific Language).

## Migration Class

Migrations inherit from `CQL::Migration(VERSION)` where VERSION is an integer (typically a timestamp):

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

      index [:email], unique: true
    end

    schema.users.create!
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
column :score, Int32, default: 0, index: true
```

**Options:**
| Option | Type | Description |
|--------|------|-------------|
| `null` | Bool | Allow NULL values (default: false) |
| `default` | T | Default value |
| `unique` | Bool | Add unique constraint |
| `index` | Bool | Create index on column |
| `size` | Int32 | Column size (for VARCHAR) |
| `as` | String | SQL column alias |

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
```

### Supported Types

| Crystal Type | SQL Type |
|--------------|----------|
| `Int32` | INTEGER |
| `Int64` | BIGINT |
| `Float32` | FLOAT |
| `Float64` | DOUBLE PRECISION |
| `String` | VARCHAR / TEXT |
| `Bool` | BOOLEAN |
| `Time` | TIMESTAMP |
| `Date` | DATE |
| `JSON::Any` | JSON / JSONB |

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

Creates an index within a table definition:

```crystal
schema.table :users do
  column :email, String
  column :first_name, String
  column :last_name, String

  index [:email], unique: true            # Unique index
  index [:email]                          # Regular index
  index [:first_name, :last_name]         # Composite index
end
```

### create_index / drop_index

Manage indexes in alter operations:

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

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `columns` | Array(Symbol) | Local column(s) |
| `references` | Symbol | Target table |
| `references_columns` | Array(Symbol) | Target column(s) |
| `on_delete` | Symbol | `:cascade`, `:restrict`, `:set_null`, `:no_action` |
| `on_update` | Symbol | `:cascade`, `:restrict`, `:set_null`, `:no_action` |
| `name` | String | Optional constraint name |

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
| `add_column :name, Type, options` | Add a new column |
| `drop_column :name` | Remove a column |
| `rename_column :old, :new` | Rename a column |
| `change_column :name, NewType` | Change column type |
| `create_index :name, [:cols]` | Create an index |
| `drop_index :name` | Drop an index |
| `foreign_key [:cols], references: :table` | Add foreign key |
| `drop_foreign_key :name` | Drop foreign key |
| `rename_table :new_name` | Rename the table |
| `unique_constraint [:cols]` | Add unique constraint |
| `check_constraint "expression"` | Add check constraint |

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

      index [:email], unique: true
      index [:username], unique: true
    end
    schema.users.create!

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
      index [:user_id]
      index [:published]
    end
    schema.posts.create!
  end

  def down
    schema.posts.drop!
    schema.users.drop!
  end
end
```

## Migration Execution

```crystal
migrator = schema.migrator

# Apply migrations
migrator.up                    # Apply all pending
migrator.up(1)                 # Apply 1 migration

# Rollback migrations
migrator.down                  # Rollback all
migrator.down(1)               # Rollback 1 migration
migrator.rollback              # Alias for down(1)

# Other operations
migrator.redo                  # Rollback and reapply last
migrator.up_to(version)        # Apply up to specific version
migrator.down_to(version)      # Rollback to specific version

# Status
migrator.applied_migrations    # List applied migrations
migrator.pending_migrations    # List pending migrations
migrator.last                  # Get last applied migration
```

## See Also

- [Create a Migration](../../how-to/migrations/create-migration.md)
- [Run Migrations](../../how-to/migrations/run-migrations.md)
- [Add Columns](../../how-to/migrations/add-columns.md)
