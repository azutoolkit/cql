# Set Up Has Many

This guide shows you how to set up a has_many relationship where one model has multiple related records.

## When to Use

Use `has_many` when:
- A User has many Posts
- A Post has many Comments
- A Category has many Products

## Compile-Time Safety

CQL validates `has_many` declarations during compilation:

- The association name must be a symbol literal.
- The `foreign_key` option must be a symbol literal when provided.
- The `dependent` option must be one of `:destroy`, `:delete_all`, `:nullify`, or `:restrict_with_error`.
- If the target model is available during compilation, the target foreign key type must match the parent model primary key type.

Example:

```crystal
class Post
  include CQL::ActiveRecord::Model(Int64)

  has_many :comments, Comment, foreign_key: :post_id
end

class Comment
  include CQL::ActiveRecord::Model(Int32)

  property post_id : Int32?
end
```

This fails at compile time because `Comment#post_id` is `Int32` while `Post` uses an `Int64` primary key. Change `post_id` to `Int64?` or change the parent primary key type.

## Schema Setup

```crystal
schema.table :users do
  primary :id, Int64, auto_increment: true
  column :name, String
  timestamps
end
schema.users.create!

schema.table :posts do
  primary :id, Int64, auto_increment: true
  column :user_id, Int64, null: false
  column :title, String
  column :body, String
  timestamps

  foreign_key [:user_id], references: :users, references_columns: [:id]
  index [:user_id]
end
schema.posts.create!
```

## Define the Relationship

Add `has_many` to the parent model:

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :users

  property id : Int64?
  property name : String

  has_many :posts, Post, :user_id

  def initialize(@name : String)
  end
end

struct Post
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :posts

  property id : Int64?
  property user_id : Int64
  property title : String
  property body : String

  belongs_to :user, User, :user_id

  def initialize(@title : String, @body : String, @user_id : Int64)
  end
end
```

## Query Related Records

### Get All Related Records

```crystal
user = User.find(1)
posts = user.posts.all

posts.each do |post|
  puts post.title
end
```

### Count Related Records

```crystal
user = User.find(1)
count = user.posts.count
puts "User has #{count} posts"
```

### Filter Related Records

```crystal
user = User.find(1)

# Published posts only
published = user.posts.where(published: true).all

# Most recent posts
recent = user.posts.order(created_at: :desc).limit(5).all
```

## Create Related Records

```crystal
user = User.create!(name: "John")

# Create posts for user
post1 = Post.create!(
  title: "First Post",
  body: "Hello world",
  user_id: user.id.not_nil!
)

post2 = Post.create!(
  title: "Second Post",
  body: "Another post",
  user_id: user.id.not_nil!
)

user.posts.count  # => 2
```

## Delete Related Records

### Delete Specific Posts

```crystal
user = User.find(1)
user.posts.where(published: false).each(&.delete!)
```

### Delete All Posts

```crystal
user = User.find(1)
user.posts.all.each(&.delete!)
```

## Cascade Delete with Foreign Keys

Configure foreign key to cascade deletes:

```crystal
schema.table :posts do
  # ...
  foreign_key [:user_id], references: :users, references_columns: [:id], on_delete: :cascade
end
```

Now when a user is deleted, their posts are automatically deleted.

## Check for Related Records

```crystal
user = User.find(1)

if user.posts.count > 0
  puts "User has posts"
else
  puts "User has no posts"
end
```

## Verify It Works

```crystal
user = User.create!(name: "Test User")

Post.create!(title: "Post 1", body: "Body 1", user_id: user.id.not_nil!)
Post.create!(title: "Post 2", body: "Body 2", user_id: user.id.not_nil!)

user.posts.count  # => 2
user.posts.all.map(&.title)  # => ["Post 1", "Post 2"]
```

## Related

- [Set Up Belongs To](belongs-to.md)
- [Set Up Has One](has-one.md)
- [Set Up Many-to-Many](many-to-many.md)
