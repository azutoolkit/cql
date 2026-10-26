# Frequently Asked Questions

Short answers, each linking to the page that covers the task.

## General

### What is CQL?

A type-safe query DSL and ORM for Crystal: schemas, migrations, a query builder and Active Record models. Start with [Your First CQL App](../tutorials/getting-started/your-first-cql-app.md).

### What databases does CQL support?

SQLite, PostgreSQL, MySQL and CockroachDB. See [Database Support](../reference/database-support.md) for what each supports and [Configure Database Connection](../how-to/configuration/database-connection.md) for their URLs.

### Is CQL stable?

CQL is pre-1.0: `shard.yml` carries a `0.0.x` version, and CI tags a new release for every push to `master`. Pin a version in your `shard.yml` and read the **Upgrade notes** in `CHANGELOG.md` before you update.

## Models

### Should I use `class` or `struct` for models?

Use `class`: `save` assigns the generated id to the instance it is called on, which a struct copy would not see. See [Define a Model](../how-to/models/define-model.md).

### Why is my primary key nullable?

A new record has no id until it is saved. `CQL::ActiveRecord::Model(Int64)` provides `id` (an `Int64?`), `id!` (raises while it is `nil`) and `id=`:

```crystal
user = User.new("Ada", "ada@example.com")
user.id  # => nil
user.save
user.id! # => 1
```

### How do I add a field that isn't in the database?

Mark it with `DB::Field(ignore: true)`. CQL leaves it out of `INSERT` and `UPDATE`, and it is `nil` on records it reads:

```crystal
@[DB::Field(ignore: true)]
property remember_token : String?
```

See [Define a Model](../how-to/models/define-model.md).

## Queries

### How do I write raw SQL?

Add a fragment with bound values. Use `?` or `:name` placeholders in one fragment, never both:

```crystal
User.where("lower(email) = ? AND age > ?", "ada@example.com", 18).all
User.where("lower(email) = :email AND age > :age", email: "ada@example.com", age: 18).all
```

For a whole statement, use the pooled connection; `AppDB.exec(sql)` runs a statement and returns a `DB::ExecResult`, not rows:

```crystal
rows = AppDB.exec_query do |conn|
  conn.query_all("SELECT name, age FROM users WHERE id = ?", 1, as: {String, Int32})
end
```

See [Use Raw SQL Fragments Safely](../how-to/querying/raw-fragments.md).

### Why is my query returning an empty array?

Print the SQL and its parameters (next question) and compare them with your data. SoftDeletable models hide soft-deleted records. `where(col: nil)` and `where { col == nil }` match `IS NULL`, but a raw fragment `col = ?` with `nil` matches nothing. See [Filter with Where Clauses](../how-to/querying/filter-records.md) and [Implement Soft Deletes](../how-to/models/soft-delete.md).

### How do I see the SQL a query will run?

```crystal
User.where(active: true).to_sql       # => "SELECT users.id, ... FROM users WHERE users.active = ?"
User.where(active: true).query.to_sql # => {"SELECT ... WHERE users.active = ?", [true]}
```

To log every statement CQL runs:

```crystal
Log.setup do |c|
  c.bind("cql.*", :debug, Log::IOBackend.new)
end

CQL::Telemetry.log_queries # one debug line per statement on the "cql.telemetry" source
```

See [Inspect Queries with to_sql and explain](../how-to/querying/explain-and-to-sql.md) and [Telemetry](../how-to/performance/telemetry.md).

## Relationships

### When do I use belongs_to vs has_many?

- `belongs_to`: this model has the foreign key column (`Comment` has `post_id`).
- `has_many`: the other model has the foreign key (`Post` has many `Comment`s).

See [Set Up Belongs To](../how-to/relationships/belongs-to.md) and [Set Up Has Many](../how-to/relationships/has-many.md).

### Why does my relationship fail at compile time?

CQL checks associations while compiling. A `belongs_to` or `has_many` fails when the foreign key getter is missing, the arguments are not literals, or the key types differ. A `Post` with `property user_id : Int32?` cannot belong to a `User` keyed by `Int64`:

```text
CQL belongs_to error in Post: foreign key `:user_id` type Int32 does not match User.id! primary key type Int64. Change `:user_id` to Int64 or update the target model primary key type.
```

Change the foreign key to `Int64?`, or change the related model's key type. See [Set Up Belongs To](../how-to/relationships/belongs-to.md).

### How do I check that models match the schema?

Set `CQL_VALIDATE_SCHEMA_MAPPINGS=1`: each model's getter types are compared with the columns its schema declares, and a mismatch raises `CQL::ActiveRecord::SchemaMappingError` ("CQL schema mapping error in User: ..."). The check runs after all other top-level code, so an application that starts a blocking server never reaches it; run it in CI from a program that only requires your models. See [Fix Schema Mapping Errors](../how-to/troubleshooting/schema-mapping-errors.md).

### How do I eager load associations?

`preload` loads `has_many`, `belongs_to` and `has_one` associations with one extra query each:

```crystal
users = User.preload(:posts).all # 2 queries; user.posts is already loaded
posts = Post.preload(:user).all  # 2 queries
```

`preload` ignores `many_to_many`. Load those in batches through the join model:

```crystal
posts = Post.all
post_ids = posts.compact_map(&.id)
links = PostTag.where { post_id.in(post_ids) }.all
tags = Tag.where { id.in(links.map(&.tag_id).uniq) }.all.index_by(&.id)
```

Skip a query when its id list is empty: `in([])` renders `IN ()`, which PostgreSQL and MySQL reject.

See [Avoid N+1 Queries](../how-to/performance/n-plus-one.md).

## Migrations

### How do I add a column to an existing table?

```crystal
class AddAvatarToUsers < CQL::Migration(5)
  def up
    schema.alter :users do
      add_column :avatar_url, String, null: true
    end
  end

  def down
    schema.alter :users do
      drop_column :avatar_url
    end
  end
end
```

`add_column` ignores its `default:` option, so existing rows get `NULL`; fill them with an `UPDATE` in the same migration if they need a value. See [Add Columns](../how-to/migrations/add-columns.md).

### How do I roll back a migration?

```crystal
migrator.rollback    # the newest migration
migrator.rollback(2) # the two newest
migrator.down        # every migration
```

Steps count back from the newest *registered* migration, so a pending migration newer than the applied ones uses up a step without rolling anything back. `down_to(version)` does not stop at `version`; see [Rollback Migrations](../how-to/migrations/rollback.md) for rolling back to a version.

### What if a migration fails halfway through?

On SQLite and PostgreSQL, `migrator.up` runs in one transaction, so a failure rolls the whole run back. On MySQL and CockroachDB each statement commits on its own: earlier migrations of the run stay applied and recorded, and the failing one is not recorded. Undo its partial changes by hand, fix it, and run `migrator.up` again. See [Fix Migration Errors](../how-to/troubleshooting/migration-errors.md).

## Performance

### How do I avoid N+1 queries?

Preload the association instead of reading it inside a loop:

```crystal
# ❌ One query per post
Post.all.each { |post| puts post.user.try(&.name) }

# ✅ Two queries
Post.preload(:user).all.each { |post| puts post.user.try(&.name) }
```

See [Avoid N+1 Queries](../how-to/performance/n-plus-one.md) and [Optimize Queries](../how-to/performance/optimize-queries.md).

### Should I add indexes?

Index foreign key columns, and the columns your `WHERE` and `ORDER BY` clauses use most. Declare them in the schema (`index: true` on a column, or `index [...]`) or add them in a migration with `create_index`. See [Create Indexes](../how-to/migrations/indexes.md).

## Troubleshooting

### "Connection refused" error

The server is not running, or the URL names the wrong host or port. Check the server with `pg_isready` or `mysqladmin ping`, then the URL. See [Fix Connection Errors](../how-to/troubleshooting/connection-errors.md).

### "Table does not exist" error

The table was never created in this database. Run `migrator.up`, or create a declared table with `AppDB.users.create!`. See [Run Migrations](../how-to/migrations/run-migrations.md).

### Validation failed, but I don't know why

`save`, `save!` and the instance method `record.create!` raise `CQL::ActiveRecord::Validations::ValidationError`, whose message joins the errors; the class method `User.create!(...)` does not validate. To inspect the errors without `rescue`:

```crystal
user = User.new("", "ada@example.com")
unless user.valid?
  user.errors.each { |error| puts "#{error.field}: #{error.message}" }
end
# name: name must be present
```

See [Fix Validation Errors](../how-to/troubleshooting/validation-errors.md).

## Best Practices

### Should I use `save` or `save!`?

- `save` returns `false` when a `before_*` callback returns `false`; `save!` raises `CQL::RecordNotSaved` instead.
- Both raise `CQL::ActiveRecord::Validations::ValidationError` for an invalid record, so call `valid?` first to handle validation failures without `rescue`.

See [Use Callbacks](../how-to/models/use-callbacks.md).

### When should I use transactions?

When several writes must succeed or fail together; an exception in the block rolls them all back:

```crystal
User.transaction do
  user = User.create!(name: "Ada", email: "ada@example.com")
  Profile.create!(user_id: user.id!, country: "UK")
end
```

See [Use Transactions](../how-to/data-operations/transactions.md).

### How do I test my models?

Use a separate test database and empty the tables between examples; `User.delete_all` sends one `DELETE FROM users` without callbacks:

```crystal
before_each do
  User.delete_all
end

it "creates a user" do
  user = User.create!(name: "Test", email: "test@example.com")
  user.id.should_not be_nil
end
```

See [Test Models](../how-to/testing/test-models.md) and [Set Up Test Databases](../how-to/testing/test-database.md).
