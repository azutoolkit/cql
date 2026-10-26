---
description: "Declare belongs_to on the model that holds the foreign key, such as a Comment with a post_id."
---

# Set Up Belongs To

## Declare the Association

```crystal
AppDB = CQL::Schema.define(:app_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://./app.db") do
  table :posts do
    primary :id, Int64, auto_increment: true
    column :title, String
  end

  table :comments do
    primary :id, Int64, auto_increment: true
    column :body, String
    column :post_id, Int64, null: true
    foreign_key [:post_id], references: :posts, references_columns: [:id]
  end
end

class Post
  include CQL::ActiveRecord::Model(Int64)

  property title : String = ""

  def initialize(@title : String = "")
  end
end

class Comment
  include CQL::ActiveRecord::Model(Int64)

  property body : String = ""
  property post_id : Int64?          # nilable even when the column is NOT NULL

  belongs_to :post, Post, :post_id   # or foreign_key: :post_id

  def initialize(@body : String = "", @post_id : Int64? = nil)
  end
end
```

Declare the foreign key nilable: `post=`, `create_post`, `delete_post` and `clear_post` assign `nil` to it, and they do not compile against an `Int64` property.

| Option | Default | Effect |
|---|---|---|
| `optional:` | `true` | `comment.post` returns `Post?`. With `false` it returns `Post` and raises `InvalidAssociation` when the foreign key is `nil` or `0`, or `DB::NoResultsError` when the post is missing. |
| `cache:` | `true` | The post is cached on the comment after the first read. With `false` it is read on every call, and `preload(:post)` silently skips it. |

## Read the Parent

```crystal
comment = Comment.find!(1)
comment.post.try(&.title)   # => "Hello" (Post?, read once, then cached)
comment.post_loaded?        # => true
comment.reload_post         # reads it again

# 2 queries for any number of comments: the comments, then
# SELECT ... FROM posts WHERE posts.id IN (?, ...) per chunk of the bind limit
Comment.preload(:post).all.each { |c| c.post.try(&.title) }
```

## Set and Change the Parent

```crystal
post = Post.create!(title: "Hello")

Comment.create!(body: "First", post_id: post.id!)   # set the foreign key directly

comment = Comment.new("Second")
comment.post = post         # sets post_id; the post must be saved (soft-deleted counts), or UnsavedRecord is raised
comment.save!

comment = Comment.new("Third")
comment.build_post(title: "Draft")     # Post.new(title: "Draft"): not saved, post_id unset
comment.create_post(title: "New")      # validates and INSERTs the post, sets post_id
comment.save!                          # the comment itself is not saved by create_post

comment.update_post(title: "Edited")   # assigns and save!s the post; AssociationNotFound if none
comment.delete_post                    # => Bool, DELETE without callbacks; clears post_id
comment.clear_post                     # post_id = nil (InvalidAssociation with optional: false)
```

`build_post` and `create_post` call `Post.new` with the arguments you pass, so `Post` needs a matching `initialize`.

## Rely on Compile-Time Checks

```crystal
class Reply
  include CQL::ActiveRecord::Model(Int64)

  property post_id : Int32?

  # Error: CQL belongs_to error in Reply: foreign key `:post_id` type Int32 does not match
  # Post.id! primary key type Int64. Change `:post_id` to Int64 or update the target model primary key type.
  belongs_to :post, Post, :post_id
end
```

The association name and foreign key must be Symbol literals, and the foreign key needs a getter. A target declared later is checked once all files are loaded.

## See Also

- [Set Up Has Many](has-many.md)
- [Set Up Has One](has-one.md)
- [Avoid N+1 Queries](../performance/n-plus-one.md)
- [Define a Model](../models/define-model.md)
- [Add Validations](../models/add-validations.md)
