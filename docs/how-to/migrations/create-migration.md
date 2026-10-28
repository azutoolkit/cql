---
description: "Write a CQL::Migration(version) subclass with up and down; defining the class registers it with CQL::Migrator."
---

# Create a Migration

## Write a Migration

{% code title="db/migrations/001_create_users.cr" %}
```crystal
class CreateUsers < CQL::Migration(1)
  def up
    users.create!   # CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, ...)
  end

  def down
    users.drop!     # DROP TABLE IF EXISTS users
  end

  # Declares the table on the migrator's schema, for up and for a down run in a later process
  private def users : CQL::Table
    schema.table :users do
      primary :id, Int64, auto_increment: true
      column :name, String
      column :email, String
      timestamps
    end
  end
end
```
{% endcode %}

```crystal
# CQL::Migration(2)               the version is an Int64, unique, applied in ascending order
# CQL::Migration(20250125120000)  timestamps sort the same way
# Two migrations with the same version make CQL::Migrator.new raise CQL::Migrator::Error:
# renumber the one cql_schema_migrations does not list. If that one already ran, first insert a
# cql_schema_migrations row with its full class name and new version, or `up` runs it again

# Only defined classes are registered: require every file before running the migrator
require "./db/migrations/*"
```

`up` and `down` take no arguments; `schema` is the schema you built the migrator from. When that schema already
declares the table (your `CQL::Schema.define` block or the generated schema file), `schema.users.create!` and
`schema.users.drop!` are enough. Otherwise `schema.users` raises `KeyError` in a process that did not run `up`.

## Create a Table With Foreign Keys and Indexes

{% code title="db/migrations/002_create_posts.cr" %}
```crystal
class CreatePosts < CQL::Migration(2)
  def up
    posts.create!
    # CREATE TABLE IF NOT EXISTS posts (..., user_id BIGINT NOT NULL, ...,
    #   FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE NO ACTION)
    # CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts (user_id)
  end

  def down
    posts.drop!
  end

  private def posts : CQL::Table
    schema.table :posts do
      primary :id, Int64, auto_increment: true
      column :title, String
      column :published, Bool, default: false
      column :user_id, Int64
      timestamps
      foreign_key [:user_id], references: :users, references_columns: [:id], on_delete: :cascade
      index [:user_id]
    end
  end
end
```
{% endcode %}

## Change an Existing Table

{% code title="db/migrations/003_change_users.cr" %}
```crystal
class ChangeUsers < CQL::Migration(3)
  def up
    schema.alter :users do
      add_column :bio, String                  # ALTER TABLE users ADD COLUMN bio TEXT
      rename_column :name, :full_name          # ALTER TABLE users RENAME COLUMN name TO full_name
      create_index :idx_users_email, [:email], unique: true
    end
  end

  def down
    schema.alter :users do
      drop_index :idx_users_email              # DROP INDEX IF EXISTS idx_users_email
      rename_column :full_name, :name
      drop_column :bio                         # ALTER TABLE users DROP COLUMN bio /* Warning: Only works on SQLite 3.35.0+ */
    end
  end
end
```
{% endcode %}

`schema.alter` raises `CQL::Schema::Error` ("Table 'users' not found") unless the schema declares the table, and it
reads columns from that declaration:

| Call | SQLite | If the schema does not declare the column |
| :--- | :--- | :--- |
| `add_column`, `rename_table`, `create_index`, `drop_index` | yes | n/a |
| `rename_column` | yes | raises `KeyError` |
| `drop_column` | yes (SQLite 3.35+) | emits `DROP COLUMN`; the database raises if the column is missing |
| `change_column :views, Int64` | `CQL::SQLiteUnsupportedFeatureError` | n/a |
| `foreign_key [...], references: ...` | `CQL::SQLiteUnsupportedFeatureError` | n/a |
| `drop_foreign_key :fk_posts_user_id` | `CQL::SQLiteUnsupportedFeatureError` | n/a |

```sql
-- PostgreSQL, from foreign_key, drop_foreign_key and change_column in schema.alter :posts
ALTER TABLE posts ADD CONSTRAINT fk_posts_user_id FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE NO ACTION
ALTER TABLE posts DROP CONSTRAINT fk_posts_user_id
ALTER TABLE posts ALTER COLUMN title TYPE BIGINT
```

On SQLite, declare foreign keys in the `schema.table` block and recreate the table to change a column type.

## Make a Migration Irreversible

{% code title="db/migrations/004_drop_legacy_field.cr" %}
```crystal
class DropLegacyField < CQL::Migration(4)
  def up
    schema.alter :users do
      drop_column :legacy_field
    end
  end

  def down
    raise CQL::Migrator::Error.new("DropLegacyField cannot be reversed")
  end
end
```
{% endcode %}

The exception aborts the rollback; on SQLite and PostgreSQL nothing is reverted.

## Test a Migration

```crystal
it "creates and drops users" do
  migrator = AppDB.migrator(CQL::MigratorConfig.new(auto_sync: false)) # leaves the schema file alone
  migrator.up
  AppDB.exec_query { |conn| conn.scalar("SELECT COUNT(*) FROM users") }.should eq(0)
  migrator.down
end
```

## See Also

- [Run Migrations](run-migrations.md)
- [Rollback Migrations](rollback.md)
- [Add Columns](add-columns.md)
- [Create Indexes](indexes.md)
- [Migration DSL Reference](../../reference/api/migration-dsl.md)
- [Fix Migration Errors](../troubleshooting/migration-errors.md)
