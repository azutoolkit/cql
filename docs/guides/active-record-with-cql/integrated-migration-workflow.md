# Integrated Migration Workflow with Active Record

This guide demonstrates CQL's integrated migration system that automatically maintains schema files in sync with your database changes, providing a seamless development experience when using the Active Record pattern.

## Overview

CQL's integrated workflow combines three powerful components:

1. **Migrations**: Version-controlled schema changes
2. **Schema Synchronization**: Automatic schema file updates
3. **Active Record Models**: Type-safe model definitions

This integration ensures your schema files always reflect the current database state, enabling compile-time type safety and seamless team collaboration.

---

## Quick Start Example

Here's a complete example showing the integrated workflow:

```crystal
# 1. Configure the integrated migrator
config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  schema_symbol: :app_schema,
  auto_sync: true  # Automatically update schema file after migrations
)

# 2. Initialize your base schema connection
AppDB = CQL::Schema.define(
  :app_database,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
) do
  # Tables will be managed by migrations
end

migrator = AppDB.migrator(config)

# 3. Create migrations
class CreateUsersTable < CQL::Migration(1)
  def up
    schema.table :users do
      primary :id, Int32
      column :name, String
      column :email, String
      timestamps
    end
    schema.users.create!
  end

  def down
    schema.users.drop!
  end
end

# 4. Run migrations - schema file automatically updated!
migrator.up

# 5. Use the auto-generated schema in your Active Record models
require "./src/schemas/app_schema"

class User
  include CQL::ActiveRecord::Model(Int32)
  db_context AppSchema, :users

  property id : Int32?
  property name : String
  property email : String
  property created_at : Time?
  property updated_at : Time?
end

# 6. Now you have type-safe Active Record operations
user = User.create!(name: "Alice", email: "alice@example.com")
puts user.id  # Compile-time type safety guaranteed!
```

---

## Configuration Setup

### Basic Configuration

```crystal
# Configure for automatic schema synchronization
config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",  # Where to save schema file
  schema_name: :AppSchema,                        # Constant name in schema file
  schema_symbol: :app_schema,                     # Symbol name for schema
  auto_sync: true                                 # Auto-update after migrations
)

migrator = MyDB.migrator(config)
```

### Environment-Specific Configurations

```crystal
# Development configuration
dev_config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  schema_symbol: :app_schema,
  auto_sync: true  # Rapid iteration with automatic updates
)

# Production configuration
prod_config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/production_schema.cr",
  schema_name: :ProductionSchema,
  schema_symbol: :production_schema,
  auto_sync: false  # Manual control for safety
)

# Test configuration
test_config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/test_schema.cr",
  schema_name: :TestSchema,
  schema_symbol: :test_schema,
  auto_sync: true
)
```

---

## Migration Development Workflow

### 1. Initial Bootstrap (Existing Database)

Start with an existing database by bootstrapping your schema file:

```crystal
# Bootstrap from existing database
migrator.bootstrap_schema

# This generates src/schemas/app_schema.cr with current database structure
```

**Generated AppSchema.cr:**

```crystal
AppSchema = CQL::Schema.define(
  :app_schema,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]) do

  table :users do
    primary :id, Int32
    text :name
    text :email
    timestamps
  end
end
```

### 2. Creating Models from Generated Schema

Once you have the schema file, create Active Record models:

```crystal
# models/user.cr
require "../src/schemas/app_schema"

class User
  include CQL::ActiveRecord::Model(Int32)
  db_context AppSchema, :users

  # Properties match the generated schema
  property id : Int32?
  property name : String
  property email : String
  property created_at : Time?
  property updated_at : Time?

  # Validations
  validate :name, presence: true, size: 2..50
  validate :email, presence: true, match: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
end
```

### 3. Adding New Features with Migrations

Create migrations to add new features:

```crystal
# migrations/002_add_user_profile.cr
class AddUserProfile < CQL::Migration(2)
  def up
    # Add new columns to existing table
    schema.alter :users do
      add_column :bio, String, null: true
      add_column :avatar_url, String, null: true
      add_column :active, Bool, default: true
    end

    # Create new related table
    schema.table :user_preferences do
      primary :id, Int32
      column :user_id, Int32
      column :notifications, Bool, default: true
      column :theme, String, default: "light"
      timestamps

      foreign_key [:user_id], references: :users, references_columns: [:id], on_delete: :cascade
    end
    schema.user_preferences.create!
  end

  def down
    schema.user_preferences.drop!
    schema.alter :users do
      drop_column :bio
      drop_column :avatar_url
      drop_column :active
    end
  end
end

# Apply migration - schema file automatically updated!
migrator.up
```

### 4. Updated Models After Migration

After running the migration, update your models to use the new schema:

```crystal
# models/user.cr - Updated after migration
class User
  include CQL::ActiveRecord::Model(Int32)
  db_context AppSchema, :users

  # Original properties
  property id : Int32?
  property name : String
  property email : String

  # New properties from migration
  property bio : String?
  property avatar_url : String?
  property active : Bool = true

  property created_at : Time?
  property updated_at : Time?

  # Relationships
  has_one :preferences, UserPreferences, dependent: :destroy

  # Validations
  validate :name, presence: true, size: 2..50
  validate :email, presence: true, match: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
end

# models/user_preferences.cr - New model
class UserPreferences
  include CQL::ActiveRecord::Model(Int32)
  db_context AppSchema, :user_preferences

  property id : Int32?
  property user_id : Int32
  property notifications : Bool = true
  property theme : String = "light"
  property created_at : Time?
  property updated_at : Time?

  belongs_to :user, User

  validate :theme, in: ["light", "dark"]
end
```

---

## Advanced Migration Patterns

### Complex Schema Changes

```crystal
class RefactorUserSystem < CQL::Migration(3)
  def up
    # Create new tables first
    schema.table :profiles do
      primary :id, Int32
      column :user_id, Int32
      column :first_name, String
      column :last_name, String
      column :bio, String, null: true
      timestamps

      foreign_key [:user_id], references: :users, references_columns: [:id]
    end
    schema.profiles.create!

    # Migrate data (in production, do this carefully)
    schema.exec_query do |conn|
      conn.query_each("SELECT id, name, bio FROM users") do |rs|
        user_id = rs.read(Int32)
        name_parts = rs.read(String).split(" ", 2)
        bio = rs.read(String?)

        first_name = name_parts[0]? || ""
        last_name = name_parts[1]? || ""

        conn.exec(
          "INSERT INTO profiles (user_id, first_name, last_name, bio, created_at, updated_at) VALUES ($1, $2, $3, $4, NOW(), NOW())",
          user_id, first_name, last_name, bio
        )
      end
    end

    # Remove old columns
    schema.alter :users do
      drop_column :name
      drop_column :bio
    end
  end

  def down
    # Reverse the changes
    schema.alter :users do
      add_column :name, String
      add_column :bio, String, null: true
    end

    # Migrate data back
    schema.exec_query do |conn|
      conn.query_each("SELECT user_id, first_name, last_name, bio FROM profiles") do |rs|
        user_id = rs.read(Int32)
        first_name = rs.read(String)
        last_name = rs.read(String)
        bio = rs.read(String?)

        full_name = "#{first_name} #{last_name}".strip

        conn.exec(
          "UPDATE users SET name = $1, bio = $2 WHERE id = $3",
          full_name, bio, user_id
        )
      end
    end

    schema.profiles.drop!
  end
end
```

### Adding Indexes for Performance

```crystal
class AddPerformanceIndexes < CQL::Migration(4)
  def up
    schema.alter :users do
      create_index :idx_users_email, [:email], unique: true
      create_index :idx_users_active, [:active]
    end

    schema.alter :user_preferences do
      create_index :idx_preferences_user_id, [:user_id]
      create_index :idx_preferences_theme, [:theme]
    end
  end

  def down
    schema.alter :user_preferences do
      drop_index :idx_preferences_user_id
      drop_index :idx_preferences_theme
    end

    schema.alter :users do
      drop_index :idx_users_email
      drop_index :idx_users_active
    end
  end
end
```

---

## Team Collaboration Workflow

### 1. Developer Workflow

```crystal
# When starting work on a feature
git pull origin main
migrator.up  # Apply any new migrations
migrator.verify_schema_consistency  # Ensure schema file is current

# Create your migration
class AddUserRoles < CQL::Migration(5)
  def up
    schema.alter :users do
      add_column :role, String, default: "user"
    end
  end

  def down
    schema.alter :users do
      drop_column :role
    end
  end
end

# Apply and test your migration
migrator.up  # Schema file automatically updated

# Update your models
class User
  # ... existing properties ...
  property role : String = "user"

  validate :role, in: ["user", "admin", "moderator"]
end

# Commit both migration and updated schema file
git add migrations/005_add_user_roles.cr
git add src/schemas/app_schema.cr
git commit -m "Add user roles system"
```

### 2. Code Review Process

```crystal
# Reviewer can verify schema consistency
migrator.verify_schema_consistency
# => true (schema file matches database after migrations)

# Check what migrations will be applied
migrator.print_pending_migrations

# Apply and verify
migrator.up
puts "Schema file represents database: #{migrator.verify_schema_consistency}"
```

### 3. Deployment Workflow

```crystal
# Production deployment configuration
prod_config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/production_schema.cr",
  schema_name: :ProductionSchema,
  auto_sync: false  # Manual control in production
)

prod_migrator = ProductionDB.migrator(prod_config)

# 1. Apply migrations
prod_migrator.up

# 2. Verify consistency
unless prod_migrator.verify_schema_consistency
  puts "WARNING: Schema file out of sync!"
  # Manual update if needed
  prod_migrator.update_schema_file
end

# 3. Deploy application with updated schema file
```

---

## Integration with Active Record Features

### Relationships with Generated Schema

```crystal
# The integrated workflow makes relationships easy
class User
  include CQL::ActiveRecord::Model(Int32)
  db_context AppSchema, :users  # Uses auto-generated schema

  has_many :posts, Post, dependent: :destroy
  has_one :profile, Profile, dependent: :destroy
  has_many :comments, Comment, dependent: :destroy

  # The schema file ensures all foreign keys exist
end

class Post
  include CQL::ActiveRecord::Model(Int32)
  db_context AppSchema, :posts

  belongs_to :user, User
  has_many :comments, Comment, dependent: :destroy

  # Schema file guarantees foreign key constraints
end
```

### Validations Based on Schema

```crystal
# Schema file provides compile-time guarantees
class User
  # Schema: column :email, String (not null)
  validate :email, presence: true  # Matches schema constraint

  # Schema: column :age, Int32, null: true
  validate :age, gt: 0, lt: 120, allow_nil: true  # Matches nullable

  # Schema: column :role, String, default: "user"
  validate :role, in: ["user", "admin"], allow_blank: false
end
```

### Scopes with Schema Awareness

```crystal
class User
  include CQL::ActiveRecord::Model(Int32)
  db_context AppSchema, :users

  # Schema file ensures these columns exist
  scope :active, -> { where(active: true) }
  scope :by_role, ->(role : String) { where(role: role) }
  scope :recent, -> { order(:created_at, :desc) }

  # Compile-time verification of column names
end
```

---

## Manual Schema Operations

### Manual Schema Updates

```crystal
# Force update schema file to match current database
migrator.update_schema_file

# Verify schema file matches database
consistent = migrator.verify_schema_consistency
unless consistent
  puts "Schema file is out of sync with database"
  puts "Run: migrator.update_schema_file"
end
```

### Schema Inspection

```crystal
# Get current schema content
schema_dumper = AppDB.schema_dumper
current_schema = schema_dumper.generate_schema_content(:AppSchema, :app_schema)
puts current_schema

# Compare with existing file
if File.exists?("src/schemas/app_schema.cr")
  existing_schema = File.read("src/schemas/app_schema.cr")
  if current_schema == existing_schema
    puts "✅ Schema file is up to date"
  else
    puts "❌ Schema file needs updating"
  end
end
```

---

## Best Practices

### 1. Version Control Integration

```bash
# Always commit both migrations and schema files together
git add migrations/
git add src/schemas/app_schema.cr
git commit -m "Add user authentication system

- Add users table with email/password
- Add sessions table for authentication
- Update schema file automatically"
```

### 2. CI/CD Pipeline Integration

```crystal
# In your CI/CD pipeline
migrator = AppDB.migrator(config)

# Ensure migrations are applied
migrator.up

# Verify schema consistency
unless migrator.verify_schema_consistency
  puts "❌ DEPLOYMENT FAILED: Schema file out of sync"
  exit(1)
end

puts "✅ Database and schema file are synchronized"
```

### 3. Development Environment Setup

```crystal
# db/setup.cr - New developer setup script
require "../src/config/database"

def setup_development_database
  puts "Setting up development database..."

  # Apply all migrations
  migrator = AppDB.migrator
  migrator.up

  # Verify everything is consistent
  if migrator.verify_schema_consistency
    puts "✅ Development database ready!"
  else
    puts "❌ Schema inconsistency detected"
    migrator.update_schema_file
    puts "Schema file updated"
  end
end

setup_development_database
```

### 4. Model Generation

```crystal
# After running migrations, generate model templates
def generate_model_template(table_name : Symbol)
  schema_file = File.read("src/schemas/app_schema.cr")

  # Parse schema and generate model template
  puts "class #{table_name.to_s.camelcase}"
  puts "  include CQL::ActiveRecord::Model(Int32)"
  puts "  db_context AppSchema, :#{table_name}"
  puts ""
  puts "  # Properties based on current schema"
  puts "  # Add your properties here based on the generated schema"
  puts "end"
end

# Generate model for new table
generate_model_template(:user_preferences)
```

---

## Troubleshooting

### Schema File Out of Sync

```crystal
# Check if schema file matches database
consistent = migrator.verify_schema_consistency

if !consistent
  puts "Schema file is out of sync with database"

  # Option 1: Update schema file to match database
  migrator.update_schema_file

  # Option 2: Check what migrations are pending
  migrator.print_pending_migrations

  # Option 3: Apply pending migrations
  migrator.up
end
```

### Migration Conflicts

```crystal
# When migration conflicts occur during team development
begin
  migrator.up
rescue ex : Exception
  puts "Migration failed: #{ex.message}"

  # Check current state
  migrator.print_applied_migrations
  migrator.print_pending_migrations

  # Resolve conflicts and retry
  puts "Resolve conflicts and run again"
end
```

### Model Compilation Errors

```crystal
# When models don't match the schema
class User
  include CQL::ActiveRecord::Model(Int32)
  db_context AppSchema, :users

  # This will cause compilation error if column doesn't exist in schema
  property non_existent_column : String  # ❌ Compile-time error

  # Solution: Check generated schema file and update model
  property name : String  # ✅ Matches schema
end
```

---

## Conclusion

The integrated migration workflow provides:

- **Automatic Schema Synchronization**: No manual schema file maintenance
- **Type Safety**: Compile-time guarantees for Active Record models
- **Team Coordination**: Consistent schema files across team members
- **Production Safety**: Manual control options for deployment
- **Developer Experience**: Seamless workflow from migration to model usage

This workflow eliminates schema drift, reduces manual errors, and provides a smooth development experience when building applications with the Active Record pattern in CQL.
