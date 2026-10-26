---
description: "Add columns to an existing table with schema.alter, with defaults, indexes and data backfills."
---

# Add Columns

## Add Nullable Columns

{% code title="db/migrations/005_add_profile_fields_to_users.cr" %}
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
{% endcode %}

`add_column` makes nullable columns (`null: true`) unless you pass `null: false`, unlike `column` in a `schema.table`
block.

| Option | Effect on the `ADD COLUMN` statement |
| :--- | :--- |
| `null: false` | adds `NOT NULL` |
| `default:` | adds `DEFAULT <value>`, which also fills the existing rows |
| `unique: true` | adds `UNIQUE`; SQLite rejects it ("Cannot add a UNIQUE column"), so use `create_index ..., unique: true` |
| `index: true` | runs `CREATE INDEX idx_<table>_<column>` after the column (`UNIQUE` with `unique: true`) |
| `size:` | `VARCHAR(size)` for a `String` column on PostgreSQL, CockroachDB and MySQL; SQLite's `TEXT` has no length |
| `as:` | none: it names the column in selects |

## Add a Column With a Default

{% code title="db/migrations/006_add_active_to_users.cr" %}
```crystal
class AddActiveToUsers < CQL::Migration(6)
  def up
    schema.alter :users do
      add_column :active, Bool, default: true, null: false
      # ALTER TABLE users ADD COLUMN active BOOLEAN DEFAULT 1 NOT NULL (SQLite; DEFAULT TRUE on PostgreSQL)
    end
  end

  def down
    schema.alter :users do
      drop_column :active
    end
  end
end
```
{% endcode %}

The default fills the rows already in the table, so a `NOT NULL` column can be added to a table with data. When the
value depends on each row, add the column nullable and fill it as in
[Migrate Data in Batches](#migrate-data-in-batches).

## Migrate Data in Batches

{% code title="db/migrations/007_normalize_user_emails.cr" %}
```crystal
class NormalizeUserEmails < CQL::Migration(7)
  BATCH_SIZE = 1000 # a constant you control, never user input

  def up
    loop do
      # MySQL rejects LIMIT inside IN (...): select the ids first there
      result = schema.exec(<<-SQL)
        UPDATE users SET email = LOWER(TRIM(email))
        WHERE id IN (SELECT id FROM users WHERE email <> LOWER(TRIM(email)) LIMIT #{BATCH_SIZE})
        SQL
      break if result.rows_affected == 0
    end

    left = schema.exec_query do |conn|
      conn.scalar("SELECT COUNT(*) FROM users WHERE email <> LOWER(TRIM(email))").as(Int64)
    end
    raise "Data migration incomplete: #{left} emails left" if left > 0
  end

  def down
    raise "Cannot roll back #{self.class.name}: the original emails are gone"
  end
end
```
{% endcode %}

Each `UPDATE` touches at most 1,000 rows, but on SQLite and PostgreSQL every batch still runs in the migration run's one
transaction. If `email` is unique, addresses that differ only in case collide; find them first with
`GROUP BY LOWER(TRIM(email)) HAVING COUNT(*) > 1`.

## Add an Indexed Column

```crystal
schema.alter :users do
  add_column :deleted_at, Time, index: true            # ADD COLUMN deleted_at TIMESTAMP, for SoftDeletable,
end                                                    # then CREATE INDEX idx_users_deleted_at ON users (deleted_at)

schema.alter :posts do
  add_column :slug, String
  create_index :idx_posts_slug, [:slug], unique: true  # CREATE UNIQUE INDEX idx_posts_slug ON posts (slug)
end
# down: drop_index :idx_posts_slug, then drop_column :slug
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

{% tabs %}
{% tab title="PostgreSQL and MySQL" %}
```crystal
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
{% endtab %}

{% tab title="SQLite" %}
{% hint style="warning" %}
`foreign_key` in `schema.alter` raises `CQL::SQLiteUnsupportedFeatureError` while the block's SQL is built, so nothing in that block runs. Add the column alone, or recreate the table with the key declared.
{% endhint %}
{% endtab %}
{% endtabs %}

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
