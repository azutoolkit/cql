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

`dependent` accepts `:destroy`, `:delete_all`, `:nullify` and `:restrict_with_error`. When you declare it, deleting the parent applies it (see [When the Parent Is Deleted](#when-the-parent-is-deleted)). The collection's `clear` follows it too, and nullifies when it is not declared.

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

`user.posts.clear` follows the association's `dependent` option (`:nullify` when none is declared, which sets `user_id` to NULL; it needs a nullable column).

## When the Parent Is Deleted

Declare `dependent:` to choose what `user.delete!` does with the user's posts:

```crystal
has_many :posts, Post, foreign_key: :user_id, dependent: :destroy
```

| `dependent:` | Effect on the posts when the user is deleted |
|---|---|
| `:destroy` | Loads each post and calls its `delete!`, so its callbacks and its own `dependent:` associations run; a post whose `before_destroy` halts raises `RelationError` and nothing is deleted |
| `:delete_all` | One `DELETE ... WHERE user_id = ?`, without callbacks |
| `:nullify` | One `UPDATE ... SET user_id = NULL`; the column must be nullable |
| `:restrict_with_error` | Raises `CQL::ActiveRecord::Relations::BaseRelation::RelationError` while the user has posts |
| not declared | Nothing; the database's foreign key decides (see below) |

The strategy reads the posts from the database, so it covers posts that were never loaded or were added after `user.posts` was loaded.

- **Order.** `:restrict_with_error` associations are checked first, before the `before_destroy` callbacks and before anything is deleted. The other strategies run after the callbacks, in declaration order, and the user's row is deleted last.
- **Transaction.** The strategies and the user's DELETE run in one transaction. If you already have one open, they run in a savepoint inside it, so a rollback restores everything, and an error in a strategy leaves both the posts and the user unchanged.
- **Soft deletes.** A [soft-deletable](../models/soft-delete.md) parent applies the strategies on `delete!` as well as `force_delete!`.
- **Bulk deletes.** `User.where(...).delete_all` deletes record by record, in one transaction, when the model declares any `dependent:` association, so it is slower than the bulk path. The class-level `User.delete!(id)`, `User.delete_by!` and `User.delete_all` write SQL directly and skip the strategies, except on a soft-deletable model, where `delete!(id)` and `delete_by!` soft delete each record through its `delete!` and apply them.

## Cascade Delete with Foreign Keys

Configure foreign key to cascade deletes:

```crystal
schema.table :posts do
  # ...
  foreign_key [:user_id], references: :users, references_columns: [:id], on_delete: :cascade
end
```

Now when a user row is deleted, the database deletes their posts. This also covers the class-level deletes (`User.delete!(id)`, `User.delete_by!`, `User.delete_all`), which skip `dependent:`. Leave `dependent:` undeclared if the foreign key should do the work alone.

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
