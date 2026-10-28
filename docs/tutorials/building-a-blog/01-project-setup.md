---
description: "Create the blog_engine project, add CQL and connect it to SQLite."
---

# Part 1: Project Setup

Parts 2 to 5 build on this project, so keep it.

**You need:** Crystal 1.19.1 or later and the SQLite 3 development library. [Your First CQL App](../getting-started/your-first-cql-app.md) is a shorter introduction.

## What you will build

```text
User ──< Post >── Category        User ──< Comment >── Post
```

- A user writes many posts and many comments.
- A category holds many posts; a post may have no category.
- A post has many comments; a comment may be anonymous (no user).

{% stepper %}
{% step %}
### Create the project

```bash
crystal init app blog_engine
cd blog_engine
```

Check: `shard.yml` and `src/blog_engine.cr` exist.
{% endstep %}

{% step %}
### Add the dependencies

Add to `shard.yml`:

{% code title="shard.yml" %}
```yaml
dependencies:
  cql:
    github: azutoolkit/cql
    version: ~> 0.0.808
  sqlite3:
    github: crystal-lang/crystal-sqlite3
```
{% endcode %}

```bash
shards install
```

Check: the output lists `Installing cql` and `Installing sqlite3`.
{% endstep %}

{% step %}
### Create the directories

```bash
mkdir -p src/models src/schemas migrations db
```

```text
blog_engine/
├── shard.yml
├── db/            # SQLite database file
├── migrations/    # schema changes, Part 2
└── src/
    ├── models/    # models, Part 3
    └── schemas/   # schema written by the migrator, Part 2
```
{% endstep %}

{% step %}
### Configure the database

{% code title="src/database.cr" %}
```crystal
require "cql"
require "sqlite3"

# foreign_keys=1 makes SQLite enforce the ON DELETE rules declared in Part 2
DATABASE_URL = ENV["DATABASE_URL"]? || "sqlite3://./db/blog_development.db?foreign_keys=1"

# The connection the migrations run on; they declare the tables, so the block stays empty
AppDB = CQL::Schema.define(:app_db, adapter: CQL::Adapter::SQLite, uri: DATABASE_URL) do
end

# These values are also MigratorConfig's defaults
MIGRATOR_CONFIG = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  schema_symbol: :app_schema,
  auto_sync: true
)
```
{% endcode %}

| Setting | Meaning |
| :--- | :--- |
| `adapter` | The database dialect. Part 5 switches it to PostgreSQL for production. |
| `uri` | Connection URL. A relative SQLite path starts from the directory you run the program in. |
| `schema_file_path`, `schema_name`, `schema_symbol` | Where the migrator writes the generated schema, and the constant and symbol it defines. |
| `auto_sync` | Rewrite that file after every `up` and `down`. |
{% endstep %}

{% step %}
### Write the entry point

Replace the generated `src/blog_engine.cr`:

{% code title="src/blog_engine.cr" %}
```crystal
require "./database"
require "../migrations/*"

module BlogEngine
  VERSION = "0.1.0"

  def self.setup
    AppDB.exec("SELECT 1") # fails here if the database cannot be opened
    puts "Database connected"
  end

  def self.migrate
    migrator = AppDB.migrator(MIGRATOR_CONFIG)
    pending = migrator.pending_migrations.size

    if pending > 0
      puts "Running #{pending} pending migration(s)..."
      migrator.up
      puts "Migrations complete"
    else
      puts "Database is up to date"
    end
  end
end
```
{% endcode %}

`require` runs at compile time, so the migrations are required at the top of the file.
{% endstep %}

{% step %}
### Write the setup script

{% code title="src/setup.cr" %}
```crystal
require "./blog_engine"

puts "Setting up Blog Engine..."
BlogEngine.setup
BlogEngine.migrate
puts "Setup complete!"
```
{% endcode %}

{% hint style="info" %}
You run `src/setup.cr` in Part 2, once there is a migration for it to apply.
{% endhint %}
{% endstep %}

{% step %}
### Check the connection

{% code title="src/verify.cr" %}
```crystal
require "./database"

begin
  AppDB.exec("SELECT 1")
  puts "Database connection: OK"
rescue ex
  puts "Database connection: FAILED (#{ex.message})"
  exit 1
end
```
{% endcode %}

```bash
crystal src/verify.cr
```

```text
Database connection: OK
```

`db/blog_development.db` now exists.
{% endstep %}
{% endstepper %}

{% content-ref url="02-database-schema.md" %}
[02-database-schema.md](02-database-schema.md)
{% endcontent-ref %}
