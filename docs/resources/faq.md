# Frequently Asked Questions

## General

### What is CQL?

CQL (Crystal Query Language) is an ORM (Object-Relational Mapping) library for Crystal that provides type-safe database interactions, migrations, and Active Record patterns.

### What databases does CQL support?

CQL supports:
- PostgreSQL
- MySQL
- SQLite

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

Primary keys should be `Type?` (nullable) because new records don't have an ID until saved:

```crystal
property id : Int64?  # Correct - nil until saved
```

### How do I add a field that isn't in the database?

Use the `DB::Field(ignore: true)` annotation:

```crystal
@[DB::Field(ignore: true)]
property temp_value : String?
```

## Queries

### How do I write raw SQL?

```crystal
results = MyDB.exec("SELECT * FROM users WHERE id = ?", [1])
```

### Why is my query returning an empty array?

Check:
1. Data exists in the database
2. Your where conditions are correct
3. If using soft deletes, records might be deleted

### How do I debug what SQL is being generated?

Enable query logging:

```crystal
Log.setup do |c|
  c.bind("cql.*", :debug, Log::IOBackend.new)
end
```

## Relationships

### When do I use belongs_to vs has_many?

- `belongs_to`: The model has a foreign key column (e.g., Comment has `post_id`)
- `has_many`: The other model has the foreign key (e.g., Post has many Comments)

### How do I eager load associations?

Load related IDs first, then batch load:

```crystal
posts = Post.where(published: true).all
user_ids = posts.map(&.user_id).uniq
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
migrator.down       # Rollback one
migrator.down_to(3) # Rollback to version 3
```

### What if a migration fails halfway through?

Manually check the database state, fix any issues, and potentially mark the migration as not applied:

```sql
DELETE FROM cql_schema_migrations WHERE version = 5;
```

## Performance

### How do I avoid N+1 queries?

Load related data in batches:

```crystal
# Bad: N+1
posts.each { |p| puts p.user.name }

# Good: Batch load
user_ids = posts.map(&.user_id).uniq
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

Check the errors array:

```crystal
unless model.valid?
  model.errors.each do |e|
    puts "#{e.field}: #{e.message}"
  end
end
```

## Best Practices

### Should I use `save` or `save!`?

- Use `save` when you want to handle failure gracefully
- Use `save!` when failure should raise an exception

### When should I use transactions?

When multiple operations must succeed or fail together:

```crystal
User.transaction do
  user = User.create!(...)
  Profile.create!(user_id: user.id.not_nil!)
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
