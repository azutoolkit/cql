# Set Up Belongs To

This guide shows you how to set up a belongs_to relationship where one model references another via a foreign key.

## When to Use

Use `belongs_to` when:
- A Comment belongs to a Post
- An Order belongs to a User
- A Photo belongs to an Album

The model with `belongs_to` holds the foreign key.

## Compile-Time Safety

CQL validates `belongs_to` declarations during compilation:

- The association name must be a symbol literal.
- The foreign key must be a symbol literal.
- The model must define a getter/property for the foreign key.
- If the target model is available during compilation, the foreign key type must match the target model primary key type.

This catches mistakes before the application starts:

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)
end

class Comment
  include CQL::ActiveRecord::Model(Int32)

  property user_id : Int32?

  # Raises at compile time because user_id is Int32 but User uses Int64 IDs.
  belongs_to :user, User, :user_id
end
```

The error message tells you which foreign key is wrong and which type to use. Forward-declared targets are also checked after all model files are loaded, provided the target type is required before compilation finishes.

## Schema Setup

Create tables with a foreign key column:

```crystal
schema.table :posts do
  primary :id, Int64, auto_increment: true
  column :title, String
  timestamps
end
schema.posts.create!

schema.table :comments do
  primary :id, Int64, auto_increment: true
  column :body, String
  column :post_id, Int64, null: false
  timestamps

  foreign_key [:post_id], references: :posts, references_columns: [:id]
end
schema.comments.create!
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

  belongs_to :post, Post, :post_id

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
schema.table :comments do
  # ...
  column :user_id, Int64, null: true  # Optional
end

struct Comment
  # ...
  property user_id : Int64?

  belongs_to :user, User, :user_id

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
