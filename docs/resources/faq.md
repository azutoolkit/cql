# Frequently Asked Questions

## General

### What is CQL?

CQL (Crystal Query Language) is an ORM (Object-Relational Mapping) library for Crystal that provides type-safe database interactions, migrations, and Active Record patterns.

### What databases does CQL support?

CQL supports:
- PostgreSQL
- MySQL
- SQLite
- CockroachDB

### Is CQL production-ready?

CQL is actively maintained and used in production applications. However, as with any library, thoroughly test your specific use case.

## Models

### Should I use `class` or `struct` for models?

Both work with CQL. Use `struct` for value semantics (recommended for most cases) or `class` if you need reference semantics.

```crystal
struct User  # Recommended
  include CQL::ActiveRecord::Model(Int64)
end
```

### Why is my primary key nullable?

Primary keys are `Type?` (nullable) because new records don't have an ID until saved. `CQL::ActiveRecord::Model(Int64)` already provides `id` (as `Int64?`), `id!` (raises when nil) and `id=`, so declaring the property yourself is optional:

```crystal
property id : Int64?  # nil until saved
user.id!              # Int64, raises when the record is unsaved
```

### How do I add a field that isn't in the database?

Use the `DB::Field(ignore: true)` annotation:

```crystal
@[DB::Field(ignore: true)]
property temp_value : String?
```

## Queries

### How do I write raw SQL?

Add a fragment with bound values to a model query:

```crystal
users = User.where("lower(email) = ? AND age > :age", "john@example.com", age: 18).all
```

For a whole statement, use a pooled connection (`MyDB.exec(sql)` runs DDL/statements and returns no rows):

```crystal
rows = MyDB.exec_query do |conn|
  conn.query_all("SELECT name, age FROM users WHERE id = ?", 1, as: {String, Int32})
end
```

### Why is my query returning an empty array?

Check:
1. Data exists in the database
2. Your where conditions are correct
3. If using soft deletes, records might be deleted

### How do I debug what SQL is being generated?

Print the SQL and bound values of a query without running it:

```crystal
User.where(active: true).query.to_sql   # => {"SELECT ... WHERE users.active = ?", [true]}
```

Or log every statement CQL runs:

```crystal
Log.setup do |c|
  c.bind("cql.*", :debug, Log::IOBackend.new)
end

CQL::Telemetry.log_queries
```

## Relationships

### When do I use belongs_to vs has_many?

- `belongs_to`: The model has a foreign key column (e.g., Comment has `post_id`)
- `has_many`: The other model has the foreign key (e.g., Post has many Comments)

### Why does my relationship fail at compile time?

CQL validates relationship metadata during compilation. A `belongs_to` or `has_many` declaration fails if the foreign key is missing, the macro arguments are malformed, or the foreign key type does not match the related model's primary key type.

For example, a `Post` with `property user_id : Int32?` cannot belong to a `User` that includes `CQL::ActiveRecord::Model(Int64)`. Change the foreign key to `Int64?` or change the related model primary key type.

### How do I check model/schema type drift?

Enable strict schema mapping validation during CI, staging, or application boot:

```bash
CQL_VALIDATE_SCHEMA_MAPPINGS=1 crystal run src/app.cr
```

This compares model getter types with the schema table configured by `db_context` and raises a clear `CQL schema mapping error` if they differ.

### How do I eager load associations?

For `has_many`, `belongs_to` and `has_one`, use `preload`:

```crystal
users = User.preload(:posts).all   # 2 queries, user.posts is already loaded
```

`preload` also loads `belongs_to` and `has_one` associations (`Post.preload(:user).all`), but ignores `many_to_many`. For those, load related IDs first, then batch load:

```crystal
posts = Post.where(published: true).all
user_ids = posts.compact_map(&.user_id).uniq
users = User.where { id.in(user_ids) }.all.index_by(&.id)
```

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

### How do I rollback a migration?

```crystal
migrator.rollback      # Rollback the last migration
migrator.rollback(2)   # Rollback the last two
migrator.down_to(3)    # Rollback until version 3 is the latest applied
migrator.down          # Rollback everything
```

### What if a migration fails halfway through?

Manually check the database state, fix any issues, and potentially mark the migration as not applied:

```sql
DELETE FROM cql_schema_migrations WHERE version = 5;
```

## Performance

### How do I avoid N+1 queries?

Preload `has_many`, `belongs_to` and `has_one` associations, and load other related data in batches:

```crystal
# Bad: N+1
posts.each { |p| puts p.user.try(&.name) }

# Good: has_many with preload (2 queries)
users = User.preload(:posts).all

# Good: belongs_to by batch load
user_ids = posts.compact_map(&.user_id).uniq
users = User.where { id.in(user_ids) }.all.index_by(&.id)
posts.each { |p| puts users[p.user_id]?.try(&.name) }
```

### Should I add indexes?

Add indexes on:
- Foreign key columns
- Columns used in WHERE clauses
- Columns used in ORDER BY

## Troubleshooting

### "Connection refused" error

The database server isn't running or the connection string is wrong. Check:
1. Database is running: `pg_isready` or `mysqladmin ping`
2. Connection string is correct

### "Table does not exist" error

Migrations haven't run. Execute:

```crystal
migrator.up
```

### "Validation failed" but I don't know why

`save`, `save!` and `create!` raise `CQL::ActiveRecord::Validations::ValidationError` (its message joins the error messages). To inspect the errors yourself:

```crystal
unless model.valid?
  model.errors.each do |e|
    puts "#{e.field}: #{e.message}"
  end
end
```

## Best Practices

### Should I use `save` or `save!`?

- `save` returns `false` when a `before_*` callback halts the save; `save!` raises `CQL::RecordNotSaved` instead
- Both raise `CQL::ActiveRecord::Validations::ValidationError` for an invalid record, so call `valid?` first if you want to handle validation failures without `rescue`

### When should I use transactions?

When multiple operations must succeed or fail together:

```crystal
User.transaction do
  user = User.create!(...)
  Profile.create!(user_id: user.id!)
end
```

### How do I test my models?

Use a test database and reset it between tests:

```crystal
before_each do
  # Clean database
  User.delete_all
end

it "creates a user" do
  user = User.create!(name: "Test", email: "test@example.com")
  user.id.should_not be_nil
end
```
