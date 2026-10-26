# Add Columns

Add columns to an existing table with `schema.alter`, and give them defaults with a backfill or raw DDL.

## Add Nullable Columns

```crystal
class AddProfileFieldsToUsers < CQL::Migration(5)
  def up
    schema.alter :users do
      add_column :avatar_url, String   # ALTER TABLE users ADD COLUMN avatar_url TEXT
      add_column :bio, String
    end
  end

  def down
    schema.alter :users do
      drop_column :avatar_url
      drop_column :bio
    end
  end
end
```

`add_column` makes nullable columns (`null: true`) unless you pass `null: false`, unlike `column` in a `schema.table`
block.

| Option | Effect on the `ADD COLUMN` statement |
| :--- | :--- |
| `null: false` | adds `NOT NULL` |
| `default:` | none: the default is never written |
| `unique: true` | adds `UNIQUE`; SQLite rejects it ("Cannot add a UNIQUE column"), so use `create_index ..., unique: true` |
| `size:`, `index:`, `as:` | none |

## Add a Column With a Default

```crystal
# ❌ default: is dropped: ALTER TABLE users ADD COLUMN active BOOLEAN NOT NULL
add_column :active, Bool, default: true, null: false
# Table with rows -> SQLite3::Exception: Cannot add a NOT NULL column with default value NULL
# Empty table     -> succeeds, then an INSERT without active fails: NOT NULL constraint failed: users.active
```

```crystal
# ✅ Nullable column, then a backfill with a bound value
class AddActiveToUsers < CQL::Migration(6)
  def up
    schema.alter :users do
      add_column :active, Bool
    end
    schema.update.table(:users).set(active: true).commit  # UPDATE users SET active = ?
  end

  def down
    schema.alter :users do
      drop_column :active
    end
  end
end

# ✅ Raw DDL when the database must enforce NOT NULL and the default
class AddVersionToUsers < CQL::Migration(7)
  def up
    schema.exec("ALTER TABLE users ADD COLUMN version INTEGER NOT NULL DEFAULT 1")
  end

  def down
    schema.exec("ALTER TABLE users DROP COLUMN version")
  end
end
```

`schema.exec` does not change the schema's table declaration, so `drop_column :version` would emit nothing; drop it
with raw DDL too. Raw DDL is not translated per dialect, so write it for your database.

## Add an Indexed Column

```crystal
schema.alter :posts do
  add_column :slug, String
  create_index :idx_posts_slug, [:slug], unique: true  # CREATE UNIQUE INDEX idx_posts_slug ON posts (slug)
end
# down: drop_index :idx_posts_slug, then drop_column :slug

schema.alter :users do
  add_column :deleted_at, Time                         # ADD COLUMN deleted_at TIMESTAMP, for SoftDeletable
  create_index :idx_users_deleted_at, [:deleted_at]
end
```

## Add Timestamps to an Existing Table

```crystal
schema.alter :posts do
  add_column :created_at, Time
  add_column :updated_at, Time
end
now = Time.utc
schema.update.table(:posts).set(created_at: now, updated_at: now).commit
```

## Add a Foreign Key Column

```crystal
# PostgreSQL and MySQL
schema.alter :posts do
  add_column :category_id, Int64
  create_index :idx_posts_category_id, [:category_id]
  foreign_key [:category_id], references: :categories, references_columns: [:id], on_delete: :set_null
end
# ALTER TABLE posts ADD COLUMN category_id BIGINT
# CREATE INDEX idx_posts_category_id ON posts (category_id)
# ALTER TABLE posts ADD CONSTRAINT fk_posts_category_id FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL ON UPDATE NO ACTION
# down: drop_foreign_key :fk_posts_category_id, drop_index, drop_column
```

{% hint style="warning" %}
On SQLite, `foreign_key` in `schema.alter` raises `DB::Error` while the block's SQL is built, so nothing in that block runs. Add the column alone, or recreate the table with the key declared.
{% endhint %}

## Use the Column in the Model

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)

  property name : String = ""
  property email : String = ""
  property avatar_url : String?
end

user = User.create!(name: "John", email: "john@example.com", avatar_url: "/avatars/john.png")
user.avatar_url # => "/avatars/john.png"
```

`create!` writes only columns the schema declares, so add the column to your `CQL::Schema.define` block too (with
`auto_sync`, the migrator rewrites the generated schema file for you).

## See Also

- [Create a Migration](create-migration.md)
- [Create Indexes](indexes.md)
- [Implement Soft Deletes](../models/soft-delete.md)
- [Add Optimistic Locking](../models/optimistic-locking.md)
- [Migration DSL Reference](../../reference/api/migration-dsl.md)
