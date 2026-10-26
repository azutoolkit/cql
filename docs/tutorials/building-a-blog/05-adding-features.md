# Part 5: Adding Features

Add validations, callbacks and transactions to the blog engine, seed it with sample data, print statistics, and prepare it for production.

**You need:** the project from [Part 4](04-crud-operations.md).

## Step 1: Add validations

Declare rules with `validate :attribute, predicate: value`. The predicates are `presence`, `required`, `size`, `match`, `eq`, `gt`, `gte`, `lt`, `lte`, `in`, `exclude`, `confirmation` and `accept`; `message:` replaces the default text. A rule that needs the database, such as uniqueness, is a `CQL::ActiveRecord::Validations::CustomValidator` registered with `use`.

At the top of `src/models/user.cr`, above `class User`:

```crystal
# Uniqueness needs the database, so it is a custom validator
class UniqueUserValidator < CQL::ActiveRecord::Validations::CustomValidator
  def initialize(@record : User)
  end

  def valid? : Array(CQL::ActiveRecord::Validations::Error)
    errors = [] of CQL::ActiveRecord::Validations::Error
    if (other = User.find_by(username: @record.username)) && other.id != @record.id
      errors << CQL::ActiveRecord::Validations::Error.new(:username, "username has already been taken")
    end
    if (other = User.find_by(email: @record.email)) && other.id != @record.id
      errors << CQL::ActiveRecord::Validations::Error.new(:email, "email has already been taken")
    end
    errors
  end
end
```

Inside `class User`, below the associations:

```crystal
  validate :username, presence: true, size: 3..50
  validate :email, presence: true, match: /\A[^@\s]+@[^@\s]+\z/
  use UniqueUserValidator
```

Inside `class Post` in `src/models/post.cr`, below the associations:

```crystal
  validate :title, presence: true, size: 1..200
  validate :content, presence: true
```

Try them in a new script:

```crystal
# src/features.cr
require "./blog_engine"

User.delete_all
Category.delete_all

user = User.new(username: "ab", email: "invalid")
puts "valid? #{user.valid?}"
user.errors.each { |error| puts "  #{error.field}: #{error.message}" }

begin
  user.save
rescue ex : CQL::ActiveRecord::Validations::ValidationError
  puts "save raised: #{ex.message}"
end
```

```bash
crystal src/features.cr
```

```text
valid? false
  username: username must have a size of 3..50
  email: email must match the pattern /\A[^@\s]+@[^@\s]+\z/
save raised: username must have a size of 3..50,email must match the pattern /\A[^@\s]+@[^@\s]+\z/
```

`save` and `save!` both raise on an invalid record, so call `valid?` first when you want to report errors. `create!` skips validations.

## Step 2: Add callbacks

The callbacks are `before_validation`, `after_validation`, `before_save`, `after_save`, `before_create`, `after_create`, `before_update`, `after_update`, `before_destroy` and `after_destroy`. `save` runs them in this order: `before_validation`, `after_validation`, the validation rules, `before_save`, `before_create` or `before_update`, `after_create` or `after_update`, `after_save`. `create!` runs none.

Inside `class User`, below `use UniqueUserValidator`:

```crystal
  before_validation :normalize_email
  after_create :send_welcome_notification

  private def normalize_email
    @email = @email.strip.downcase
  end

  private def send_welcome_notification
    puts "Welcome, #{display_name}!"
  end
```

Inside `class Post`, below the validations:

```crystal
  before_save :clean_title
  after_save :notify_subscribers

  private def clean_title
    @title = @title.strip
  end

  private def notify_subscribers
    puts "Notifying subscribers about: #{title}" if published?
  end
```

`save` fills in `created_at` and `updated_at` itself, so no callback is needed for them. Add to `src/features.cr`:

```crystal
dana = User.new(username: "dana", email: "  Dana@Example.COM ", first_name: "Dana")
dana.save!
puts "Stored email: #{User.find!(dana.id!).email}"

copy = User.new(username: "dana", email: "dana@example.com")
puts "Duplicate: #{copy.errors.map(&.message)}"

post = Post.new(title: "  Hello, CQL  ", content: "First post.", user_id: dana.id!, published: true)
post.save!
puts "Stored title: #{post.title.inspect}"
```

```text
...
Welcome, Dana!
Stored email: dana@example.com
Duplicate: ["username has already been taken", "email has already been taken"]
Notifying subscribers about: Hello, CQL
Stored title: "Hello, CQL"
```

{% hint style="warning" %}
A callback that returns `false` halts the operation, and `save` returns `false`. End a callback with `nil` or `true` when its last expression can be `false`.
{% endhint %}

## Step 3: Use transactions

Add to `src/features.cr`:

```crystal
def publish_with_comments(author : User, title : String, content : String, comments : Array(String)) : Post
  post = Post.new(title: title, content: content, user_id: author.id!, published: true)
  Post.transaction do
    post.save!
    comments.each { |text| Comment.create!(content: text, post_id: post.id!, user_id: author.id) }
  end
  post
end

welcome = publish_with_comments(dana, "Welcome", "Thanks for reading.", ["First!", "Great start."])
puts "#{welcome.title} has #{welcome.comments.count} comments"

begin
  Post.transaction do
    Post.create!(title: "Half done", content: "Never committed.", user_id: dana.id!)
    raise "something failed"
  end
rescue ex
  puts "Rolled back (#{ex.message}): #{Post.where(title: "Half done").count} posts titled Half done"
end

Post.transaction do
  Post.create!(title: "Also half done", content: "Never committed.", user_id: dana.id!)
  raise DB::Rollback.new
end
puts "DB::Rollback: #{Post.where(title: "Also half done").count} posts, no exception"
```

```text
...
Notifying subscribers about: Welcome
Welcome has 2 comments
Rolled back (something failed): 0 posts titled Half done
DB::Rollback: 0 posts, no exception
```

An exception rolls the whole block back and propagates; `DB::Rollback` rolls back without escaping. `transaction` returns the block's value or `nil`, so the method above returns `post` itself.

## Step 4: Write a seeder

```crystal
# src/seeders.cr
module Seeders
  USERS = [
    {username: "alice", email: "alice@example.com", first_name: "Alice", last_name: "Johnson"},
    {username: "bob", email: "bob@example.com", first_name: "Bob", last_name: "Smith"},
    {username: "charlie", email: "charlie@example.com", first_name: "Charlie", last_name: "Brown"},
  ]
  CATEGORIES = ["Technology", "Lifestyle", "Travel", "Food", "Programming"]

  def self.run(random = Random.new(42)) # a fixed seed gives the same data on every run
    User.delete_all
    Category.delete_all

    users = USERS.map { |attrs| User.new(**attrs).tap(&.save!) }
    categories = CATEGORIES.map { |name| Category.new(name).tap(&.save!) }
    posts = create_posts(users, categories, random)
    comments = create_comments(users, posts, random)

    puts "Seeded #{users.size} users, #{categories.size} categories, #{posts.size} posts, #{comments} comments"
  end

  # create! skips validations and callbacks, which keeps seeding fast and quiet
  private def self.create_posts(users, categories, random) : Array(Post)
    users.flat_map do |user|
      (1..random.rand(2..4)).map do |number|
        Post.create!(
          title: "#{user.display_name}'s Post ##{number}",
          content: "A sample post by #{user.full_name}. " * 10,
          user_id: user.id!,
          category_id: categories.sample(random).id,
          published: random.rand < 0.8,
          views_count: random.rand(0_i64..500_i64)
        )
      end
    end
  end

  private def self.create_comments(users, posts, random) : Int32
    posts.select(&.published?).sum do |post|
      count = random.rand(0..3)
      count.times do
        commenter = random.rand < 0.9 ? users.sample(random) : nil # 10% anonymous
        Comment.create!(content: "Great post!", post_id: post.id!, user_id: commenter.try(&.id))
      end
      count
    end
  end
end
```

Users go through `save!`, so their validations and `after_create` callback run. Step 6 runs the seeder.

## Step 5: Print statistics

`CQL::Telemetry` publishes every statement CQL runs. `alert_on_slow` calls a block for the slow ones.

```crystal
# src/monitoring.cr
module Monitoring
  def self.watch_slow_queries
    CQL::Telemetry.alert_on_slow(100.milliseconds) do |event|
      puts "Slow query (#{event.duration.total_milliseconds.round(1)}ms): #{event.sql}"
    end
  end

  def self.print_stats
    published = Post.where(published: true)
    published_count = published.count
    total_views = published.sum(:views_count)
    average = published_count > 0 ? total_views.to_f / published_count : 0.0

    puts "Users: #{User.count} | Posts: #{Post.count} (#{published_count} published) | Comments: #{Comment.count}"
    puts "Views: #{total_views} total, #{average.round(1)} per published post"

    puts "Top posts:"
    published.order(views_count: :desc).limit(3).all.each do |post|
      puts "  #{post.views_count} views - #{post.title}"
    end

    puts "Most active authors:"
    AppSchema.query
      .from(:posts)
      .select(:user_id, count: :id)
      .where(published: true)
      .group(:user_id)
      .all(as: {Int64, Int64})
      .sort_by { |_, total| -total }
      .each { |user_id, total| puts "  #{total} posts - #{User.find!(user_id).full_name}" }
  end
end
```

## Step 6: Run the demo

```crystal
# src/demo.cr
require "./blog_engine"
require "./seeders"
require "./monitoring"

BlogEngine.setup
BlogEngine.migrate
Monitoring.watch_slow_queries

Seeders.run
Monitoring.print_stats

puts "Recent posts:"
Post.where(published: true).order(created_at: :desc, id: :desc).limit(2).all.each do |post|
  puts "  #{post.title} by #{post.user.try(&.full_name)}"
  puts "    #{post.word_count} words | #{post.views_count} views | #{post.comments.count} comments"
  puts "    #{post.excerpt(60)}"
end
```

```bash
crystal src/demo.cr
```

```text
Database connected
Database is up to date
Welcome, Alice!
Welcome, Bob!
Welcome, Charlie!
Seeded 3 users, 5 categories, 10 posts, 17 comments
Users: 3 | Posts: 10 (9 published) | Comments: 17
Views: 2063 total, 229.2 per published post
Top posts:
  491 views - Charlie's Post #2
  489 views - Charlie's Post #3
  381 views - Alice's Post #1
Most active authors:
  4 posts - Charlie Brown
  3 posts - Bob Smith
  2 posts - Alice Johnson
Recent posts:
  Charlie's Post #4 by Charlie Brown
    60 words | 304 views | 3 comments
    A sample post by Charlie Brown. A sample post by Charlie Bro...
  Charlie's Post #3 by Charlie Brown
    60 words | 489 views | 1 comments
    A sample post by Charlie Brown. A sample post by Charlie Bro...
```

No `Slow query` line appears unless a statement takes 100 ms. To find N+1 queries and profile in depth, see [Performance Monitoring](../real-world-examples/performance-monitoring.md).

## Step 7: Prepare for production

Switch the adapter with the environment. `require "cql"` includes a native PostgreSQL driver, so `postgres://` URLs need no other shard:

```crystal
# src/database.cr
require "cql"
require "sqlite3" # development; drop it when you only run on PostgreSQL

adapter = ENV["CRYSTAL_ENV"]? == "production" ? CQL::Adapter::Postgres : CQL::Adapter::SQLite
uri = ENV["DATABASE_URL"]? || "sqlite3://./db/blog_development.db?foreign_keys=1"

AppDB = CQL::Schema.define(:app_db, adapter: adapter, uri: uri) do
end

MIGRATOR_CONFIG = CQL::MigratorConfig.new(
  schema_file_path: "src/schemas/app_schema.cr",
  schema_name: :AppSchema,
  schema_symbol: :app_schema,
  auto_sync: false # keep the hand edit below
)
```

The models use `AppSchema`, and the generated file hard-codes the adapter and URL it was dumped from. Edit those two lines to read the environment too. With `auto_sync: false` the migrator no longer rewrites the file, so add each new table to it yourself:

```crystal
# src/schemas/app_schema.cr, edited by hand
AppSchema = CQL::Schema.define(
  :app_schema,
  adapter: ENV["CRYSTAL_ENV"]? == "production" ? CQL::Adapter::Postgres : CQL::Adapter::SQLite,
  uri: ENV["DATABASE_URL"]? || "sqlite3://./db/blog_development.db?foreign_keys=1") do
  # ... generated table definitions ...
end
```

```bash
export CRYSTAL_ENV=production
export DATABASE_URL=postgres://user:pass@host:5432/blog_production
```

| Before deploying | Where |
| :--- | :--- |
| Values are bound as parameters by every CQL query; keep raw SQL to literals you control | [Use Raw SQL Fragments Safely](../../how-to/querying/raw-fragments.md) |
| Index the columns you filter and join on | [Create Indexes](../../how-to/migrations/indexes.md) |
| Load associations with `preload` instead of in a loop | [Avoid N+1 Queries](../../how-to/performance/n-plus-one.md) |
| Paginate every list | [Paginate Results](../../how-to/querying/pagination.md) |
| Cache expensive queries | [Enable Query Caching](../../how-to/caching/query-cache.md) |
| Size the connection pool | [Set Up Connection Pooling](../../how-to/configuration/connection-pooling.md) |

Authentication, authorization and rate limiting belong to your web framework.

## What you built

A blog engine with migrations, four associated models, validations, callbacks, transactions, seed data and statistics. To keep going:

- [Migration Workflows](../real-world-examples/migration-workflows.md) adds tags and a `featured` flag to this project.
- [Performance Monitoring](../real-world-examples/performance-monitoring.md) profiles it.
- The [How-to Guides](../../how-to/README.md), [Reference](../../reference/README.md) and [Explanation](../../explanation/README.md) cover each feature in depth.
