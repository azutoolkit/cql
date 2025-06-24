# Altering the Schema

## Understanding Schema Changes: What, Why, and How

Schema alteration is the process of modifying your database structure after it's already been created and contains data. Think of it like renovating a house while people are still living in it - you need to be careful, methodical, and ensure everything continues to work.

### Why Schema Changes Are Inevitable

When you first design a database, you make your best guess about what you'll need. But software evolves:

```crystal
# Week 1: Simple user system
table :users do
  primary :id, Int32
  text :name
  text :email
end

# Week 6: Need user preferences
table :users do
  primary :id, Int32
  text :name
  text :email
  text :preferences    # ← New requirement!
  bool :email_verified # ← Security requirement!
end

# Week 12: Need user roles and permissions
table :users do
  primary :id, Int32
  text :name
  text :email
  text :preferences
  bool :email_verified
  text :role           # ← Admin vs regular users
  timestamp :last_login # ← Analytics requirement
end
```

**This is normal and expected!** The key is handling these changes safely and systematically.

### Two Approaches to Schema Changes in CQL

CQL gives you two ways to modify your database schema, each suited for different situations:

```crystal
# 1. Migration-Based (Recommended for production)
class AddUserPreferences < CQL::Migration(5)
  def up
    schema.alter :users do
      add_column :preferences, String, default: "{}"
      add_column :email_verified, Bool, default: false
    end
  end
end

# 2. Direct Alteration (Good for development experimentation)
MyDB.alter :users do
  add_column :preferences, String, default: "{}"
  add_column :email_verified, Bool, default: false
end
```

**When to use which approach:**

- **Migrations**: Production apps, team projects, changes you want to track
- **Direct alterations**: Quick experiments, one-off fixes, learning CQL

---

## Core Concepts: Understanding Database Alterations

### 1. The AlterTable Operations - Your Schema Modification Toolkit

Think of `AlterTable` operations as your toolbox for database modifications. Each operation is designed for a specific type of change:

```crystal
# Your schema modification toolkit:
add_column      # Add new fields to existing tables
drop_column     # Remove fields you no longer need
rename_column   # Change field names for clarity
change_column   # Modify field types or constraints
create_index    # Speed up queries on specific fields
drop_index      # Remove indexes you no longer need
foreign_key     # Create relationships between tables
drop_foreign_key # Remove relationships
```

### 2. Schema Alteration Safety - Why Order Matters

Database alterations aren't just code changes - they affect live data. The order of operations matters:

```crystal
# ❌ Dangerous: This can lose data
schema.alter :users do
  drop_column :old_email
  add_column :email, String, null: false  # What about existing users?
end

# ✅ Safe: This preserves data
schema.alter :users do
  add_column :new_email, String, null: true      # 1. Add new column
  # Run data migration: UPDATE users SET new_email = old_email
  change_column :new_email, String, null: false  # 2. Make it required
  drop_column :old_email                          # 3. Drop old column
  rename_column :new_email, :email               # 4. Rename to final name
end
```

### 3. The Connection to Migrations - Keeping Everything in Sync

When you alter schemas through migrations, CQL automatically updates your `AppSchema.cr` file:

```crystal
# Before migration
AppSchema = CQL::Schema.define(:app_schema, ...) do
  table :users do
    primary :id, Int32
    text :name
    text :email
  end
end

# After running AddUserPreferences migration
AppSchema = CQL::Schema.define(:app_schema, ...) do
  table :users do
    primary :id, Int32
    text :name
    text :email
    text :preferences    # ← Automatically added!
    bool :email_verified # ← Automatically added!
  end
end
```

This means your Crystal code always knows the current database structure, preventing runtime errors.

---

## Learning Path: From Simple Changes to Complex Transformations

### Level 1: Adding New Columns (The Safe Start)

Adding columns is usually the safest schema change because it doesn't affect existing data:

```crystal
# Scenario: Your e-commerce app needs to track user shipping preferences
class AddShippingPreferences < CQL::Migration(3)
  def up
    schema.alter :users do
      # Always start with nullable columns for existing data
      add_column :shipping_address, String, null: true
      add_column :preferred_shipping, String, default: "standard"
      add_column :shipping_notifications, Bool, default: true
    end
  end

  def down
    schema.alter :users do
      # Remove in reverse order for safety
      drop_column :shipping_notifications
      drop_column :preferred_shipping
      drop_column :shipping_address
    end
  end
end
```

**Key learning points:**

- New columns should usually be `null: true` to accommodate existing records
- Provide sensible defaults for non-nullable columns
- Think about what happens to existing data
- Always provide a rollback path

### Level 2: Creating Indexes for Performance

As your app grows, you'll notice some queries getting slow. Indexes are your solution:

```crystal
# Scenario: Users are complaining that email login is slow
class AddEmailIndexToUsers < CQL::Migration(4)
  def up
    schema.alter :users do
      # Unique index prevents duplicate emails AND speeds up lookups
      create_index :idx_users_email, [:email], unique: true
    end
  end

  def down
    schema.alter :users do
      drop_index :idx_users_email
    end
  end
end

# Scenario: Product search by category is getting slow
class AddProductIndexes < CQL::Migration(5)
  def up
    schema.alter :products do
      # Single column index for category filtering
      create_index :idx_products_category, [:category_id]

      # Composite index for complex queries
      create_index :idx_products_category_price, [:category_id, :price]

      # Partial index for specific conditions
      create_index :idx_products_active, [:status],
        where: "status = 'active'"  # If your database supports this
    end
  end

  def down
    schema.alter :products do
      drop_index :idx_products_active
      drop_index :idx_products_category_price
      drop_index :idx_products_category
    end
  end
end
```

**Why indexes matter:**

- **Without index**: Database scans every row to find matches (slow!)
- **With index**: Database uses the index like a book's table of contents (fast!)
- **Unique indexes**: Prevent duplicate data AND improve performance
- **Composite indexes**: Optimize queries that filter on multiple columns

### Level 3: Creating Relationships Between Tables

Real applications have related data. Foreign keys maintain data integrity:

```crystal
# Scenario: Blog posts should belong to users
class CreateUserPostsRelationship < CQL::Migration(6)
  def up
    # First, add the foreign key column
    schema.alter :posts do
      add_column :user_id, Int32, null: false
    end

    # Then create the foreign key constraint
    schema.alter :posts do
      foreign_key [:user_id],
        references: :users,
        references_columns: [:id],
        on_delete: "CASCADE"  # Delete posts when user is deleted
    end

    # Finally, add an index for performance
    schema.alter :posts do
      create_index :idx_posts_user_id, [:user_id]
    end
  end

  def down
    schema.alter :posts do
      drop_index :idx_posts_user_id
      drop_foreign_key :fk_posts_user_id  # CQL auto-generates FK names
      drop_column :user_id
    end
  end
end
```

**Understanding foreign key options:**

- `on_delete: "CASCADE"`: Delete related records when parent is deleted
- `on_delete: "SET NULL"`: Set foreign key to NULL when parent is deleted
- `on_delete: "RESTRICT"`: Prevent deletion of parent if children exist
- `on_update: "CASCADE"`: Update foreign keys when parent ID changes

### Level 4: Complex Data Transformations

Sometimes you need to transform existing data, not just structure:

```crystal
# Scenario: You stored full names but now need separate first/last names
class SplitUserNames < CQL::Migration(7)
  def up
    # Step 1: Add new columns
    schema.alter :users do
      add_column :first_name, String, null: true
      add_column :last_name, String, null: true
    end

    # Step 2: Migrate data (this would be more complex in real life)
    # You'd typically do this with a data migration script
    puts "Migrating user names..."
    # MyDB.query(<<-SQL
    #   UPDATE users
    #   SET first_name = split_part(name, ' ', 1),
    #       last_name = split_part(name, ' ', 2)
    #   WHERE name IS NOT NULL
    # SQL
    # )

    # Step 3: Make new columns required and drop old one
    schema.alter :users do
      change_column :first_name, String, null: false
      change_column :last_name, String, null: false
      drop_column :name
    end
  end

  def down
    # This is complex to reverse - we'd lose data!
    schema.alter :users do
      add_column :name, String, null: true
    end

    # Reconstruct full names
    # MyDB.query("UPDATE users SET name = first_name || ' ' || last_name")

    schema.alter :users do
      change_column :name, String, null: false
      drop_column :last_name
      drop_column :first_name
    end
  end
end
```

**Data transformation best practices:**

- **Plan carefully**: Data transformations can be irreversible
- **Backup first**: Always have a recovery plan
- **Test thoroughly**: Use realistic test data
- **Consider performance**: Large data migrations can be slow
- **Batch operations**: Don't lock tables for too long

---

## Working with Existing Databases: The Bootstrap Approach

### When You Inherit a Database

Maybe you're joining a project with an existing database, or converting from another ORM. CQL's bootstrap feature creates a starting point:

```crystal
# 1. Connect to existing database
ExistingApp = CQL::Schema.define(
  :existing_app,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
) do
  # Empty - we'll discover the structure
end

# 2. Bootstrap: Generate schema from existing database
config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/existing_schema.cr",
  schema_name: :ExistingSchema,
  auto_sync: true
)

migrator = ExistingApp.migrator(config)
migrator.bootstrap_schema

puts "✅ Generated schema file from existing database!"
```

**What bootstrap gives you:**

- Complete `ExistingSchema.cr` file matching your database
- Baseline for future migrations
- Type safety for your Crystal code
- No data loss or downtime

### Adopting the Migration Workflow

After bootstrapping, future changes use migrations:

```crystal
# Now you can create migrations for new changes
class AddUserPreferencesToExistingApp < CQL::Migration(1)  # Start from 1
  def up
    schema.alter :users do
      add_column :preferences, String, default: "{}"
      add_column :timezone, String, default: "UTC"
    end
  end

  def down
    schema.alter :users do
      drop_column :timezone
      drop_column :preferences
    end
  end
end

# Apply the migration
migrator.up
# Your schema file is automatically updated!
```

---

## Environment-Specific Strategies

### Development: Fast Iteration with Safety Nets

In development, you want speed but also safety:

```crystal
# Development configuration
dev_config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/dev_schema.cr",
  schema_name: :DevSchema,
  auto_sync: true  # Automatic schema file updates
)

# Experiment with direct alterations
DevDB.alter :users do
  add_column :experimental_field, String, null: true
end

# If you like it, convert to a migration
class AddExperimentalField < CQL::Migration(8)
  def up
    schema.alter :users do
      add_column :experimental_field, String, null: true
    end
  end

  def down
    schema.alter :users do
      drop_column :experimental_field
    end
  end
end
```

### Production: Safety First

Production requires careful, controlled changes:

```crystal
# Production configuration
prod_config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/production_schema.cr",
  schema_name: :ProductionSchema,
  auto_sync: false  # Manual control for safety
)

# Production deployment process
prod_migrator = ProdDB.migrator(prod_config)

# 1. Review what will change
pending = prod_migrator.pending_migrations
puts "Changes to apply:"
pending.each { |m| puts "  - #{m.name}" }

# 2. Apply changes during maintenance window
puts "Applying migrations..."
prod_migrator.up

# 3. Verify success
unless prod_migrator.verify_schema_consistency
  puts "⚠️  Manual schema file update needed"
  # Review and then: prod_migrator.update_schema_file
end
```

---

## Common Pitfalls and How to Avoid Them

### Pitfall 1: Forgetting About Existing Data

```crystal
# ❌ This will fail if users table has existing records
schema.alter :users do
  add_column :email, String, null: false  # Error! Existing records have no email
end

# ✅ Safe approach
schema.alter :users do
  add_column :email, String, null: true           # 1. Allow null initially
  # Populate email addresses for existing users
  # MyDB.query("UPDATE users SET email = name || '@example.com' WHERE email IS NULL")
  change_column :email, String, null: false       # 2. Make required after populating
end
```

### Pitfall 2: Dropping Columns with Constraints

```crystal
# ❌ This might fail if column is referenced elsewhere
schema.alter :users do
  drop_column :old_id  # Error! Foreign keys might reference this
end

# ✅ Drop constraints first
schema.alter :posts do
  drop_foreign_key :fk_posts_user_old_id  # Drop foreign keys first
end

schema.alter :users do
  drop_column :old_id  # Now this works
end
```

### Pitfall 3: Not Testing Rollbacks

```crystal
# ❌ Rollback that doesn't work
class AddComplexChanges < CQL::Migration(9)
  def up
    schema.alter :users do
      add_column :computed_field, String, null: false
      # Complex calculation to populate field
    end
  end

  def down
    schema.alter :users do
      drop_column :computed_field  # This works, but...
      # How do we restore the computed values if we roll back and re-apply?
    end
  end
end

# ✅ Rollback that preserves data
class AddComplexChanges < CQL::Migration(9)
  def up
    schema.alter :users do
      add_column :computed_field, String, null: true  # Allow null initially
      # Populate computed_field
      change_column :computed_field, String, null: false
    end
  end

  def down
    schema.alter :users do
      drop_column :computed_field
    end
  end
end
```

---

## Performance Considerations: Making Changes Without Breaking Things

### Index Creation on Large Tables

```crystal
# For large tables, index creation can be slow
class AddIndexesToLargeTable < CQL::Migration(10)
  def up
    # This might lock the table for minutes on large datasets
    schema.alter :large_table do
      create_index :idx_created_at, [:created_at]
    end

    # Consider:
    # 1. Create during low-traffic periods
    # 2. Use database-specific concurrent index creation if available
    # 3. Monitor the operation
  end

  def down
    schema.alter :large_table do
      drop_index :idx_created_at  # Usually fast
    end
  end
end
```

### Batching Large Data Changes

```crystal
class MigrateUserStatusBatched < CQL::Migration(11)
  def up
    # Add new column
    schema.alter :users do
      add_column :status, String, default: "active"
    end

    # Migrate data in batches to avoid long locks
    batch_size = 1000
    offset = 0

    loop do
      count = MyDB.query("
        UPDATE users
        SET status = CASE
          WHEN last_login_at > NOW() - INTERVAL '30 days' THEN 'active'
          ELSE 'inactive'
        END
        WHERE id BETWEEN #{offset} AND #{offset + batch_size}
      ").rows_affected

      break if count == 0
      offset += batch_size
      puts "Migrated #{offset} users..."
    end
  end
end
```

---

## Advanced Patterns: Real-World Scenarios

### Pattern 1: Feature Flag Columns

```crystal
# Enable new features gradually
class AddFeatureFlags < CQL::Migration(12)
  def up
    schema.alter :users do
      add_column :beta_features_enabled, Bool, default: false
      add_column :feature_flags, String, default: "{}"  # JSON storage
    end

    # Create index for feature flag queries
    schema.alter :users do
      create_index :idx_users_beta_features, [:beta_features_enabled]
    end
  end

  def down
    schema.alter :users do
      drop_index :idx_users_beta_features
      drop_column :feature_flags
      drop_column :beta_features_enabled
    end
  end
end
```

### Pattern 2: Data Archival Preparation

```crystal
# Prepare for archiving old data
class AddArchivalFields < CQL::Migration(13)
  def up
    schema.alter :orders do
      add_column :archived_at, Time, null: true
      add_column :archival_reason, String, null: true
    end

    # Index for finding archived vs active records
    schema.alter :orders do
      create_index :idx_orders_archived, [:archived_at]
      # Partial index for active records only
      create_index :idx_orders_active, [:created_at],
        where: "archived_at IS NULL"
    end
  end

  def down
    schema.alter :orders do
      drop_index :idx_orders_active
      drop_index :idx_orders_archived
      drop_column :archival_reason
      drop_column :archived_at
    end
  end
end
```

### Pattern 3: Gradual Column Replacement

```crystal
# Replace a column without losing data
class ReplaceUserIdWithUuid < CQL::Migration(14)
  def up
    # Phase 1: Add new UUID column
    schema.alter :users do
      add_column :uuid, String, null: true
    end

    # Phase 2: Populate UUIDs (in a real app, you'd generate proper UUIDs)
    # MyDB.query("UPDATE users SET uuid = 'user_' || id::text WHERE uuid IS NULL")

    # Phase 3: Make UUID required
    schema.alter :users do
      change_column :uuid, String, null: false
      create_index :idx_users_uuid, [:uuid], unique: true
    end

    # Phase 4: Update foreign keys (this would be done in separate migrations)
    # ... migrate all references from id to uuid

    # Phase 5: Remove old id column (in a future migration after all references updated)
    # schema.alter :users do
    #   drop_column :id
    #   rename_column :uuid, :id
    # end
  end

  def down
    # This is complex - document carefully!
    schema.alter :users do
      drop_index :idx_users_uuid
      drop_column :uuid
    end
  end
end
```

---

## Debugging Schema Changes

### Understanding What Went Wrong

```crystal
# Check current schema state
migrator = MyDB.migrator(config)

# See what migrations have been applied
puts "Applied migrations:"
migrator.applied_migrations.each { |m| puts "  ✅ #{m.name}" }

# See what's pending
puts "Pending migrations:"
migrator.pending_migrations.each { |m| puts "  ⏳ #{m.name}" }

# Check if schema file matches database
unless migrator.verify_schema_consistency
  puts "⚠️  Schema file out of sync with database"
  puts "Database has changes not reflected in schema file"
end
```

### Common Error Messages and Solutions

```crystal
# Error: "relation 'users' does not exist"
# Solution: Make sure table creation migration ran first
migrator.up_to(1)  # Apply the create_users migration

# Error: "column 'email' already exists"
# Solution: Check if migration was partially applied
# Look at actual database structure and adjust migration

# Error: "cannot drop column - constraint exists"
# Solution: Drop constraints before dropping columns
schema.alter :table do
  drop_foreign_key :constraint_name
  drop_column :column_name
end
```

---

## Complete Example: E-commerce Schema Evolution

Let's follow an e-commerce site's schema changes over time:

```crystal
# Week 1: Basic product catalog
class CreateProducts < CQL::Migration(1)
  def up
    schema.table :products do
      primary :id, Int32, auto_increment: true
      text :name, null: false
      decimal :price, precision: 10, scale: 2
      timestamp :created_at, null: true
    end
  end
end

# Week 3: Need categories
class AddProductCategories < CQL::Migration(2)
  def up
    schema.table :categories do
      primary :id, Int32, auto_increment: true
      text :name, null: false
      text :slug, null: false
    end

    schema.alter :categories do
      create_index :idx_categories_slug, [:slug], unique: true
    end

    schema.alter :products do
      add_column :category_id, Int32, null: true
      foreign_key [:category_id], references: :categories, references_columns: [:id]
    end
  end
end

# Week 6: Need inventory tracking
class AddInventoryTracking < CQL::Migration(3)
  def up
    schema.alter :products do
      add_column :stock_quantity, Int32, default: 0
      add_column :low_stock_threshold, Int32, default: 10
    end

    schema.alter :products do
      create_index :idx_products_stock, [:stock_quantity]
    end
  end
end

# Week 10: Performance issues with product searches
class OptimizeProductQueries < CQL::Migration(4)
  def up
    schema.alter :products do
      # Index for price range queries
      create_index :idx_products_price, [:price]

      # Composite index for category + price filtering
      create_index :idx_products_category_price, [:category_id, :price]

      # Full-text search preparation
      add_column :search_terms, String, null: true
    end
  end
end

# Result: A robust, performant product catalog
# Your final ProductSchema.cr automatically includes all these changes!
```

---

## Related Documentation

- [Migrations](migrations.md) - Complete migration workflow and team collaboration
- [Initializing the Database](initializing-the-database.md) - Setting up new databases and bootstrap strategies
- [Schema Dump Guide](../guides/schema-dump.md) - Working with existing databases
- [Migration Workflow Guide](../guides/active-record-with-cql/integrated-migration-workflow.md) - Advanced patterns and real-world examples

---

## Key Takeaways

1. **Schema changes are inevitable** - plan for them from the start
2. **Use migrations for tracking** - they provide version control for your database
3. **Consider existing data** - new columns should usually be nullable initially
4. **Test rollbacks** - ensure you can undo changes if something goes wrong
5. **Performance matters** - indexes can make queries thousands of times faster
6. **Safety first in production** - use manual verification and maintenance windows
7. **Bootstrap existing databases** - don't rewrite everything to adopt CQL

Schema alteration is both an art and a science. The technical operations are straightforward, but understanding when and how to use them safely requires experience. Start with simple changes, test thoroughly, and gradually work up to more complex transformations. CQL's integrated migration system makes this process as safe and straightforward as possible, but good practices and careful planning are still essential for success.
