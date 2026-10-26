# Migration Workflows

Change the blog engine's schema as you would in production: add tables and a column, migrate data, test rollbacks and deploy.

**You need:** the blog engine from all five parts of [Building a Blog](../building-a-blog/01-project-setup.md).

## Step 1: Add a migration runner

```crystal
# src/migrate.cr
require "./blog_engine"

# AppSchema knows every table and column. On a schema that lacks one, schema.alter raises,
# schema.posts raises KeyError, and drop_column only logs an error and skips the column.
migrator = AppSchema.migrator(MIGRATOR_CONFIG)

case ARGV[0]?
when "up"
  migrator.up
when "down"
  migrator.rollback # reverts the newest migration file, if it is applied (see Step 3)
when "status"
  puts "Applied: #{migrator.applied_migrations.map(&.version)}"
  puts "Pending: #{migrator.pending_migrations.map(&.version)}"
else
  puts "Usage: crystal src/migrate.cr [up|down|status]"
end
```

```bash
crystal src/migrate.cr status
```

```text
Applied: [1, 2, 3, 4]
Pending: []
```

## Step 2: Add the tagging tables

The plan: `tags` with a unique `slug`, and a `post_tags` join table with its own `id`, so that it can have a model.

```crystal
# migrations/005_create_tags.cr
class CreateTags < CQL::Migration(5)
  def up
    schema.table :tags do
      primary :id, Int64, auto_increment: true
      column :name, String
      column :slug, String
      timestamps

      unique_constraint [:slug]
    end

    schema.tags.create!
  end

  def down
    schema.tags.drop!
  end
end
```

```crystal
# migrations/006_create_post_tags.cr
class CreatePostTags < CQL::Migration(6)
  def up
    schema.table :post_tags do
      primary :id, Int64, auto_increment: true
      column :post_id, Int64
      column :tag_id, Int64
      timestamps

      foreign_key [:post_id], references: :posts, references_columns: [:id], on_delete: :cascade
      foreign_key [:tag_id], references: :tags, references_columns: [:id], on_delete: :cascade
      unique_constraint [:post_id, :tag_id]
    end

    schema.post_tags.create!

    schema.alter :post_tags do
      create_index :idx_post_tags_tag_id, [:tag_id]
    end
  end

  def down
    schema.post_tags.drop!
  end
end
```

## Step 3: Apply the migrations and test the rollback

```bash
crystal src/migrate.cr up
crystal src/migrate.cr down
crystal src/migrate.cr up
```

```text
...
│   ✔    │ CreateTags │       5 │
│   ✔    │ CreatePostTags │       6 │
...
│   ✗    │ CreatePostTags │       6 │
...
│   ✔    │ CreatePostTags │       6 │
```

Running `down` and `up` locally proves the migration reverses. `migrator.down` reverts every applied migration; to stop at a version, use the `rollback_to` helper from [Rollback Migrations](../../how-to/migrations/rollback.md).

{% hint style="warning" %}
`rollback(n)` looks only at the newest `n` migration files, applied or not, so with a pending newest file, or on a second `rollback` in a row, it reverts nothing. `down_to` reverts the wrong migrations.
{% endhint %}

## Step 4: Map the new tables

The migrator rewrote `src/schemas/app_schema.cr`, so `AppSchema` now has both tables:

```crystal
# src/models/tag.cr
class Tag
  include CQL::ActiveRecord::Model(Int64)
  db_context AppSchema, :tags

  property name : String
  property slug : String
  property created_at : Time?
  property updated_at : Time?

  has_many :post_tags, PostTag, :tag_id

  def initialize(@name : String)
    @slug = Category.generate_slug(name)
  end
end
```

```crystal
# src/models/post_tag.cr
class PostTag
  include CQL::ActiveRecord::Model(Int64)
  db_context AppSchema, :post_tags

  property post_id : Int64
  property tag_id : Int64
  property created_at : Time?
  property updated_at : Time?

  belongs_to :post, Post, :post_id
  belongs_to :tag, Tag, :tag_id

  def initialize(@post_id : Int64, @tag_id : Int64)
  end
end
```

```crystal
# src/tags.cr
require "./blog_engine"

tag = Tag.find_by(slug: "crystal") || Tag.new("Crystal").tap(&.save!)
Post.where(published: true).limit(2).all.each do |post|
  PostTag.new(post.id!, tag.id!).save! unless PostTag.find_by(post_id: post.id!, tag_id: tag.id!)
end
puts "#{tag.name} (#{tag.slug}): #{tag.post_tags.count} posts"
```

```bash
crystal src/tags.cr
```

```text
Crystal (crystal): 2 posts
```

## Step 5: Add a column without downtime

Deploy the migration before the code that uses the column, and never drop a column that running code still reads.

```crystal
# migrations/007_add_featured_to_posts.cr
class AddFeaturedToPosts < CQL::Migration(7)
  def up
    schema.alter :posts do
      add_column :featured, Bool, null: true # add_column does not write default: yet
      add_column :featured_at, Time, null: true
      create_index :idx_posts_featured, [:featured]
    end
    schema.exec("UPDATE posts SET featured = FALSE") # backfill the existing rows
  end

  def down
    schema.alter :posts do
      drop_index :idx_posts_featured
      drop_column :featured_at
      drop_column :featured
    end
  end
end
```

{% hint style="warning" %}
`add_column` ignores `default:`, so `default: false, null: false` fails on a table with rows. Add the column as nullable and backfill it, as here, or write the `ALTER TABLE` with `schema.exec`.
{% endhint %}

```bash
crystal src/migrate.cr up
crystal src/migrate.cr down
crystal src/migrate.cr up
```

Check: the output shows `✔ AddFeaturedToPosts`, `✗`, then `✔`, and `app_schema.cr` lists `boolean :featured, null: true`. (SQLite needs the index dropped before the column.) Then add to `Post`, below its properties:

```crystal
  property featured : Bool? # nil for rows written without it
  property featured_at : Time?
```

## Step 6: Migrate data in batches

```crystal
# migrations/008_normalize_user_emails.cr
class NormalizeUserEmails < CQL::Migration(8)
  BATCH_SIZE = 1000 # a constant you control, never user input

  def up
    loop do
      # MySQL rejects LIMIT inside IN (...): select the ids first there
      result = schema.exec(<<-SQL)
        UPDATE users SET email = LOWER(TRIM(email))
        WHERE id IN (SELECT id FROM users WHERE email <> LOWER(TRIM(email)) LIMIT #{BATCH_SIZE})
        SQL
      break if result.rows_affected == 0
    end

    left = schema.exec_query do |conn|
      conn.scalar("SELECT COUNT(*) FROM users WHERE email <> LOWER(TRIM(email))").as(Int64)
    end
    raise "Data migration incomplete: #{left} emails left" if left > 0
  end

  def down
    raise "Cannot roll back #{self.class.name}: the original emails are gone"
  end
end
```

```bash
crystal src/migrate.cr up
crystal src/migrate.cr down
```

```text
...
│   ✔    │ NormalizeUserEmails │       8 │
...
Unhandled exception: Cannot roll back NormalizeUserEmails: the original emails are gone (Exception)
```

`users.email` is unique, so addresses that differ only in case collide; find them first with `GROUP BY LOWER(TRIM(email)) HAVING COUNT(*) > 1`. To change a column's type, add a new column, copy the data, switch the code, and drop the old column later.

## Step 7: Deploy

First run the migrations on a copy of production data and back the database up. `migrator.up` runs all pending migrations in one transaction on SQLite and PostgreSQL, so one failure undoes them all; this script commits them one at a time:

```crystal
# src/deploy_migrations.cr
require "./blog_engine"

migrator = AppSchema.migrator(MIGRATOR_CONFIG)
pending = migrator.pending_migrations

if pending.empty?
  puts "No pending migrations"
  exit 0
end

pending.each do |migration|
  puts "Running migration #{migration.version} (#{migration.name})..."
  begin
    migrator.up_to(migration.version)
  rescue ex
    puts "FAILED: #{ex.message}"
    exit 1
  end
end
puts "All migrations completed"
```

```bash
crystal src/deploy_migrations.cr
```

```text
No pending migrations
```

MySQL and CockroachDB commit DDL as it runs, so a migration that fails halfway leaves its earlier statements applied.

## Next steps

- [Create a Migration](../../how-to/migrations/create-migration.md)
- [Rollback Migrations](../../how-to/migrations/rollback.md)
- [Migration DSL Reference](../../reference/api/migration-dsl.md)
