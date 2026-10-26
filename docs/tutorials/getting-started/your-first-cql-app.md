# Your First CQL App

Build a small SQLite application with CQL: connect, migrate, define models, query, validate and use transactions.

**You need:** Crystal 1.12.2 or later, and SQLite 3 with its development library (`libsqlite3-dev` on Debian and Ubuntu).

## Step 1: Create the project

```bash
crystal init app myapp
cd myapp
```

Check: `ls` shows `shard.yml` and `src/myapp.cr`.

## Step 2: Add CQL and a driver

Add to `shard.yml`:

```yaml
dependencies:
  cql:
    github: azutoolkit/cql
    version: "~> 0.0.589"
  sqlite3:
    github: crystal-lang/crystal-sqlite3
```

```bash
shards install
```

Check: the output lists `Installing cql` and `Installing sqlite3`, and `lib/cql` exists.

For another database, change the driver, the adapter and the URL in Step 3:

| Database | Shard | Adapter | URL |
| :--- | :--- | :--- | :--- |
| PostgreSQL | none: `require "cql"` registers a native driver (the `pg` shard also works) | `CQL::Adapter::Postgres` | `postgres://user:pass@localhost:5432/myapp` |
| MySQL | `mysql` (`github: crystal-lang/crystal-mysql`), plus `require "mysql"` | `CQL::Adapter::MySql` | `mysql://user:pass@localhost:3306/myapp` |

## Step 3: Connect to the database

```bash
mkdir -p db
```

```crystal
# src/database.cr
require "cql"
require "sqlite3"

# foreign_keys=1 makes SQLite enforce foreign keys (PostgreSQL and MySQL always do)
AppDB = CQL::Schema.define(:app_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://./db/development.db?foreign_keys=1") do
  # Empty: the migrations declare the tables
end
```

```crystal
# src/check_connection.cr
require "./database"

AppDB.exec("SELECT 1")
puts "Connected to #{AppDB.uri}"
```

```bash
crystal src/check_connection.cr
```

```text
Connected to sqlite3://./db/development.db?foreign_keys=1
```

## Step 4: Create the users table

A migration describes one schema change and how to undo it.

```crystal
# migrations/001_create_users.cr
class CreateUsers < CQL::Migration(1)
  def up
    schema.table :users do
      primary :id, Int64, auto_increment: true
      column :name, String # NOT NULL unless you pass null: true
      column :email, String
      column :active, Bool, default: false
      timestamps # created_at and updated_at

      unique_constraint [:email]
    end

    schema.users.create!
  end

  def down
    schema.users.drop!
  end
end
```

```crystal
# src/setup.cr
require "./database"
require "../migrations/*"

# AppDB.migrator uses CQL::MigratorConfig.new: after each run it writes the database's
# tables to src/schemas/app_schema.cr as AppSchema (schema_symbol :app_schema, auto_sync: true)
migrator = AppDB.migrator
migrator.up
puts "Applied #{migrator.applied_migrations.size} migration(s)"
```

```bash
crystal src/setup.cr
```

```text
┌────────┬──────────────────────┬─────────┐
│ Status │ Migration            │ Version │
├────────┼──────────────────────┼─────────┤
│   ✔    │ CreateUsers │       1 │
└────────┴──────────────────────┴─────────┘

Applied 1 migration(s)
```

CQL's development logger also prints timestamped `INFO` and `DEBUG` lines. Check that `src/schemas/app_schema.cr` now exists: it defines `AppSchema`, which knows every table in the database. `AppDB` declares none, so the application uses `AppSchema`.

## Step 5: Define a model and run CRUD queries

```crystal
# src/models/user.cr
class User
  include CQL::ActiveRecord::Model(Int64) # adds the id primary key
  db_context AppSchema, :users

  property name : String
  property email : String
  property active : Bool = false
  property created_at : Time?
  property updated_at : Time?

  def initialize(@name : String, @email : String, @active : Bool = false)
  end
end
```

Models are classes, not structs, so that `save` can assign the new id to your instance. Replace the generated `src/myapp.cr`:

```crystal
# src/myapp.cr
require "cql"
require "sqlite3"
require "./schemas/app_schema"
require "./models/*"

User.delete_all # start each run from an empty table

# Create
alice = User.new(name: "Alice Johnson", email: "alice@example.com", active: true)
alice.save
puts "Created #{alice.name} with id #{alice.id}"

bob = User.create!(name: "Bob Smith", email: "bob@example.com")
puts "Created #{bob.name}"

# Read
puts "find: #{User.find(alice.id!).try(&.name)}"
puts "find_by: #{User.find_by(email: "bob@example.com").try(&.name)}"
puts "Active users: #{User.where(active: true).count}"

# Update
alice.active = false
alice.save
bob.update!(name: "Robert Smith")
puts "Updated: #{User.all.map(&.name)}"

# Delete
User.where(active: false).first.try(&.delete!)
puts "Remaining: #{User.all.map(&.name)}"
```

```bash
crystal src/myapp.cr
```

```text
Created Alice Johnson with id 1
Created Bob Smith
find: Alice Johnson
find_by: Bob Smith
Active users: 1
Updated: ["Alice Johnson", "Robert Smith"]
Remaining: ["Robert Smith"]
```

The id grows on every run, because SQLite does not reuse ids.

## Step 6: Add posts

```crystal
# migrations/002_create_posts.cr
class CreatePosts < CQL::Migration(2)
  def up
    schema.table :posts do
      primary :id, Int64, auto_increment: true
      column :title, String
      column :body, String
      column :user_id, Int64
      timestamps

      foreign_key [:user_id], references: :users, references_columns: [:id], on_delete: :cascade
    end

    schema.posts.create!

    schema.alter :posts do
      create_index :idx_posts_user_id, [:user_id]
    end
  end

  def down
    schema.posts.drop!
  end
end
```

```crystal
# src/models/post.cr
class Post
  include CQL::ActiveRecord::Model(Int64)
  db_context AppSchema, :posts

  property title : String
  property body : String
  property user_id : Int64
  property created_at : Time?
  property updated_at : Time?

  belongs_to :user, User, :user_id

  def initialize(@title : String, @body : String, @user_id : Int64)
  end
end
```

In `src/models/user.cr`, add the other side of the association below the properties:

```crystal
  has_many :posts, Post, :user_id
```

Add to the end of `src/myapp.cr`:

```crystal
author = User.create!(name: "Carol", email: "carol@example.com")
Post.create!(title: "My First Post", body: "Hello!", user_id: author.id!)
Post.create!(title: "Another Post", body: "More content.", user_id: author.id!)

puts "#{author.name} has #{author.posts.count} posts: #{author.posts.all.map(&.title)}"
first_post = Post.find_by!(title: "My First Post")
puts "'#{first_post.title}' was written by #{first_post.user.try(&.name)}"
```

Run the migration first, so `AppSchema` gains the `posts` table, then the app:

```bash
crystal src/setup.cr
crystal src/myapp.cr
```

```text
...
Applied 2 migration(s)
...
Carol has 2 posts: ["My First Post", "Another Post"]
'My First Post' was written by Carol
```

`User.delete_all` at the top of the script now removes posts too: the `on_delete: :cascade` foreign key deletes them in the database.

## Step 7: Validate input

In `src/models/user.cr`, add below `has_many`:

```crystal
  validate :name, presence: true, size: 1..100
  validate :email, presence: true, match: /@/
```

Add to the end of `src/myapp.cr`:

```crystal
invalid = User.new(name: "", email: "nope")
puts "valid? #{invalid.valid?}"
puts invalid.errors.map(&.message)

begin
  invalid.save
rescue ex : CQL::ActiveRecord::Validations::ValidationError
  puts "save raised: #{ex.message}"
end
```

```bash
crystal src/myapp.cr
```

```text
...
valid? false
["name must be present", "name must have a size of 1..100", "email must match the pattern /@/"]
save raised: name must be present,name must have a size of 1..100,email must match the pattern /@/
```

`save` and `save!` run the validations and raise when the record is invalid; `create!` skips them.

## Step 8: Use a transaction

Add to the end of `src/myapp.cr`:

```crystal
User.transaction do
  dave = User.create!(name: "Dave", email: "dave@example.com")
  Post.create!(title: "Welcome", body: "Thanks for joining!", user_id: dave.id!)
end
puts "Dave saved: #{User.find_by(email: "dave@example.com").try(&.posts.count)} post"

begin
  User.transaction do
    User.create!(name: "Erin", email: "erin@example.com")
    raise "payment failed"
  end
rescue ex
  puts "Rolled back (#{ex.message}): Erin saved? #{User.find_by(email: "erin@example.com") ? "yes" : "no"}"
end
```

```bash
crystal src/myapp.cr
```

```text
...
Dave saved: 1 post
Rolled back (payment failed): Erin saved? no
```

An exception inside the block rolls back every statement in it, then propagates.

## Project structure

```text
myapp/
├── shard.yml
├── db/development.db          # SQLite database
├── migrations/
│   ├── 001_create_users.cr
│   └── 002_create_posts.cr
└── src/
    ├── check_connection.cr
    ├── database.cr            # AppDB: the connection migrations run on
    ├── myapp.cr               # the application
    ├── setup.cr               # runs the migrations
    ├── models/
    │   ├── post.cr
    │   └── user.cr
    └── schemas/
        └── app_schema.cr      # AppSchema, written by the migrator
```

## Troubleshooting

The connection pool opens the first time code uses `AppDB`, so a wrong PostgreSQL or MySQL URL, or a stopped server, raises there, for example `DB::ConnectionRefused`. `crystal src/check_connection.cr` shows it.

To inspect or reset the migrations (development only), run the migrator on `AppSchema`. A `down` method such as `schema.posts.drop!` needs a schema that knows the table, and `AppDB` declares none (it raises `KeyError`):

```crystal
# src/reset.cr
require "cql"
require "sqlite3"
require "./schemas/app_schema"
require "../migrations/*"

migrator = AppSchema.migrator
puts "Applied: #{migrator.applied_migrations.size}, pending: #{migrator.pending_migrations.size}"
migrator.down # roll back every migration
migrator.up   # apply them again
```

## Next steps

- [Building a Blog](../building-a-blog/01-project-setup.md): a five-part project
- [Define a Model](../../how-to/models/define-model.md)
- [Build Complex Queries](../../how-to/querying/complex-queries.md)
- [Add Validations](../../how-to/models/add-validations.md)
