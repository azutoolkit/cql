# Quick Reference

The most used CQL calls, one line each. Every block below compiles and runs on SQLite in this order.

## Schema

```crystal
AppDB = CQL::Schema.define(:app_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://./app.db") do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String
    column :email, String
    column :age, Int32, default: 0
    column :active, Bool, default: true
    timestamps
    index [:email], unique: true
  end

  table :posts do
    primary :id, Int64, auto_increment: true
    column :user_id, Int64, null: true
    column :title, String
    column :published, Bool, default: false
  end

  table :profiles do
    primary :id, Int64, auto_increment: true
    column :user_id, Int64, null: true
    column :bio, String, default: ""
    column :lock_version, Int32, default: 1
  end

  table :comments do
    primary :id, Int64, auto_increment: true
    column :post_id, Int64
    column :body, String
    column :deleted_at, Time, null: true
  end

  table :tags do
    primary :id, Int64, auto_increment: true
    column :name, String
  end

  table :post_tags do
    primary :id, Int64, auto_increment: true
    column :post_id, Int64
    column :tag_id, Int64
  end
end

AppDB.build # CREATE TABLE IF NOT EXISTS ... for every table, then its indexes
```

## Models

```crystal
class User
  include CQL::ActiveRecord::Model(Int64) # Pk: Int32, Int64, UUID or String (ULID)
  # db_context AppDB, :users              # optional: inferred from the class name and the schema

  property name : String = ""
  property email : String = ""
  property age : Int32 = 0
  property active : Bool = true
  property created_at : Time?
  property updated_at : Time?

  has_many :posts, Post, :user_id
  has_one :profile, Profile, :user_id

  validate :name, presence: true, size: 2..50
  validate :email, required: true, match: /@/

  before_save :normalize_email

  scope :active, -> { where(active: true) }
  scope :adults, -> { where { age >= 18 } }

  def initialize # every model needs a no-argument initialize
  end

  def initialize(@name : String, @email : String)
  end

  private def normalize_email
    @email = @email.downcase
    true # false would halt the save
  end
end

class Post
  include CQL::ActiveRecord::Model(Int64)

  property user_id : Int64?
  property title : String = ""
  property published : Bool = false

  belongs_to :user, User, :user_id
  many_to_many :tags, Tag, join_through: PostTag

  def initialize(@title : String = "", @user_id : Int64? = nil) # used by user.posts.create(title:)
  end
end

class Profile
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::OptimisticLocking

  optimistic_locking version_column: :lock_version # Int32 column; default :lock_version

  property user_id : Int64?
  property bio : String = ""
  property lock_version : Int32 = 1
end

class Tag
  include CQL::ActiveRecord::Model(Int64)
  property name : String = ""
end

class PostTag
  include CQL::ActiveRecord::Model(Int64)
  property post_id : Int64 = 0
  property tag_id : Int64 = 0
end
```

| Macro | Signature | Defaults |
| :--- | :--- | :--- |
| `belongs_to` | `belongs_to :user, User, :user_id, optional: true` | optional (reader returns `User?`) |
| `has_one` | `has_one :profile, Profile, :user_id, dependent: :destroy` | `dependent: :destroy`; also `:delete`, `:nullify` |
| `has_many` | `has_many :posts, Post, :user_id, dependent: :nullify` | `dependent: :nullify`; also `:destroy`, `:delete_all`, `:restrict_with_error`; `foreign_key:` may be named |
| `many_to_many` | `many_to_many :tags, Tag, join_through: PostTag` | `dependent: :nullify`; also `:destroy`, `:delete_all` |
| `validate` | `validate :email, match: /@/, message: "is invalid"` | see [Validation Options](api/validation-options.md) |
| `before_save` etc. | `before_save :method` | see [Callback Hooks](api/callback-hooks.md) |
| `scope` | `scope :recent, -> { order(id: :desc) }` | |

## Create, read, update, delete

```crystal
ada = User.create!(name: "Ada", email: "ADA@example.com", age: 36) # INSERT; no validation, no callbacks
grace = User.new("Grace", "grace@example.com")
grace.save                        # => true; validates, runs callbacks, sets id and timestamps
grace.name = "Grace H."
grace.save!                       # raises ValidationError if invalid, RecordNotSaved if a callback halts
grace.valid?                      # => true
grace.errors                      # => [] of CQL::ActiveRecord::Validations::Error

User.find(ada.id!)                # => User?
User.find!(ada.id!)               # raises DB::NoResultsError when missing
User.find_by(email: "ADA@example.com")
User.find_by!(name: "Ada")

User.update!(ada.id!, age: 37)    # UPDATE users SET age = ? WHERE users.id = ?
ada.reload!
ada.delete!                       # => true; runs destroy callbacks
```

## Query

```crystal
User.all                                   # Array(User)
User.first                                 # User?
User.last                                  # User?
User.count                                 # SELECT COUNT(*) FROM users
User.where(active: true).exists?           # Bool
User.where(active: true).order(created_at: :desc).limit(10).offset(10).all
User.where { age > 18 }.all                # typed columns, checked at compile time
User.where { (age >= 18) & (active == true) }.all
User.where { name.like("G%") }.all
User.where("lower(email) = ?", "grace@example.com").all
User.query.joins(:posts) { posts.published == true }.order_by(created_at: :desc).select(:id, :name).to_a
User.page(2, per_page: 20)                 # Array(User)
User.preload(:posts).all                   # has_many, belongs_to, has_one
User.where(active: true).pluck(:email, as: String)
User.active.adults.all                     # scopes chain
User.where(active: true).find_each(batch_size: 1000) { |user| user.name }
```

## Associations

```crystal
user = User.create!(name: "Linus", email: "linus@example.com")
post = user.posts.create(title: "Hello") # sets user_id; validates the Post
user.posts.all                           # Array(Post)
user.posts.count                         # Int64
post.user                                # => User?
user.profile                             # => Profile?
tag = Tag.create!(name: "crystal")
post.tags << tag                         # inserts the post_tags row
post.tags.all                            # Array(Tag)
```

## Transactions

```crystal
User.transaction do
  owner = User.create!(name: "Ken", email: "ken@example.com")
  Profile.create!(user_id: owner.id!, bio: "unix")
end # commits; an exception in the block rolls back

AppDB.transaction do |tx|
  tx.connection.exec("UPDATE users SET active = ? WHERE age < ?", false, 18)
end
```

## Soft deletes

```crystal
class Comment
  include CQL::ActiveRecord::Model(Int64)
  include CQL::ActiveRecord::SoftDeletable # adds deleted_at : Time?

  property post_id : Int64 = 0
  property body : String = ""
end

comment = Comment.create!(post_id: post.id!, body: "Nice")
comment.delete!                   # UPDATE comments SET deleted_at = ...
Comment.all                       # excludes soft-deleted rows
Comment.with_deleted.all.size     # includes them
Comment.only_deleted.all.size     # only them
comment.restore!                  # deleted_at = NULL
comment.force_delete!             # DELETE FROM comments ...
```

## Optimistic locking

`Profile` (above) includes `CQL::ActiveRecord::OptimisticLocking`.

```crystal
profile = Profile.create!(user_id: user.id!, bio: "kernel")
profile.bio = "Linux"
begin
  profile.update!                 # UPDATE profiles SET ..., lock_version = ? WHERE (profiles.id = ?) AND (profiles.lock_version = ?)
rescue CQL::OptimisticLockError
  profile.reload!                 # another process won; reload and retry
end
```

## Query builder (`CQL::Query`)

```crystal
AppDB.query.from(:users).select(:name).where(active: true).order(:name).all(as: String)
AppDB.query.from(:users).select(:name, :age).all(as: {String, Int32})
AppDB.insert.into(:users).values(name: "Barbara", email: "barbara@example.com").commit
AppDB.update.table(:users).set(active: false).where(name: "Barbara").commit
AppDB.delete.from(:users).where(name: "Barbara").commit
AppDB.query.from(:users).where(name: "Ada").to_sql(for: CQL::Adapter::Postgres) # {sql, params}
```

## Migrations

```crystal
class CreateUsers < CQL::Migration(20250125001401)
  def up
    schema.table :users do
      primary :id, Int64, auto_increment: true
      column :name, String
      column :email, String
      column :age, Int32, default: 0
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

migrator = AppDB.migrator(CQL::MigratorConfig.new(schema_file_path: "src/schemas/app_schema.cr", auto_sync: true))
migrator.up                       # apply pending migrations
migrator.pending_migrations       # => [] of CQL::BaseMigration.class
migrator.applied_migrations.size  # => 1
migrator.rollback                 # revert the newest
```

## Configuration

```crystal
CQL.configure do |c|
  c.db = "sqlite3://./app.db"
  c.pool_size = 5
  c.sql_logging = false
end
```

| Database | URL |
| :--- | :--- |
| SQLite file / in memory | `sqlite3://./db/app.db` / `sqlite3::memory:` |
| PostgreSQL | `postgres://user:pass@host:5432/database` (or `postgresql://`) |
| MySQL | `mysql://user:pass@host:3306/database` |
| CockroachDB | `cockroachdb://user:pass@host:26257/database` |

## Schema mapping check

```bash
CQL_VALIDATE_SCHEMA_MAPPINGS=1 crystal spec
```

With the variable set to `1`, every model compares its getter types and primary key with its schema table and raises `CQL::ActiveRecord::SchemaMappingError` on a mismatch. The check runs after all other top-level code, so run it through specs or a script that only requires the models, not a server that blocks.

## See Also

- [Migration DSL](api/migration-dsl.md)
- [Validation Options](api/validation-options.md)
- [Callback Hooks](api/callback-hooks.md)
- [Configuration Reference](configuration.md)
- [Error Codes](error-codes.md)
- [Glossary](glossary.md)
