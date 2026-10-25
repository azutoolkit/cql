# Set Up Has Many

This guide shows you how to set up a has_many relationship where one model has multiple related records.

## When to Use

Use `has_many` when:
- A User has many Posts
- A Post has many Comments
- A Category has many Products

## Options

```crystal
has_many :posts, Post                                  # foreign key defaults to user_id (owner name + _id)
has_many :posts, Post, :user_id                        # third argument is the foreign key
has_many :posts, Post, foreign_key: :author_id, dependent: :destroy
```

`dependent` accepts `:destroy`, `:delete_all`, `:nullify` and `:restrict_with_error`. It decides what `user.delete!` does with the posts (see [Deleting the Parent](#deleting-the-parent)) and what `user.posts.clear` does. Without `dependent:`, deleting the parent leaves the posts alone and `clear` nullifies.

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
  column :published, Bool, default: false
  column :views_count, Int64, default: 0_i64
  timestamps

  foreign_key [:user_id], references: :users, references_columns: [:id]
end
schema.posts.create!

# Index the foreign key (indexes are created with schema.alter, see Create Indexes)
schema.alter :posts do
  create_index :idx_posts_user_id, [:user_id]
end
```

## Define the Relationship

Add `has_many` to the parent model:

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :users

  property id : Int64?
  property name : String

  has_many :posts, Post, foreign_key: :user_id

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
  property published : Bool = false
  property views_count : Int64 = 0_i64
  property created_at : Time?

  belongs_to :user, User, :user_id

  def initialize(@title : String, @body : String, @user_id : Int64 = 0_i64)
  end
end
```

## Query Related Records

### Get All Related Records

```crystal
user = User.find!(1)
posts = user.posts.all

posts.each do |post|
  puts post.title
end
```

### Count Related Records

```crystal
user = User.find!(1)
count = user.posts.count
puts "User has #{count} posts"

user.posts_count   # Same count, as a generated method
user.posts_any?    # => Bool
```

### Filter Related Records

`user.posts.where`, `order`, `limit` and `offset` return a plain `CQL::Query` already scoped to the user, so finish with `.all(Post)`:

```crystal
user = User.find!(1)

# Published posts only
published = user.posts.where(published: true).all(Post)

# Most recent posts
recent = user.posts.order(created_at: :desc).limit(5).all(Post)

# Look up within the user's posts
user.posts.find(title: "First Post")        # => Array(Post)
user.posts.find_by(title: "First Post")     # => Post?
```

For the typed `where { ... }` DSL, scopes and `preload`, query the model directly: `Post.where(user_id: user.id!).where { views_count > 100 }.all`.

### Eager Load Related Records

```crystal
users = User.preload(:posts).all
users.each { |u| puts u.posts.size }   # no extra query per user
```

## Create Related Records

```crystal
user = User.create!(name: "John")

# Create posts through the collection (sets user_id for you; the model needs a default for it)
post1 = user.posts.create(title: "First Post", body: "Hello world")

# Or build, then add
post2 = Post.new("Second Post", "Another post", user.id!)
user.posts << post2

# Or create directly with the foreign key
Post.create!(title: "Third Post", body: "Yet another", user_id: user.id!)

user.posts.count  # => 3
```

The parent must be saved first; `user.posts` raises `CQL::ActiveRecord::Relations::BaseRelation::UnsavedRecord` otherwise.

## Delete Related Records

### Delete Specific Posts

```crystal
user = User.find!(1)
Post.where(user_id: user.id!, published: false).all.each(&.delete!)
```

### Delete All Posts

```crystal
user = User.find!(1)
user.posts.all.each(&.delete!)

# or in one statement, without callbacks
user.posts.delete_all
```

`user.posts.clear` follows the association's `dependent` option (`:nullify` without one, which sets `user_id` to NULL; it needs a nullable column).

## Deleting the Parent

With `dependent:` declared, `user.delete!` handles the posts before it deletes the user row:

| `dependent:` | What happens to the posts |
|---|---|
| `:destroy` | each post is loaded and deleted with `post.delete!`, running its callbacks |
| `:delete_all` | one `DELETE` statement, no post callbacks |
| `:nullify` | one `UPDATE` setting `user_id` to NULL (the column must be nullable) |
| `:restrict_with_error` | raises `RelationError` if any post exists, and nothing is deleted |
| not given | nothing; the posts keep their `user_id` |

```crystal
class User
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :users

  has_many :posts, Post, foreign_key: :user_id, dependent: :destroy
end

user.delete!   # destroys the user's posts, then the user
```

Some details:

- The handlers run after the model's `before_destroy` callbacks, so a callback that returns `false` stops the delete before any post is changed. `:restrict_with_error` associations are checked before the other handlers run.
- Each association with `dependent:` runs once per `delete!`. `has_one` and `many_to_many` follow the same rule.
- `:delete_all` and `:nullify` affect every row whose foreign key points at the parent, even on an association declared with `scope:`; `:destroy` and `:restrict_with_error` see only the scoped rows.
- Only hard deletes run the handlers. On a model with `CQL::ActiveRecord::SoftDeletable`, `delete!` (soft delete) leaves the posts alone and `force_delete!` handles them.
- The class methods `User.delete!(id)`, `User.delete_by!(...)` and `User.delete_all` issue a single `DELETE` and skip callbacks and `dependent:`. A scoped `User.where(...).delete_all` calls `delete!` on each matching record, so it runs them.
- The handlers and the parent delete are separate statements. Wrap them in `User.transaction { user.delete! }` when they must succeed or fail together.

## Cascade Delete with Foreign Keys

Configure foreign key to cascade deletes:

```crystal
schema.table :posts do
  # ...
  foreign_key [:user_id], references: :users, references_columns: [:id], on_delete: :cascade
end
```

Now when a user row is deleted, the database deletes their posts, including deletes that skip callbacks such as `User.delete!(id)`. Use `dependent: :destroy` instead when each post's callbacks must run.

## Check for Related Records

```crystal
user = User.find!(1)

if user.posts.count > 0
  puts "User has posts"
else
  puts "User has no posts"
end
```

## Verify It Works

```crystal
user = User.create!(name: "Test User")

Post.create!(title: "Post 1", body: "Body 1", user_id: user.id!)
Post.create!(title: "Post 2", body: "Body 2", user_id: user.id!)

user.posts.count  # => 2
user.posts.all.map(&.title)  # => ["Post 1", "Post 2"]
```

## Related

- [Set Up Belongs To](belongs-to.md)
- [Set Up Has One](has-one.md)
- [Set Up Many-to-Many](many-to-many.md)
