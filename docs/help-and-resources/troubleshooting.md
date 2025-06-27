---
icon: life-ring
---

# Troubleshooting

Quick solutions for common issues when working with CQL.

## Setup & Installation Issues

### Shard Installation Fails

**Error:** `Failed to resolve dependencies`

**Solution:**

1. Check Crystal version compatibility: `crystal --version`
2.  Update `shard.yml` with compatible version:

    ```yaml
    dependencies:
      cql:
        github: azutoolkit/cql
        version: "~> 1.0"
    ```
3. Install with: `shards install`

### Database Driver Not Found

**Error:** `can't load file 'pg'`

**Solution:** Add the database driver to `shard.yml`:

```yaml
dependencies:
  # PostgreSQL
  pg:
    github: will/crystal-pg
  # MySQL
  mysql:
    github: crystal-lang/crystal-mysql
  # SQLite
  sqlite3:
    github: crystal-lang/crystal-sqlite3
```

## Database Connection Problems

### Connection Refused

**Error:** `Connection refused (Errno)`

**Solutions:**

1.  Verify database is running:

    ```bash
    # PostgreSQL
    pg_isready -h localhost -p 5432

    # MySQL
    mysqladmin ping -h localhost
    ```
2.  Check connection string format:

    ```crystal
    # Correct
    "postgres://username:password@localhost:5432/database"
    "mysql://username:password@localhost:3306/database"
    "sqlite3:///path/to/database.db"
    ```
3.  Test connection manually:

    ```crystal
    begin
      DB.open("postgres://user:pass@localhost/dbname") do |db|
        result = db.scalar("SELECT 1")
        puts "Connection successful: #{result}"
      end
    rescue ex
      puts "Connection failed: #{ex.message}"
    end
    ```

### Authentication Failed

**Error:** `password authentication failed`

**Solutions:**

1.  Test credentials manually:

    ```bash
    psql -h localhost -U username -d database_name
    mysql -h localhost -u username -p database_name
    ```
2.  Use environment variables:

    ```crystal
    uri: ENV["DATABASE_URL"]? || "postgres://localhost:5432/myapp_dev"
    ```
3.  Create database user if needed:

    ```sql
    -- PostgreSQL
    CREATE USER myapp_user WITH PASSWORD 'password';
    GRANT ALL PRIVILEGES ON DATABASE myapp_dev TO myapp_user;

    -- MySQL
    CREATE USER 'myapp_user'@'localhost' IDENTIFIED BY 'password';
    GRANT ALL PRIVILEGES ON myapp_dev.* TO 'myapp_user'@'localhost';
    ```

## Schema & Migration Issues

### Column Not Found Error

**Error:** `undefined method 'name' for #<NamedTuple(id: Int64)>`

**Solution:** Ensure schema matches database:

```crystal
# Complete schema definition
table :users do
  primary :id, Int64
  column :name, String
  column :email, String
  timestamps
end
```

Verify with: `crystal run db/migrate.cr`

### Migration Fails - Column Exists

**Error:** `column "email" already exists`

**Solution:** Check before adding columns:

```crystal
class AddEmailToUsers < CQL::Migration
  def up
    unless column_exists?(:users, :email)
      alter_table :users do
        add_column :email, String
      end
    end
  end
end
```

## Query & Model Issues

### Type Mismatch Errors

**Error:** `no overload matches 'User#new'`

**Solution:** Use proper type casting:

```crystal
# Safe casting
user = User.new(
  name: params["name"]?.try(&.as(String)) || "",
  email: params["email"]?.try(&.as(String)) || "",
  age: params["age"]?.try(&.as(String).to_i?) || 0
)
```

### Records Not Found

**Error:** `DB::NoResultsError`

```crystal
# ❌ Missing column
table :users do
  primary :id, Int64
  # Missing: column :name, String
end

# ✅ Complete definition
table :users do
  primary :id, Int64
  column :name, String
  column :email, String
  timestamps
end
```

2.  **Check if migration was run:**

    ```bash
    # Run pending migrations
    crystal run db/migrate.cr
    ```
3.  **Verify table structure:**

    ```sql
    -- PostgreSQL
    \d users

    -- MySQL
    DESCRIBE users;

    -- SQLite
    .schema users
    ```

### ❌ Issue: Migration Fails with Column Already Exists

```
Error: PQ::PQError: ERROR: column "email" of relation "users" already exists
```

**Solutions:**

1.  **Check existing columns before adding:**

    ```crystal
    # In migration
    alter_table :users do
      add_column :email, String unless column_exists?(:email)
    end
    ```
2.  **Use conditional migrations:**

    ```crystal
    class AddEmailToUsers < CQL::Migration
      def up
        unless column_exists?(:users, :email)
          alter_table :users do
            add_column :email, String
          end
        end
      end

      def down
        if column_exists?(:users, :email)
          alter_table :users do
            drop_column :email
          end
        end
      end
    end
    ```
3.  **Reset and rebuild database (development only):**

    ```bash
    # ⚠️ This will destroy all data!
    crystal run db/drop.cr
    crystal run db/create.cr
    crystal run db/migrate.cr
    ```

***

## 🔍 Query & Model Issues

### ❌ Issue: Type Mismatch Errors

```
Error: no overload matches 'User#new' with type Hash(String, DB::Any)
```

**Solution:**

1.  **Ensure proper type casting:**

    ```crystal
    # ❌ Wrong type handling
    user = User.new(params)  # params might have wrong types

    # ✅ Proper type casting
    user = User.new(
      name: params["name"].as(String),
      email: params["email"].as(String),
      age: params["age"].as(String).to_i
    )
    ```
2.  **Use safe casting with validation:**

    ```crystal
    # ✅ Safe casting
    def create_user(params)
      user = User.new(
        name: params["name"]?.try(&.as(String)) || "",
        email: params["email"]?.try(&.as(String)) || "",
        age: params["age"]?.try(&.as(String).to_i?) || 0
      )

      # Validate before saving
      if user.valid?
        user.save!
      else
        puts "Validation errors: #{user.errors.full_messages}"
      end
    end
    ```

### ❌ Issue: Records Not Found

```
Error: DB::NoResultsError
```

**Debugging Steps:**

1.  **Use safe find methods:**

    ```crystal
    # ❌ Unsafe - raises if not found
    user = User.find!(id)

    # ✅ Safe - returns nil if not found
    user = User.find(id)
    if user
      puts "Found: #{user.name}"
    else
      puts "User not found with ID: #{id}"
    end
    ```
2.  **Check your query conditions:**

    ```crystal
    # Debug your queries
    query = User.where(email: email)
    puts "SQL: #{query.to_sql}"  # See the generated SQL

    result = query.first
    puts result ? "Found user" : "No user found"
    ```
3.  **Verify data exists:**

    ```crystal
    # Check if any data exists
    total_users = User.count
    puts "Total users in database: #{total_users}"

    # List all users (for debugging)
    User.all.each_with_index do |user, i|
      puts "#{i + 1}. #{user.name} (#{user.email})"
    end
    ```

### ❌ Issue: Association Loading Problems

```
Error: undefined method 'posts' for User
```

**Solution:**

1.  **Verify association is defined:**

    ```crystal
    struct User
      include CQL::ActiveRecord::Model(Int64)
      db_context UserDB, :users

      # ✅ Define the association
      has_many :posts, Post, foreign_key: :user_id

      property id : Int64?
      property name : String
      property email : String
    end
    ```
2.  **Check foreign key setup:**

    ```crystal
    struct Post
      include CQL::ActiveRecord::Model(Int64)
      db_context UserDB, :posts

      # ✅ Make sure foreign key column exists
      property user_id : Int64?
      property title : String
      property content : String

      belongs_to :user, User
    end
    ```

***

## ⚠️ Runtime Errors

### ❌ Issue: Validation Errors Not Displayed

```crystal
user = User.new(name: "", email: "invalid")
user.save  # Returns false but no error details shown
```

**Solution:**

1.  **Always check validation errors:**

    ```crystal
    user = User.new(name: "", email: "invalid")

    if user.save
      puts "✅ User saved successfully!"
    else
      puts "❌ Validation failed:"
      user.errors.full_messages.each do |error|
        puts "  - #{error}"
      end
    end
    ```
2.  **Use save! for development debugging:**

    ```crystal
    begin
      user.save!  # Will raise with detailed error
    rescue CQL::RecordInvalid => ex
      puts "Validation errors:"
      ex.record.errors.full_messages.each { |msg| puts "  - #{msg}" }
    end
    ```

### ❌ Issue: Transaction Rollback Problems

```crystal
# Transaction doesn't rollback as expected
```

**Solution:**

1.  **Ensure exceptions are raised:**

    ```crystal
    UserDB.transaction do
      user1.save!  # Use ! methods to raise on failure
      user2.save!

      # Explicitly raise for business logic errors
      raise "Business rule violation" if some_condition
    end
    ```
2.  **Handle rollback explicitly:**

    ```crystal
    UserDB.transaction do |tx|
      begin
        user1.save!
        user2.save!

        # Some complex logic that might fail
        raise "Error" if validation_fails

      rescue ex
        puts "Rolling back transaction: #{ex.message}"
        tx.rollback
        raise ex  # Re-raise to exit transaction block
      end
    end
    ```

***

## ⚡ Performance Issues

### ❌ Issue: Slow Queries

**Debugging Steps:**

1.  **Enable query logging:**

    ```crystal
    # In your schema definition
    schema = CQL::Schema.define(:myapp, adapter: adapter, uri: uri) do
      # Enable logging in development
      log_level = :debug if ENV["ENV"]? == "development"
    end
    ```
2.  **Analyze query performance:**

    ```crystal
    # Time your queries
    start_time = Time.monotonic
    users = User.where(active: true).limit(100).all
    duration = Time.monotonic - start_time
    puts "Query took: #{duration.total_milliseconds}ms"
    ```
3.  **Check for N+1 queries:**

    ```crystal
    # ❌ N+1 problem
    users = User.all
    users.each do |user|
      puts user.posts.count  # Triggers one query per user
    end

    # ✅ Use eager loading (when available)
    users = User.join(:posts).all
    users.each do |user|
      puts user.posts.count  # Posts already loaded
    end
    ```

### ❌ Issue: High Memory Usage

**Solutions:**

1.  **Use pagination for large datasets:**

    ```crystal
    # ❌ Loading all records
    users = User.all  # Could load millions of records

    # ✅ Use pagination
    page_size = 100
    offset = 0

    loop do
      batch = User.limit(page_size).offset(offset).all
      break if batch.empty?

      batch.each { |user| process_user(user) }
      offset += page_size
    end
    ```
2.  **Use select to limit columns:**

    ```crystal
    # ❌ Loading all columns
    users = User.all

    # ✅ Load only needed columns
    users = User.select(:id, :name, :email).all
    ```

***

## 🛠️ Development Tips

### 🔍 Debugging Techniques

1.  **Enable SQL logging:**

    ```crystal
    # See generated SQL queries
    users = User.where(active: true)
    puts users.to_sql  # Shows: ["SELECT * FROM users WHERE active = ?", [true]]
    ```
2.  **Inspect model state:**

    ```crystal
    user = User.new(name: "Test")
    puts "New record? #{user.new_record?}"
    puts "Persisted? #{user.persisted?}"
    puts "Valid? #{user.valid?}"
    puts "Errors: #{user.errors.full_messages}"
    ```
3.  **Check database state:**

    ```crystal
    # Verify database connection
    puts "Tables: #{MySchema.tables.keys}"

    # Check record counts
    puts "Users: #{User.count}"
    puts "Posts: #{Post.count}"
    ```

### ⚡ Quick Fixes

1.  **Reset database in development:**

    ```bash
    # ⚠️ Development only!
    rm db/development.sqlite3  # For SQLite
    crystal run db/migrate.cr
    crystal run db/seed.cr     # If you have a seed file
    ```
2.  **Clear and rebuild schema cache:**

    ```crystal
    # Force schema reload
    MySchema.build
    ```
3.  **Check for pending migrations:**

    ```crystal
    # In your application
    pending = MySchema.pending_migrations
    if pending.any?
      puts "⚠️ Pending migrations: #{pending.map(&.version)}"
    end
    ```

***

## 🆘 Getting More Help

### 📚 Additional Resources

* [**CQL Documentation**](../../) - Complete documentation
* [**GitHub Issues**](https://github.com/azutoolkit/cql/issues) - Report bugs or get help
* [**Crystal Forum**](https://forum.crystal-lang.org/) - Community discussions
* [**Crystal Discord**](https://discord.gg/crystal) - Real-time chat support

### 🐛 Reporting Issues

When reporting issues, please include:

1. **Crystal version:** `crystal --version`
2. **CQL version:** Check your `shard.yml`
3. **Database type and version**
4. **Minimal reproduction code**
5. **Full error message and stack trace**
6. **Expected vs actual behavior**

### 💡 Best Practices

* **Use transactions** for multi-step operations
* **Validate input** before database operations
* **Handle exceptions** gracefully in production
* **Use environment variables** for sensitive configuration
* **Test database operations** with proper fixtures
* **Monitor query performance** in production
* **Keep migrations reversible** when possible

***

> 💡 **Pro Tip**: Most CQL issues are related to schema mismatches or missing validations. Always verify your schema definitions match your database structure and use proper error handling patterns.

**Still stuck?** Check the [FAQ section](faqs.md) or reach out to the community for help! 🤝
