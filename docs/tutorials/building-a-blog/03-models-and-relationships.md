---
description: "Map the four tables to model classes, connect them with associations, and try them out."
---

# Part 3: Models and Relationships

**You need:** the project from [Part 2](02-database-schema.md), with `src/schemas/app_schema.cr` generated. Every model points at that `AppSchema` with `db_context`.

{% stepper %}
{% step %}
### Create the User model

{% code title="src/models/user.cr" %}
```crystal
class User
  include CQL::ActiveRecord::Model(Int64) # adds the id primary key
  db_context AppSchema, :users

  property username : String
  property email : String
  property first_name : String?
  property last_name : String?
  property active : Bool = true
  property created_at : Time?
  property updated_at : Time?

  has_many :posts, Post, :user_id
  has_many :comments, Comment, :user_id

  def initialize(@username : String, @email : String,
                 @first_name : String? = nil, @last_name : String? = nil, @active : Bool = true)
  end

  def full_name : String
    [first_name, last_name].compact.join(" ").presence || username
  end

  def display_name : String
    first_name || username
  end
end
```
{% endcode %}

Each `property` maps the column of the same name. Models are classes, not structs, so that `save` can set the new `id` on the instance you hold.
{% endstep %}

{% step %}
### Create the Category model

{% code title="src/models/category.cr" %}
```crystal
class Category
  include CQL::ActiveRecord::Model(Int64)
  db_context AppSchema, :categories

  property name : String
  property slug : String
  property created_at : Time?
  property updated_at : Time?

  has_many :posts, Post, :category_id

  def initialize(@name : String, slug : String? = nil)
    @slug = slug || Category.generate_slug(@name)
  end

  # "Web Development" -> "web-development"
  def self.generate_slug(text : String) : String
    text.downcase.gsub(/[^a-z0-9\s-]/, "").gsub(/\s+/, "-").gsub(/-+/, "-").strip("-")
  end
end
```
{% endcode %}
{% endstep %}

{% step %}
### Create the Post model

{% code title="src/models/post.cr" %}
```crystal
class Post
  include CQL::ActiveRecord::Model(Int64)
  db_context AppSchema, :posts

  property title : String
  property content : String
  property published : Bool = false
  property views_count : Int64 = 0_i64
  property user_id : Int64
  property category_id : Int64? # nilable: a post may have no category
  property created_at : Time?
  property updated_at : Time?

  belongs_to :user, User, :user_id
  belongs_to :category, Category, :category_id
  has_many :comments, Comment, :post_id

  def initialize(@title : String, @content : String, @user_id : Int64,
                 @category_id : Int64? = nil, @published : Bool = false, @views_count : Int64 = 0_i64)
  end

  def published? : Bool
    published
  end

  def word_count : Int32
    content.split.size
  end

  def reading_time_minutes : Int32
    (word_count / 200.0).ceil.to_i # 200 words per minute
  end

  def excerpt(length : Int32 = 150) : String
    content.size <= length ? content : content[0, length].rstrip + "..."
  end

  def increment_views!
    @views_count += 1
    save
  end
end
```
{% endcode %}
{% endstep %}

{% step %}
### Create the Comment model

{% code title="src/models/comment.cr" %}
```crystal
class Comment
  include CQL::ActiveRecord::Model(Int64)
  db_context AppSchema, :comments

  property content : String
  property post_id : Int64
  property user_id : Int64? # nil for anonymous comments
  property created_at : Time?
  property updated_at : Time?

  belongs_to :post, Post, :post_id
  belongs_to :user, User, :user_id

  def initialize(@content : String, @post_id : Int64, @user_id : Int64? = nil)
  end

  def author_name : String
    user.try(&.display_name) || "Anonymous"
  end
end
```
{% endcode %}
{% endstep %}

{% step %}
### Load the models in the entry point

Replace `src/blog_engine.cr`:

{% code title="src/blog_engine.cr" %}
```crystal
require "./database"
require "./schemas/app_schema"
require "./models/*"
require "../migrations/*"

module BlogEngine
  VERSION = "0.1.0"

  def self.setup
    AppSchema.exec("SELECT 1")
    puts "Database connected"
  end

  def self.migrate
    migrator = AppSchema.migrator(MIGRATOR_CONFIG)
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

The migrator now runs on `AppSchema` too, because it knows the existing tables. Later migrations that alter or drop a table need that: on the empty `AppDB`, `schema.alter :posts` raises `Table 'posts' not found` and `schema.posts.drop!` raises `KeyError`.

Associations may name a model that is required later, such as `User` naming `Post`. CQL checks every `belongs_to` and `has_many` once all files are loaded, and reports a missing target model, or a foreign key whose type does not match the target's primary key, as a compile-time error.
{% endstep %}

{% step %}
### Try the models

{% code title="src/test_models.cr" %}
```crystal
require "./blog_engine"

BlogEngine.setup

alice = User.new(username: "alice", email: "alice@example.com", first_name: "Alice", last_name: "Johnson")
alice.save!
puts "Created user: #{alice.full_name} (ID: #{alice.id})"

tech = Category.new("Technology")
tech.save!
puts "Created category: #{tech.name} (slug: #{tech.slug})"

post = Post.new(
  title: "Getting Started with Crystal",
  content: "Crystal is a wonderful programming language...",
  user_id: alice.id!,
  category_id: tech.id,
  published: true
)
post.save!
puts "Created post: #{post.title} (#{post.word_count} words, #{post.reading_time_minutes} min read)"

comment = Comment.new(content: "Great article!", post_id: post.id!, user_id: alice.id)
comment.save!
puts "Created comment by: #{comment.author_name}"

puts "Alice's posts: #{alice.posts.all.map(&.title)}"
puts "Post author: #{post.user.try(&.full_name)}"
puts "Post category: #{post.category.try(&.name)}"
puts "Post comments: #{post.comments.count}"

# Clean up so the script can run again: the ON DELETE CASCADE keys remove Alice's posts and comments
alice.delete!
tech.delete!
puts "Cleaned up: #{Post.count} posts, #{Comment.count} comments left"
```
{% endcode %}

```bash
crystal src/test_models.cr
```

```text
Database connected
Created user: Alice Johnson (ID: 1)
Created category: Technology (slug: technology)
Created post: Getting Started with Crystal (6 words, 1 min read)
Created comment by: Alice
Alice's posts: ["Getting Started with Crystal"]
Post author: Alice Johnson
Post category: Technology
Post comments: 1
Cleaned up: 0 posts, 0 comments left
```

The ID grows on each run.
{% endstep %}
{% endstepper %}

## What the associations add

| Declaration | Adds | Use |
| :--- | :--- | :--- |
| `belongs_to :user, User, :user_id` | `post.user`, a `User?` | `post.user.try(&.full_name)` |
| `has_many :posts, Post, :user_id` | `user.posts`, a collection scoped to the user | `user.posts.all` (an `Array(Post)`), `user.posts.count` (a `COUNT(*)` query) |

To filter one user's posts in the database, query the model: `Post.where(user_id: user.id!, published: true).all`.

{% content-ref url="04-crud-operations.md" %}
[04-crud-operations.md](04-crud-operations.md)
{% endcontent-ref %}
