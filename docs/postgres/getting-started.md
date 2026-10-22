# A PostgreSQL Database in 5 Minutes

`CQL::Postgres` gives a PostgreSQL app models, migrations, seeds, database tasks and a health
report with one URL of configuration. It is opt-in and lives next to (not instead of) CQL's own
`CQL::Migration(V)`, `CQL::Migrator` and `CQL::ActiveRecord::Model(Pk)`: apps that only
`require "cql"` never load it.

## 1. Add the shards

```yaml
dependencies:
  cql:
    github: azutoolkit/cql
  pg:
    github: will/crystal-pg
    version: ~> 0.29.0
```

```crystal
require "cql/postgres"
```

## 2. Point CQL at the database

```bash
export DATABASE_URL=postgres://postgres:postgres@localhost:5432/blog_development
```

That is all the configuration there is. Without it CQL falls back to `PG*` variables and
then to `postgres://localhost/<app>_<env>` (`CQL_ENV` / `APP_ENV`, default `development`). To set it
in code, or tune the pool:

```crystal
CQL::Postgres.configure do |c|
  c.url = "postgres://localhost/blog_development"
  c.pool_size = 10
  c.slow_query_ms = 50
  c.n_plus_one = CQL::Postgres::Configuration::NPlusOne::Warn # Off | Warn | Raise
  c.log = Log.for("my_app.db")                                 # warnings and migration progress
end
```

The pool opens lazily (or with `CQL::Postgres::Database.boot`) and the schema is learned from your
models. Queries, transactions and pool connects are published through `CQL::Events`, so dashboards and
tracers subscribe without this layer knowing about them.

## 3. Declare a model

```crystal
# src/models/user.cr
class User < CQL::Postgres::Model
  table :users

  column id : Int64, primary_key: true
  column email : String, validate: :email, unique: true
  column name : String
  column role : String = "member"
  timestamps

  validates :name, presence: true, length: 2..80
  has_many posts : Post, foreign_key: :user_id
  scope :admins, -> { where(role: "admin") }
end
```

See [Models](models.md) for every macro.

## 4. Write the migration

```crystal
# db/migrations/20261022000001_create_users.cr
class CreateUsers < CQL::Postgres::Migration(20261022000001_i64)
  def up
    create_table :users do |t|
      t.string :email
      t.string :name
      t.string :role, default: "member"
      t.timestamps
      t.index :email, unique: true
    end
  end

  def down
    drop_table :users
  end
end
```

See [Migrations](migrations.md) for the PostgreSQL types, index options and
online-safe operations.

## 5. Add the task runner

```crystal
# db/tasks.cr
require "cql"
require "cql/postgres"
require "../src/models"
require "./migrations/*"
require "./seeds"

exit CQL::Postgres::Database::Tasks.run(ARGV)
```

```bash
crystal run db/tasks.cr -- setup     # create + migrate + seed
crystal run db/tasks.cr -- status
```

[Database tasks](tasks.md) lists every command, including `structure:dump`,
`structure:load` and `analyze`.

## 6. Use it

```crystal
user = User.create!(email: "ada@example.com", name: "Ada")
User.admins.recent.preload(:posts).paginate(page: 2, per_page: 20) # => CQL::Postgres::Page(User)

User.transaction do |tx|
  author = User.create!(tx, email: "bob@example.com", name: "Bob")
  Post.create!(tx, user_id: author.id.not_nil!, title: "Hello")
end
```

## Good to know

* Declare `table` and the `primary_key` column first; associations and validations come after.
* Write association targets as full constant paths inside namespaces (`Blog::Post`).
* `column` accepts `String`, `Int32`, `Int64`, `Float64`, `Bool`, `Time`, `UUID` and `JSON::Any`
  (json/jsonb). Array columns are not mapped by models yet: use migrations and raw SQL for them.
* Scope names are global per query builder in CQL (`scope :recent` on two models collides when both
  are loaded); give scopes distinct names across models.
