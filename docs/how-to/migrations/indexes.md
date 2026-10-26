---
description: "Declare indexes with a new table, add them to existing tables in migrations, and check that queries use them."
---

# Create Indexes

## Declare Indexes With the Table

{% code title="db/migrations/004_create_accounts.cr" %}
```crystal
class CreateAccounts < CQL::Migration(4)
  def up
    accounts.create!
  end

  def down
    accounts.drop!
  end

  private def accounts : CQL::Table
    schema.table :accounts do
      primary :id, Int64
      column :email, String, index: true
      column :name, String
      column :status, String
      index [:name, :status], unique: true
      index [:status], name: "idx_accounts_by_status"
    end
  end
end
```
{% endcode %}

```sql
-- table.create! and schema.build run, after CREATE TABLE IF NOT EXISTS accounts (...):
CREATE INDEX IF NOT EXISTS idx_accounts_email ON accounts (email)
CREATE UNIQUE INDEX IF NOT EXISTS idx_accounts_name_status ON accounts (name, status)
CREATE INDEX IF NOT EXISTS idx_accounts_by_status ON accounts (status)
-- MySQL has no IF NOT EXISTS for indexes: CREATE INDEX idx_accounts_email ON accounts (email)
```

- Without `name:`, an index is named after its table and columns, as `idx_accounts_name_status` above. A name longer
  than 63 characters raises `ArgumentError`; pass a shorter `name:`.
- `IF NOT EXISTS` makes a second `create!` safe on SQLite, PostgreSQL and CockroachDB. On MySQL it fails with a
  duplicate key name error.
- SQLite and PostgreSQL share index names across the whole schema, so a second table that reuses an explicit `name:`
  silently gets no index. Keep names unique.

## Add Indexes to an Existing Table

{% code title="db/migrations/005_add_user_indexes.cr" %}
```crystal
class AddUserIndexes < CQL::Migration(5)
  def up
    schema.alter :users do
      create_index :idx_users_email, [:email], unique: true            # CREATE UNIQUE INDEX idx_users_email ON users (email)
      create_index :idx_users_status_created, [:status, :created_at]   # composite: filter on status, sort by created_at
      create_index :idx_users_deleted_at, [:deleted_at]                # SoftDeletable filters on deleted_at
    end

    schema.alter :posts do
      create_index :idx_posts_user_id, [:user_id]                      # foreign keys: joins and preload
      create_index :idx_posts_user_published, [:user_id, :published]
    end
  end

  def down
    schema.alter :users do
      drop_index :idx_users_email          # DROP INDEX IF EXISTS idx_users_email (MySQL: DROP INDEX idx_users_email ON users)
      drop_index :idx_users_status_created
      drop_index :idx_users_deleted_at
    end

    schema.alter :posts do
      drop_index :idx_posts_user_id
      drop_index :idx_posts_user_published
    end
  end
end
```
{% endcode %}

`create_index` takes an explicit name and emits no `IF NOT EXISTS`, so running it again fails
(`index idx_users_email already exists` on SQLite). A unique index also rejects duplicate rows:
`UNIQUE constraint failed: users.email`. The table must be declared on the schema, or `schema.alter` raises
`CQL::Schema::Error`.

## Choose What to Index

| Index | For |
| :--- | :--- |
| Foreign key columns (`user_id`) | `joins`, `preload` and `where(user_id: ...)` |
| Columns in `where` and `order` | filters and sorts on large tables |
| Unique index | uniqueness rules and `upsert_all(on_conflict: ...)` |
| Composite `[a, b]` | filters on `a`, or on `a` and `b`; usually not on `b` alone |

Every index slows inserts and updates a little, so skip columns that queries never filter on.

## Check That a Query Uses the Index

```crystal
puts User.where(email: "john@example.com").query.explain
# SEARCH users USING INDEX idx_users_email (email=?)

puts User.where(active: true).query.explain
# SCAN users   (no index on active: every row is read)
```

## See Also

- [Create a Migration](create-migration.md)
- [Add Columns](add-columns.md)
- [Optimize Queries](../performance/optimize-queries.md)
- [Inspect Queries with to_sql and explain](../querying/explain-and-to-sql.md)
- [Upsert Records](../data-operations/upsert.md)
