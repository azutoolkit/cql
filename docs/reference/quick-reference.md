# Quick Reference

Essential CQL patterns for quick reference.

## Schema Definition

```crystal
MyDB = CQL::Schema.define(
  :my_db,
  adapter: CQL::Adapter::Postgres,  # or SQLite, MySql, CockroachDB
  uri: "postgres://localhost/myapp"
) do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String
    column :email, String
    timestamps
  end
end
```

## Model Definition

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  # db_context is optional: User maps to :users, in the schema whose define block declares it.
  # One argument overrides just that part: db_context table: :people, db_context schema: MyDB
  # Both: db_context MyDB, :users

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
user = User.find(1)             # => User? (nil when missing)
user = User.find!(1)            # raises DB::NoResultsError
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
User.where { age > 18 }.all                        # typed columns, checked at compile time
User.where { (age >= 18) & (status == "active") }.all
User.where { name.like("%john%") }.all
User.where("lower(email) = ?", "john@example.com").all

# Chaining
User.where(active: true)
    .order(created_at: :desc)
    .limit(10)
    .all

# Typed ordering, joins through associations and partial selects
User.query
    .joins(:posts) { posts.published == true }
    .order_by(created_at: :desc)
    .select(:id, :name)
    .to_a

# Pagination and loading
User.page(2, per_page: 20)
User.preload(:posts).all          # has_many, belongs_to, has_one
User.where(active: true).pluck(:email, as: String)

# Scopes
scope :active, -> { where(active: true) }
User.active.recent.all
```

## Relationships

```crystal
# Define
belongs_to :user, User, :user_id
has_one :profile, Profile, :user_id
has_many :posts, Post, :user_id

# Use
user.posts.all                    # Array(Post)
user.posts.create(title: "Hi")    # sets user_id for you
post.user                         # => User? (optional: true by default)
```

`has_many` also takes `foreign_key:` and `dependent:` (`:nullify`, `:destroy`, `:delete_all`, `:restrict_with_error`); `many_to_many :tags, Tag, join_through: PostTag` uses a join model.

Relationship declarations are compile-time checked. `belongs_to` and `has_many` raise CQL-specific compile errors when foreign-key and primary-key types do not match:

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)
end

class Post
  include CQL::ActiveRecord::Model(Int32)

  property user_id : Int32?

  # Compile-time error: user_id must match User's Int64 primary key.
  belongs_to :user, User, :user_id
end
```

## Schema Mapping Validation

```bash
CQL_VALIDATE_SCHEMA_MAPPINGS=1 crystal run src/app.cr
```

When enabled, CQL checks model getter types against the model's schema table (from `db_context`, or inferred) and raises `CQL schema mapping error` for mismatches.

## Validations

```crystal
validate :name, presence: true
validate :email, required: true, match: /@/
validate :age, gt: 0, lt: 150
validate :status, in: ["active", "pending"]
validate :username, presence: true, size: 3..20, message: "is invalid"   # one call per property
use PasswordValidator                                                    # custom validator class
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
  Profile.create!(user_id: user.id!)
end
```

## Soft Deletes

```crystal
include CQL::ActiveRecord::SoftDeletable

user.delete!        # Soft delete
user.restore!       # Restore
user.force_delete!  # Permanent delete

User.with_deleted.all
User.only_deleted.all
```

## Optimistic Locking

```crystal
include CQL::ActiveRecord::OptimisticLocking
optimistic_locking version_column: :version   # version property is an Int32 (the lock_version column), whatever the primary key type

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

# CockroachDB
"cockroachdb://user:pass@host:26257/database"

# SQLite
"sqlite3://./db/app.db"
"sqlite3::memory:"
```
