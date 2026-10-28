---
description: "Declare has_many on the model whose related records hold the foreign key, such as a User with many posts."
---

# Set Up Has Many

## Declare the Association

```crystal
AppDB = CQL::Schema.define(:app_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://./app.db") do
  table :users do
    primary :id, Int64, auto_increment: true
    column :name, String
  end

  table :posts do
    primary :id, Int64, auto_increment: true
    column :user_id, Int64, null: true
    column :title, String
    column :published, Bool, default: false
    foreign_key [:user_id], references: :users, references_columns: [:id]
    index [:user_id]
  end
end

class User
  include CQL::ActiveRecord::Model(Int64)

  property name : String = ""

  has_many :posts, Post, foreign_key: :user_id, dependent: :destroy
end

class Post
  include CQL::ActiveRecord::Model(Int64)

  property user_id : Int64?
  property title : String = ""
  property published : Bool = false

  belongs_to :user, User, :user_id

  def initialize(@title : String = "", @published : Bool = false)
  end
end
```

```crystal
has_many :posts, Post                     # foreign key user_id: owner name + _id (Blog::User -> user_id)
has_many :posts, Post, :author_id         # or foreign_key: :author_id
has_many :posts, Post, dependent: :nullify # :destroy, :delete_all, :nullify or :restrict_with_error
```

These fail to compile: a non-literal name or `foreign_key`, another `dependent:` value, a foreign key whose type differs from the owner's key type (`Post#user_id : Int32?` against `Model(Int64)`), and a foreign key that is the target's own primary key.

## Read the Posts

```crystal
user = User.find!(1)
user.posts.all              # => Array(Post), loaded once and cached on the collection
user.reload_posts           # forgets the cache after posts were written elsewhere
user.posts.count            # => Int64: SELECT COUNT(*) unless already loaded
user.posts_count            # same
user.posts_any?             # => Bool
user.posts.find(title: "Hello")       # => Array(Post)
user.posts.find_by(title: "Hello")    # => Post?
user.posts.exists?(published: true)   # => Bool

# where, order, limit and offset return a CQL::Query scoped to the user
user.posts.where(published: true).order(id: :desc).limit(5).all(Post)

# For the typed DSL and scopes, query the model
Post.where(user_id: user.id!).where { title.like("H%") }.all

User.preload(:posts).all    # one extra query per chunk of the bind limit
```

## Add Posts

```crystal
user = User.create!(name: "Ada")   # the parent must be saved, or UnsavedRecord is raised

user.posts.create(title: "First")  # Post.new(title: "First"), user_id set, validated INSERT
user.posts.build(title: "Draft")   # same, not saved
user.posts << Post.new("Second")   # sets user_id and INSERTs without validation
user.posts << post                 # a saved post: sets user_id and UPDATEs it, with validations and callbacks
user.create_posts([Post.new("Third")])

# One multi-row INSERT per chunk; no validations or callbacks; returns the row count
user.insert_posts_all([{title: "Fourth"}, {title: "Fifth"}])  # => 2
```

`insert_posts_all` sets `user_id` on every row, replacing any value a row gives, and takes hashes or named tuples and `batch_size:` as `insert_all` does; the foreign key counts toward the bind-parameter limit.

## Remove Posts

```crystal
user.posts.delete(post)      # => Bool: DELETE of that post if it is the user's, without callbacks
user.posts.delete_all        # => Int64: one DELETE ... WHERE posts.user_id = ?, without callbacks
user.posts.nullify_all       # => Int64: one UPDATE ... SET user_id = NULL
user.posts.clear             # follows dependent: (nullifies when undeclared or :restrict_with_error)
user.posts.ids = [3_i64, 4_i64] # points those posts at the user
```

With `dependent: :destroy`, `clear` calls each post's `delete!` in one transaction: when one raises (a stale [locked](../models/optimistic-locking.md) post), it rolls back and every post stays, those deleted before it included.

## When the Parent Is Deleted

`dependent:` chooses what `user.delete!` does with the user's posts. It reads them from the database, so it covers posts never loaded or added since `user.posts` was loaded:

| `dependent:` | Effect on the posts |
|---|---|
| `:destroy` | Calls each post's `delete!`, so its callbacks and own `dependent:` associations run. A halting `before_destroy` raises `RelationError` and nothing is deleted. |
| `:delete_all` | One `DELETE ... WHERE user_id = ?`, without callbacks |
| `:nullify` | One `UPDATE ... SET user_id = NULL`; the column must be nullable |
| `:restrict_with_error` | Raises `CQL::ActiveRecord::Relations::BaseRelation::RelationError` while the user has posts |
| not declared | Nothing; the database's foreign key decides |

- **Order.** `:restrict_with_error` is checked first, before `before_destroy` and before anything is deleted. The other strategies run after the callbacks, in declaration order, and the user's row goes last.
- **Transaction.** The strategies and the user's `DELETE` run in one transaction, or a savepoint inside an open one, so an error leaves the posts and the user unchanged.
- **Soft deletes.** A [soft-deletable](../models/soft-delete.md) user applies them on `delete!` and `force_delete!`.
- **Bulk deletes.** `User.where(...).delete_all` deletes record by record, in one transaction, when the model declares any `dependent:`. The class-level `User.delete!(id)`, `delete_by!` and `delete_all` skip the strategies, except that a soft-deletable model's `delete!(id)` and `delete_by!` go through each record's `delete!`.

To cover the class-level deletes too, let the database cascade, and leave `dependent:` undeclared if it should do the work alone:

```crystal
foreign_key [:user_id], references: :users, references_columns: [:id], on_delete: :cascade
```

## See Also

- [Set Up Belongs To](belongs-to.md)
- [Set Up Has One](has-one.md)
- [Set Up Many-to-Many](many-to-many.md)
- [Delete Records](../data-operations/delete.md)
- [Avoid N+1 Queries](../performance/n-plus-one.md)
- [Implement Soft Deletes](../models/soft-delete.md)
