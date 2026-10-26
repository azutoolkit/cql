# Adding CQL to an Existing Project

Add CQL to an app whose PostgreSQL database already has `users` and `products` tables, then move code over one query at a time.

**You need:** an existing Crystal project, its database URL, and the basics from [Your First CQL App](your-first-cql-app.md).

## Step 1: Add the dependency

Add CQL to `shard.yml` and keep your existing driver:

```yaml
dependencies:
  cql:
    github: azutoolkit/cql
    version: "~> 0.0.589"
  # PostgreSQL needs no other shard: require "cql" registers a native driver.
  # If your app already uses the pg shard, keep it; once required, it serves postgres:// URLs.
```

```bash
shards install
```

Check: the output lists `Installing cql`.

## Step 2: Describe the existing tables

```crystal
# src/cql_config.cr
require "cql" # includes a native PostgreSQL driver for postgres:// URLs

DATABASE_URL = ENV["DATABASE_URL"]? || "postgres://localhost/myapp_development"

# Describe the tables that already exist; CQL creates nothing until you call create!
AppDB = CQL::Schema.define(:app_db, adapter: CQL::Adapter::Postgres, uri: DATABASE_URL) do
  table :users do
    primary :id, Int64, auto_increment: true
    text :email
    text :name, null: true # columns are NOT NULL unless null: true
    text :password_digest, null: true
    timestamps
  end

  table :products do
    primary :id, Int64, auto_increment: true
    text :name
    text :description, null: true
    double :price, null: true
    integer :stock, default: 0
    timestamps
  end
end

CQL_MIGRATOR_CONFIG = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  auto_sync: true
)
```

Declare each column under its real name: a model property reads the column of the same name.

## Step 3: Map models to the tables

```crystal
# src/models/user.cr
class User
  include CQL::ActiveRecord::Model(Int64) # adds the id primary key
  db_context AppDB, :users

  property email : String
  property name : String?
  property password_digest : String?
  property created_at : Time?
  property updated_at : Time?

  def initialize(@email : String, @name : String? = nil)
  end
end
```

```crystal
# src/models/product.cr
class Product
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :products

  property name : String
  property description : String?
  property price : Float64?
  property stock : Int32 = 0
  property created_at : Time?
  property updated_at : Time?

  def initialize(@name : String, @price : Float64? = nil)
  end
end
```

## Step 4: Load CQL in your application

Requiring the config and models is all the setup CQL needs; the pool opens when code first uses `AppDB`.

```crystal
# src/app.cr (your main file)
require "./cql_config"
require "./models/*"

# ...your existing application code
```

Check it against your data:

```crystal
# src/cql_check.cr
require "./cql_config"
require "./models/*"

puts "users: #{User.count}, products: #{Product.count}"
puts "first user: #{User.first.try(&.email)}"
```

```bash
crystal src/cql_check.cr
```

It prints your own row counts, for example:

```text
users: 1, products: 0
first user: ada@example.com
```

## Step 5: Add a table with a migration

```crystal
# migrations/001_create_orders.cr
class CreateOrders < CQL::Migration(1)
  def up
    schema.table :orders do
      primary :id, Int64, auto_increment: true
      column :user_id, Int64
      column :total, Float64
      column :status, String, default: "pending"
      timestamps

      foreign_key [:user_id], references: :users, references_columns: [:id]
    end

    schema.orders.create!

    schema.alter :orders do
      create_index :idx_orders_user_id, [:user_id]
      create_index :idx_orders_status, [:status]
    end
  end

  def down
    schema.orders.drop!
  end
end
```

## Step 6: Run the migration

```crystal
# src/migrate.cr
require "./cql_config"
require "../migrations/*"

migrator = AppDB.migrator(CQL_MIGRATOR_CONFIG)

case ARGV[0]?
when "up"
  migrator.up
when "down"
  migrator.rollback # the newest migration; migrator.down with no argument rolls back all
when "status"
  puts "Applied: #{migrator.applied_migrations.map(&.version)}"
  puts "Pending: #{migrator.pending_migrations.map(&.version)}"
else
  puts "Usage: crystal src/migrate.cr [up|down|status]"
end
```

```bash
crystal src/migrate.cr up
crystal src/migrate.cr status
```

```text
...
│   ✔    │ CreateOrders │       1 │
...
Applied: [1]
Pending: []
```

The migration declares `orders` only while it runs. Add the table to `AppDB` in `src/cql_config.cr` too, so that models can use it and `down` can drop it:

```crystal
  table :orders do # added by migrations/001_create_orders.cr
    primary :id, Int64, auto_increment: true
    column :user_id, Int64
    column :total, Float64
    column :status, String, default: "pending"
    timestamps
  end
```

Or point models at `AppSchema`, which `auto_sync` writes to `src/schemas/app_schema.cr` after every run.

Check: `crystal src/migrate.cr down` prints `✗ CreateOrders`, and `up` reapplies it.

## Step 7: Move code over one phase at a time

Raw SQL and CQL run side by side, so switch one kind of query at a time, starting with reads.

```crystal
# Phase 1, reads. Before:
db.query("SELECT * FROM users WHERE email = $1", email)
# After:
user = User.find_by(email: email) # => User?

# Phase 2, simple writes. Before:
db.exec("INSERT INTO users (email, name) VALUES ($1, $2)", email, name)
# After:
user = User.create!(email: email, name: name)

# Phase 3, aggregates. Before:
db.query_all("SELECT user_id, COUNT(id) FROM orders GROUP BY user_id LIMIT 10", as: {Int64, Int64})
# After:
order_counts = AppDB.query
  .from(:orders)
  .select(:user_id, count: :id)
  .group(:user_id)
  .limit(10)
  .all(as: {Int64, Int64}) # [{user_id, order_count}, ...]
```

Phase 4 adds associations:

```crystal
# src/models/order.cr
class Order
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :orders

  property user_id : Int64
  property total : Float64
  property status : String = "pending"
  property created_at : Time?
  property updated_at : Time?

  belongs_to :user, User, :user_id

  def initialize(@user_id : Int64, @total : Float64)
  end
end
```

```crystal
# src/models/user.cr: add below the properties
  has_many :orders, Order, :user_id
```

```crystal
user = User.find_by!(email: email)
puts "#{user.email} has #{user.orders.count} order(s)"
```

Keep raw SQL where the builder falls short, and wrap bulk changes in `AppDB.transaction`.

## Existing migrations from another ORM

CQL tracks its migrations in its own `cql_schema_migrations` table, so another ORM's migrations do not conflict. Leave them in place and either number CQL migrations after them (a timestamp such as `CQL::Migration(20260101120000)` works), or add an empty baseline:

```crystal
# migrations/000_baseline.cr
class Baseline < CQL::Migration(0)
  def up
    # The tables already exist; this only marks the starting point for CQL
  end

  def down
    raise "Cannot roll back the baseline migration"
  end
end
```

## Rename a column to match a property

To read a column such as `user_email` into an `email` property, rename it once old code no longer reads it. `rename_column` looks the column up in the schema, so declare `text :user_email` in `AppDB` until the migration runs, then change it to `text :email`.

```crystal
class RenameUserEmail < CQL::Migration(20260101130000)
  def up
    schema.alter :users do
      rename_column :user_email, :email
    end
  end

  def down
    schema.alter :users do
      rename_column :email, :user_email
    end
  end
end
```

## Next steps

- [Define a Model](../../how-to/models/define-model.md)
- [Run Migrations](../../how-to/migrations/run-migrations.md)
- [Building a Blog](../building-a-blog/01-project-setup.md)
