# Quick Reference

Essential CQL patterns for quick reference.

## Schema Definition

```crystal
MyDB = CQL::Schema.define(
  :my_db,
  adapter: CQL::Adapter::Postgres,  # or SQLite, MySql
  uri: "postgres://localhost/myapp"
) do
end

MyDB.init
```

## Model Definition

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :users

  property id : Int64?
  property name : String
  property email : String
  property created_at : Time?
  property updated_at : Time?

  def initialize(@name : String, @email : String)
  end
end
```

## CRUD Operations

```crystal
# Create
user = User.create!(name: "John", email: "john@example.com")

# Read
user = User.find(1)
user = User.find_by(email: "john@example.com")
users = User.where(active: true).all

# Update
user.name = "Jane"
user.save!

# Delete
user.delete!
```

## Querying

```crystal
# Basic queries
User.all
User.first
User.last
User.count

# Where clauses
User.where(active: true).all
User.where { age > 18 }.all
User.where { name.like("%john%") }.all

# Chaining
User.where(active: true)
    .order(created_at: :desc)
    .limit(10)
    .all
```

## Relationships

```crystal
# Define
belongs_to :user, User, foreign_key: :user_id
has_one :profile, Profile, foreign_key: :user_id
has_many :posts, Post, foreign_key: :user_id

# Use
user.posts.all
post.user
```

## Validations

```crystal
validate :name, presence: true
validate :email, required: true, match: /@/
validate :age, gt: 0, lt: 150
validate :status, in: ["active", "pending"]
```

## Callbacks

```crystal
before_save :normalize_data
after_create :send_notification
before_destroy :cleanup
```

## Migrations

```crystal
class CreateUsers < CQL::Migration(1)
  def up
    schema.table :users do
      primary :id, Int64, auto_increment: true
      column :name, String, null: false
      timestamps
    end
    schema.users.create!
  end

  def down
    schema.users.drop!
  end
end
```

## Run Migrations

```crystal
config = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  auto_sync: true
)

migrator = MyDB.migrator(config)
migrator.up
```

## Transactions

```crystal
User.transaction do
  user = User.create!(name: "John", email: "john@example.com")
  Profile.create!(user_id: user.id.not_nil!)
end
```

## Soft Deletes

```crystal
include CQL::ActiveRecord::SoftDeletable

user.delete!      # Soft delete
user.restore!     # Restore
user.force_delete!  # Permanent delete

User.with_deleted.all
User.only_deleted.all
```

## Optimistic Locking

```crystal
include CQL::ActiveRecord::OptimisticLocking
optimistic_locking version_column: :version

begin
  user.update!
rescue CQL::OptimisticLockError
  user.reload!
  # Retry
end
```

## Connection Strings

```crystal
# PostgreSQL
"postgres://user:pass@host:5432/database"

# MySQL
"mysql://user:pass@host:3306/database"

# SQLite
"sqlite3://./db/app.db"
"sqlite3://:memory:"
```
