# Set Up Belongs To

This guide shows you how to set up a belongs_to relationship where one model references another via a foreign key.

## When to Use

Use `belongs_to` when:
- A Comment belongs to a Post
- An Order belongs to a User
- A Photo belongs to an Album

The model with `belongs_to` holds the foreign key.

## Schema Setup

Create tables with a foreign key column:

```crystal
schema.create :posts do
  primary :id, Int64, auto_increment: true
  text :title
  timestamps
end

schema.create :comments do
  primary :id, Int64, auto_increment: true
  text :body
  bigint :post_id, null: false
  timestamps

  foreign_key [:post_id], references: :posts, references_columns: [:id]
end
```

## Define the Relationship

Add `belongs_to` to the child model:

```crystal
struct Comment
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :comments

  property id : Int64?
  property body : String
  property post_id : Int64

  belongs_to :post, Post, foreign_key: :post_id

  def initialize(@body : String, @post_id : Int64)
  end
end
```

## Access the Parent

```crystal
comment = Comment.find(1)
post = comment.post  # Returns Post?

if post
  puts "Comment on: #{post.title}"
end
```

## Create with Parent

### Set Foreign Key Directly

```crystal
post = Post.create!(title: "My Post")

comment = Comment.new("Great post!", post.id.not_nil!)
comment.save!
```

### Set via Association

```crystal
post = Post.create!(title: "My Post")

comment = Comment.new("Great post!", 0_i64)
comment.post = post  # Sets post_id automatically
comment.save!
```

## Build Associated Parent

Build a parent without saving:

```crystal
comment = Comment.new("My comment", 0_i64)
post = comment.build_post(title: "New Post")

# Save parent, then child
post.save!
comment.post = post
comment.save!
```

## Create Associated Parent

Create and save parent in one step:

```crystal
comment = Comment.new("My comment", 0_i64)
post = comment.create_post(title: "New Post")

comment.save!  # post_id is now set
```

## Optional Belongs To

For optional relationships, make the foreign key nullable:

```crystal
schema.create :comments do
  # ...
  bigint :user_id, null: true  # Optional
end

struct Comment
  # ...
  property user_id : Int64?

  belongs_to :user, User, foreign_key: :user_id

  def initialize(@body : String, @post_id : Int64, @user_id : Int64? = nil)
  end
end

comment = Comment.find(1)
if user = comment.user
  puts "By: #{user.name}"
else
  puts "Anonymous"
end
```

## Verify It Works

```crystal
post = Post.create!(title: "Test Post")
comment = Comment.create!(body: "Test Comment", post_id: post.id.not_nil!)

comment.post.try(&.title)  # => "Test Post"
comment.post_id == post.id  # => true
```

## Related

- [Set Up Has Many](has-many.md)
- [Set Up Has One](has-one.md)
- [Define a Model](../models/define-model.md)
