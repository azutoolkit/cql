---
description: "Every method of the migration class, the table builder, the alter-table builder, the migrator and its config, with defaults and the SQL they produce."
---

# Migration DSL Reference

## Migration class

```crystal
class CreateUsers < CQL::Migration(20250125001401)
  def up
    schema.table :users do
      primary :id, Int64, auto_increment: true
      column :name, String
      column :email, String
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

| Member | Meaning |
| :--- | :--- |
| `class Name < CQL::Migration(V)` | `V` is an integer literal (usually a timestamp). Defining the class registers it in `CQL::Migrator.migrations`. |
| `def up`, `def down` | Required. Apply and revert the change. There is no irreversible marker: raise from `down`. |
| `schema` | The `CQL::Schema` the migrator runs on. |
| `Name.version` | `V` as `Int64`. |

## Schema methods used in migrations

| Method | Behavior |
| :--- | :--- |
| **`schema.table(name, as: nil) { ... }`** | Declares (or replaces) the table in the schema with the [table builder](#table-builder); runs no SQL. Returns the `CQL::Table`. |
| **`schema.<name>`**, `schema.tables[:name]` | The declared table (`KeyError` for `tables[:missing]`). |
| **`schema.alter(name) { ... }`** | Runs the [alter-table builder](#schemaalter) statements; `CQL::Schema::Error` if the table is not declared. |
| `schema.build` | `create_statements` of every declared table. |
| `schema.exec(sql)` | Runs one raw statement. |
| `schema.ddl_transaction { ... }` | Transaction (a SAVEPOINT when nested) on SQLite and PostgreSQL; bare on MySQL and CockroachDB, where it raises `CQL::DialectError` inside an open transaction. |

## Table builder

Methods available inside `schema.table :name do ... end` (and on a `CQL::Table`).

### Columns

| Method | Crystal type | Defaults |
| :--- | :--- | :--- |
| **`primary(name, type = Int32, auto_increment = true)`** | `type` | `auto_increment: false` makes a plain primary key. A bare `primary` declares `id`, `Int32`. |
| **`column(name, type, as: nil, null: false, default: nil, unique: false, size: nil, index: false)`** | `type` | see [Column options](#column-options) |
| `integer(name, ...)` | `Int32` | same options without `size` |
| `bigint(name, ...)` | `Int64` | |
| `float(name, ...)` | `Float32` | |
| `double(name, ...)` | `Float64` | |
| `real(name, ...)` | `Float64` | |
| `text(name, ..., size: nil)` | `String` | |
| `varchar(name, ..., size: 1000)` | `String` | |
| `boolean(name, ...)` | `Bool` | |
| `timestamp(name, ...)` | `Time` | |
| `date(name, ...)` | `Time`, declared `DATE` | |
| `json(name, ...)` | `JSON::Any` | |
| `blob(name, ..., size: nil)` | `Slice(UInt8)` | |
| `interval(name, ...)` | `Time::Span` | |
| **`lock_version(name = :version, as: nil, null: false, default: 1, index: false)`** | `Int32` | Marked as a version column (`version_columns`) for optimistic locking. |
| **`timestamps`** | `Time` | `created_at` and `updated_at`, `NOT NULL`, defaulting to the database's current time. |

```crystal
schema.table :posts do
  primary :id, Int64, auto_increment: true # id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY (PostgreSQL)
  column :user_id, Int64
  column :title, String, default: ""
  column :slug, String, unique: true, index: true # UNIQUE, plus CREATE UNIQUE INDEX idx_posts_slug
  column :body, String, null: true
  integer :views, default: 0
  bigint :bytes, default: 0
  float :ratio, null: true
  double :score, default: 0.0
  real :weight, null: true
  text :summary, null: true
  varchar :code, null: true
  boolean :published, default: false
  timestamp :published_at, null: true
  date :publish_on, null: true
  json :meta, null: true
  blob :cover, null: true
  interval :read_time, null: true
  lock_version
  timestamps
end
```

### Column options

| Option | Type | Default | SQL |
| :--- | :--- | :--- | :--- |
| `null` | `Bool` | `false` | `false` adds `NOT NULL` |
| `default` | `DB::Any` | `nil` | `DEFAULT <literal>`; strings quoted, `Bool` as `1`/`0` on SQLite and `TRUE`/`FALSE` elsewhere |
| `unique` | `Bool` | `false` | `UNIQUE`; with `index: true` the index is unique too |
| `index` | `Bool` | `false` | Declares `idx_<t>_<column>` (e.g. `idx_posts_slug`), created by `create!` after the table |
| `as` | `String?` | `nil` | Alias used when the column is selected |
| `size` | `Int32?` | `nil` | Stored, **not emitted**: `String` is always `TEXT` / `VARCHAR` / `VARCHAR(255)` |

### Column types

| Crystal type | SQLite | PostgreSQL | MySQL | CockroachDB |
| :--- | :--- | :--- | :--- | :--- |
| `Int32` | `INTEGER` | `INTEGER` | `INT` | `INT4` |
| `Int64` | `BIGINT` | `BIGINT` | `BIGINT` | `BIGINT` |
| `UInt32` | `INTEGER UNSIGNED` | `INTEGER` | `INT UNSIGNED` | `BIGINT` |
| `UInt64` | `BIGINT UNSIGNED` | `BIGINT` | `BIGINT UNSIGNED` | `BIGINT` |
| `Float32` | `FLOAT` | `REAL` | `FLOAT` | `REAL` |
| `Float64` | `DOUBLE` | `DOUBLE PRECISION` | `DOUBLE` | `DOUBLE PRECISION` |
| `String` | `TEXT` | `VARCHAR` | `VARCHAR(255)` | `VARCHAR` |
| `Bool` | `BOOLEAN` | `BOOLEAN` | `TINYINT(1)` | `BOOLEAN` |
| `Time` | `TIMESTAMP` | `TIMESTAMP` | `DATETIME(3)` | `TIMESTAMP` |
| `Time` via `date` | `DATE` | `DATE` | `DATE` | `DATE` |
| `Time::Span` | `INTERVAL` | `INTERVAL` | `TIME` | `INTERVAL` |
| `Slice(UInt8)` | `BLOB` | `BYTEA` | `BLOB` | `BYTEA` |
| `JSON::Any` | `TEXT` | `JSONB` | `JSON` | `JSONB` |
| auto-increment primary key | `INTEGER PRIMARY KEY AUTOINCREMENT` | `<type> GENERATED ALWAYS AS IDENTITY PRIMARY KEY` | `<type> PRIMARY KEY AUTO_INCREMENT` | as PostgreSQL |
| `timestamps` default | `DEFAULT (datetime('now'))` | `DEFAULT CURRENT_TIMESTAMP` | `DEFAULT NOW(3)` | `DEFAULT CURRENT_TIMESTAMP` |

`CQL::Adapter::Postgres.sql_type(Int64)` returns the mapping.

### Indexes and constraints

| Method | Defaults | SQL |
| :--- | :--- | :--- |
| **`index(columns : Array(Symbol), unique: false, name: nil)`**, `add_index(...)` | name `idx_<t>_<columns>` | `CREATE [UNIQUE] INDEX IF NOT EXISTS ...` after the table (no `IF NOT EXISTS` on MySQL). The same name again replaces the earlier index; a name over 63 characters raises `ArgumentError`. |
| **`unique_constraint(columns : Array(Symbol), name: nil)`** | unnamed | `CONSTRAINT <name> UNIQUE (...)` |
| **`check_constraint(condition : String, name: nil)`** | unnamed | `CONSTRAINT <name> CHECK (...)`; raises `CQL::MySqlUnsupportedFeatureError` on MySQL |
| **`foreign_key(columns : Array(Symbol), references:, references_columns: nil, name: nil, on_delete: :no_action, on_update: :no_action)`** | `references_columns` defaults to the referenced table's primary key (`:id` if that table is not declared) | `FOREIGN KEY (...) REFERENCES t (...) ON DELETE ... ON UPDATE ...`; unnamed unless `name:` (MySQL names it `fk_<t>_<columns>`); PostgreSQL omits `NO ACTION` clauses |
| `foreign_key(column : Symbol, references:, ...)` | | single-column form |

`on_delete` / `on_update`: `:cascade`, `:restrict`, `:set_null`, `:no_action`. `references_columns` takes a `Symbol` or an `Array(Symbol)`.

```crystal
schema.table :comments do
  primary :id, Int64, auto_increment: true
  column :post_id, Int64
  column :user_id, Int64, null: true
  column :rating, Int32, default: 0
  foreign_key [:post_id], references: :posts, on_delete: :cascade
  foreign_key :user_id, references: :users, references_columns: :id, name: "fk_comments_user", on_delete: :set_null
  unique_constraint [:post_id, :user_id], name: "uq_comment_author"
  check_constraint "rating >= 0", name: "chk_rating"
  index [:post_id, :rating], name: "idx_comments_post_rating"
end
```

### Table methods

| Method | Returns | Behavior |
| :--- | :--- | :--- |
| `create!` | | Runs `create_statements`. |
| `drop!` | | `DROP TABLE IF EXISTS <t>` |
| `truncate!` | | `TRUNCATE TABLE <t>`; `DELETE FROM <t>` on SQLite |
| `create_sql` | `String` | `CREATE TABLE IF NOT EXISTS <t> (...)` |
| `create_index_sqls` | `Array(String)` | One `CREATE INDEX` per declared index |
| `create_statements` | `Array(String)` | `create_sql` followed by `create_index_sqls` |
| `drop_sql`, `truncate_sql` | `String` | The SQL of `drop!` / `truncate!` |
| `columns`, `indexes`, `foreign_keys`, `unique_constraints`, `check_constraints` | collections | What the block declared |
| `primary_key` | `BaseColumn?` | The declared primary key |
| `version_columns` | `Array(BaseColumn)` | Columns declared with `lock_version` |
| `<column>` | `BaseColumn` | A declared column by name (`schema.users.email`) |

```crystal
AppDB.users.create_sql
# => "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, ...)" (SQLite)
```

## `schema.alter`

Methods of `CQL::AlterTable`, available inside `schema.alter :name do ... end`. Statements run in order, in `ddl_transaction`.

| Method | Defaults | Notes |
| :--- | :--- | :--- |
| **`add_column(name, type, as: nil, null: true, default: nil, unique: false, size: nil, index: false)`** | `null: true` | **`default`, `index` and `size` are ignored**: no `DEFAULT` clause and no index are emitted, so `null: false` fails on a table with rows (SQLite: `Cannot add a NOT NULL column with default value NULL`). Use raw DDL for a default, below. |
| **`drop_column(name)`** | | An undeclared column only logs an error |
| **`rename_column(old, new)`** | | Raises `KeyError` for an undeclared column |
| **`change_column(name, type)`** | | Raises `CQL::SQLiteUnsupportedFeatureError` on SQLite |
| **`rename_table(new_name)`** | | Renames the table object at once, but every statement renders after the block, so other operations in the same block use the new name before the rename runs. Give it its own `schema.alter` block. |
| **`create_index(name : Symbol, columns : Array(Symbol), unique: false)`** | | No `IF NOT EXISTS` |
| **`drop_index(name : Symbol)`** | | |
| **`foreign_key(columns or column, references:, references_columns: nil, name : Symbol? = nil, on_delete: :no_action, on_update: :no_action)`** | `references_columns` `[:id]`, name `fk_<t>_<columns>` | Raises `DB::Error` on SQLite |
| **`drop_foreign_key(name : Symbol)`** | | Raises `CQL::SQLiteUnsupportedFeatureError` on SQLite |

```crystal
# PostgreSQL. On SQLite, change_column, foreign_key and drop_foreign_key raise.
schema.alter :users do
  add_column :phone, String
  add_column :age, Int32, null: true
  rename_column :name, :full_name
  change_column :age, Int64
  create_index :idx_users_phone, [:phone], unique: true
  foreign_key [:team_id], references: :teams, on_delete: :cascade
  drop_foreign_key :fk_users_team_id
  drop_index :idx_users_phone
  drop_column :phone
end

schema.alter :users do
  rename_table :members # alone: see the note on rename_table
end
```

A column with a default, added with raw DDL and then declared so the schema knows it:

```crystal
def up
  schema.exec "ALTER TABLE users ADD COLUMN level INTEGER DEFAULT 1 NOT NULL"
  schema.users.integer :level, default: 1 # declares only; runs no SQL
end
```

<details>
<summary>The SQL each statement emits, per dialect</summary>

| Method | SQLite | PostgreSQL / CockroachDB | MySQL |
| :--- | :--- | :--- | :--- |
| `add_column :phone, String` | `ALTER TABLE users ADD COLUMN phone TEXT` | `... ADD COLUMN phone VARCHAR` | `... ADD COLUMN phone VARCHAR(255)` |
| `add_column :age, Int32, null: false, unique: true` | `... ADD COLUMN age INTEGER NOT NULL UNIQUE` | `... age INTEGER NOT NULL UNIQUE` (`INT4` on CockroachDB) | `... age INT NOT NULL UNIQUE` |
| `drop_column :bio` | `... DROP COLUMN bio` (SQLite 3.35+) | `... DROP COLUMN bio` | `... DROP COLUMN bio` |
| `rename_column :nick, :handle` | `... RENAME COLUMN nick TO handle` | same | `... CHANGE nick handle VARCHAR(255)` |
| `change_column :score, Int64` | raises | `... ALTER COLUMN score TYPE BIGINT` | `... MODIFY COLUMN score BIGINT` |
| `create_index :idx_users_phone, [:phone], unique: true` | `CREATE UNIQUE INDEX idx_users_phone ON users (phone)` | same | same |
| `drop_index :idx_users_phone` | `DROP INDEX IF EXISTS idx_users_phone` | same | `DROP INDEX idx_users_phone ON users` |
| `foreign_key [:team_id], references: :teams` | raises | `... ADD CONSTRAINT fk_users_team_id FOREIGN KEY (team_id) REFERENCES teams (id) ON DELETE NO ACTION ON UPDATE NO ACTION` | same |
| `drop_foreign_key :fk_users_team_id` | raises | `... DROP CONSTRAINT fk_users_team_id` | `... DROP FOREIGN KEY fk_users_team_id` |
| `rename_table :members` | `ALTER TABLE users RENAME TO members` | same | `RENAME TABLE users TO members` |

</details>

## `Migrator`

```crystal
config = CQL::MigratorConfig.new(schema_file_path: "src/schemas/app_schema.cr", auto_sync: true)
migrator = AppDB.migrator(config)

migrator.up                         # apply every pending migration
migrator.pending_migrations         # => [] of CQL::BaseMigration.class
migrator.applied_migrations.size    # => 1
migrator.rollback                   # revert the newest migration
migrator.up_to(20250125001401_i64)  # apply up to and including this version
```

| Method | Behavior |
| :--- | :--- |
| `schema.migrator`, `schema.migrator(config)`, `CQL::Migrator.new(schema, config = MigratorConfig.new)` | Builds the migrator: with `auto_sync` dumps the schema file, then creates the migrations table (`ddl_transaction`). |
| **`up(steps = all)`** | Takes the first `steps` migrations in version order and applies the pending ones, in one `ddl_transaction`; then rewrites the schema file (`auto_sync`) and prints the applied list. |
| **`down(steps = all)`** | Takes the newest `steps` *defined* migrations and reverts the applied ones, in one `ddl_transaction`; then rewrites the schema file and prints what was rolled back. |
| **`rollback(steps = 1)`** | `down(steps)`. When the newest defined migration is pending, it does nothing. |
| `redo` | `rollback`, then `up`. |
| `up_to(version : Int64)` | `up(position + 1)` where `position` is the index of `version` in all migrations: applies up to and including it. Unknown versions do nothing. |
| `down_to(version : Int64)` | `down(position + 1)`: reverts `position + 1` migrations from the newest, so `down_to(first)` reverts only the newest and `down_to(newest)` reverts all. Prefer `down(n)`. |
| `pending_migrations` | `Array(BaseMigration.class)` in version order. |
| `applied_migrations` | `Array(CQL::MigrationRecord)` (`id`, `name`, `version`). |
| `last` | The newest applied migration class, or `nil`. |
| `print_applied_migrations`, `print_pending_migrations`, `print_rolled_back_migrations(list)` | Print a status table. |
| `update_schema_file` | Dumps the database to `schema_file_path`; `CQL::Migrator::Error` on failure. |
| `verify_schema_consistency` | `Bool`: the dump equals the file. `false` when the file is missing or the dump fails. |
| `bootstrap_schema` | `update_schema_file` with log lines. |
| `config`, `schema`, `repo` | The `MigratorConfig`, the schema, the `Repository(MigrationRecord, Int32)`. |

### `MigratorConfig`

| Property | Type | Default |
| :--- | :--- | :--- |
| `schema_file_path` | `String` | `"src/schemas/app_schema.cr"` |
| `schema_name` | `Symbol` | `:AppSchema` (constant in the generated file) |
| `schema_symbol` | `Symbol` | `:app_schema` |
| `migration_table_name` | `Symbol` | `:cql_schema_migrations` |
| `auto_sync?` | `Bool` | `true`: rewrite the schema file when the migrator is built and after `up` / `down` |

`CQL.build_migrator(schema)` builds the config from `CQL.configure` instead (table `:schema_migrations`); see the [Configuration Reference](../configuration.md#helpers).

## See Also

- [Create a Migration](../../how-to/migrations/create-migration.md)
- [Run Migrations](../../how-to/migrations/run-migrations.md)
- [Rollback Migrations](../../how-to/migrations/rollback.md)
- [Add Columns](../../how-to/migrations/add-columns.md)
- [Database Support](../database-support.md)
