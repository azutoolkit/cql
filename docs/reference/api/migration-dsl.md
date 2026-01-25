# Migration DSL Reference

Complete reference for the CQL Migration DSL (Domain Specific Language).

## Table Methods

### create_table

Creates a new database table.

```crystal
create_table :users do |t|
  t.column :name, String
  t.column :email, String
  t.column :age, Int32?
  t.timestamps
end
```

**Options:**
- `id: Bool` - Whether to auto-create an `id` primary key (default: true)
- `primary_key: Symbol` - Custom primary key name

### drop_table

Removes a table from the database.

```crystal
drop_table :users
```

### rename_table

Renames an existing table.

```crystal
rename_table :users, :accounts
```

## Column Methods

### column

Adds a column to a table.

```crystal
t.column :name, String                    # Required string
t.column :bio, String?                    # Nullable string
t.column :active, Bool, default: true     # With default
t.column :score, Int32, null: false       # Explicit NOT NULL
```

**Supported Types:**
| Crystal Type | SQL Type |
|--------------|----------|
| `String` | `VARCHAR(255)` / `TEXT` |
| `Int32` | `INTEGER` |
| `Int64` | `BIGINT` |
| `Float64` | `DOUBLE PRECISION` |
| `Bool` | `BOOLEAN` |
| `Time` | `TIMESTAMP` |
| `UUID` | `UUID` (PostgreSQL) |

**Options:**
- `null: Bool` - Allow NULL values
- `default: T` - Default value
- `size: Int32` - Column size (for strings)
- `unique: Bool` - Add unique constraint
- `index: Bool` - Create an index

### add_column

Adds a column to an existing table.

```crystal
add_column :users, :phone, String?
add_column :users, :verified, Bool, default: false
```

### remove_column

Removes a column from a table.

```crystal
remove_column :users, :phone
```

### rename_column

Renames a column.

```crystal
rename_column :users, :name, :full_name
```

### change_column

Modifies a column's type or constraints.

```crystal
change_column :users, :bio, String, size: 1000
```

## Index Methods

### add_index

Creates an index on one or more columns.

```crystal
add_index :users, :email                      # Single column
add_index :users, [:last_name, :first_name]   # Composite
add_index :users, :email, unique: true        # Unique index
add_index :users, :name, name: "idx_user_name" # Named index
```

**Options:**
- `unique: Bool` - Create unique index
- `name: String` - Custom index name

### remove_index

Removes an index.

```crystal
remove_index :users, :email
remove_index :users, name: "idx_user_name"
```

## Timestamps

### timestamps

Adds `created_at` and `updated_at` columns.

```crystal
create_table :posts do |t|
  t.column :title, String
  t.timestamps
end
```

Generates:
- `created_at : Time?` - Set on record creation
- `updated_at : Time?` - Set on every update

## Foreign Keys

### add_foreign_key

Creates a foreign key constraint.

```crystal
add_foreign_key :posts, :users
add_foreign_key :comments, :posts, column: :article_id
add_foreign_key :orders, :users, on_delete: :cascade
```

**Options:**
- `column: Symbol` - Custom foreign key column name
- `primary_key: Symbol` - Custom primary key column
- `on_delete: Symbol` - `:cascade`, `:nullify`, `:restrict`
- `on_update: Symbol` - `:cascade`, `:nullify`, `:restrict`

### remove_foreign_key

Removes a foreign key constraint.

```crystal
remove_foreign_key :posts, :users
```

## Raw SQL

### execute

Executes raw SQL.

```crystal
execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\""
execute "UPDATE users SET role = 'member' WHERE role IS NULL"
```

## Complete Example

```crystal
class CreateBlogSchema < CQL::Migration(1)
  def up
    create_table :users do |t|
      t.column :email, String, unique: true
      t.column :name, String
      t.column :role, String, default: "member"
      t.timestamps
    end

    create_table :posts do |t|
      t.column :user_id, Int64
      t.column :title, String
      t.column :body, String, size: 10000
      t.column :published, Bool, default: false
      t.column :published_at, Time?
      t.timestamps
    end

    add_index :posts, :user_id
    add_index :posts, :published
    add_foreign_key :posts, :users, on_delete: :cascade
  end

  def down
    drop_table :posts
    drop_table :users
  end
end
```

## See Also

- [Create a Migration](../../how-to/migrations/create-migration.md)
- [Run Migrations](../../how-to/migrations/run-migrations.md)
- [Add Columns](../../how-to/migrations/add-columns.md)
