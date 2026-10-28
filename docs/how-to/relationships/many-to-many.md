---
description: "Link two models through a join table, such as posts that have many tags and tags that have many posts."
---

# Set Up Many-to-Many

## Create the Tables

The join table needs its own primary key, because a model maps it too:

```crystal
AppDB = CQL::Schema.define(:app_db, adapter: CQL::Adapter::SQLite, uri: "sqlite3://./app.db") do
  table :posts do
    primary :id, Int64, auto_increment: true
    column :title, String
  end

  table :tags do
    primary :id, Int64, auto_increment: true
    column :name, String
  end

  table :post_tags do
    primary :id, Int64, auto_increment: true
    column :post_id, Int64
    column :tag_id, Int64
    foreign_key [:post_id], references: :posts, references_columns: [:id], on_delete: :cascade
    foreign_key [:tag_id], references: :tags, references_columns: [:id], on_delete: :cascade
    index [:post_id, :tag_id], unique: true   # no duplicate links
  end
end
```

## Declare the Models

```crystal
class PostTag
  include CQL::ActiveRecord::Model(Int64)   # its db_context (here inferred) names the join table

  property post_id : Int64?
  property tag_id : Int64?

  belongs_to :post, Post, :post_id
  belongs_to :tag, Tag, :tag_id
end

class Post
  include CQL::ActiveRecord::Model(Int64)

  property title : String = ""

  many_to_many :tags, Tag, join_through: PostTag
end

class Tag
  include CQL::ActiveRecord::Model(Int64)

  property name : String = ""

  many_to_many :posts, Post, join_through: PostTag

  def initialize(@name : String = "")
  end
end
```

```crystal
many_to_many :tags, Tag, join_through: PostTag,   # or the snake_case symbol :post_tag
  foreign_key: :post_id,                          # default: owner name + _id, without namespace
  association_foreign_key: :tag_id,               # default: target name + _id, without namespace
  dependent: :nullify                             # :nullify (default), :destroy or :delete_all
```

Any other `dependent:` value fails to compile. The join matches `association_foreign_key` against the target's primary key column, so a target keyed on another column must declare it (see [Primary Key on Another Column](../models/define-model.md#primary-key-on-another-column)).

## Link Records

```crystal
post = Post.create!(title: "Hello")
crystal = Tag.create!(name: "Crystal")
orm = Tag.create!(name: "ORM")

post.tags << crystal                # find-or-creates the join row, so duplicates are ignored
post.add_tag(orm)                   # => Bool
post.tags.create(name: "Databases") # Tag.new + validated INSERT, then the join row
PostTag.create!(post_id: post.id!, tag_id: Tag.create!(name: "SQL").id!) # or write the join row
post.tags_ids = [crystal.id!, orm.id!]   # replaces the whole set; also post.tags.ids = [...]
```

Linking needs both records saved, or `UnsavedRecord` is raised. A soft-deleted record counts as saved: it is linked, and stays hidden from the collection.

## Read Linked Records

```crystal
post.tags.map(&.name)               # => ["Crystal", "ORM"]
post.tags.reload                    # reads them again
post.tags_count                     # => Int64
post.tags_any?                      # => Bool
post.tags_include?(crystal)         # => Bool
post.tags_ids                       # => Array(Int64)
post.tags.find(name: "Crystal")     # => Array(Tag)
post.tags.find_by(name: "Crystal")  # => Tag?
post.tags.exists?(name: "Crystal")  # => Bool
crystal.posts.map(&.title)          # => ["Hello"]
```

## Unlink Records

```crystal
post.remove_tag(orm)        # => Bool; or post.tags.delete(orm) => Tag?
post.tags.clear             # unlinks every tag, following dependent:
post.tags.delete_all        # => Int64 join rows removed; the tags stay, whatever dependent: says
```

`remove_tag`, `delete` and `clear` delete the join rows; then `:nullify` keeps the tags, `:destroy` calls each tag's `delete!`, and `:delete_all` deletes the tag rows. With `:destroy`, the join rows and the tags go in one transaction on the tag's schema: when a tag's `delete!` raises (a stale [locked](../models/optimistic-locking.md) one), every join row and tag stays. A join model on another schema has its rows deleted outside that transaction. `nullify_all` is the same as `delete_all`, because the link lives in the join row.

## Delete the Owner

`post.delete!` deletes the post's join rows first, even without `dependent:` and whether or not `post.tags` was loaded, in one transaction (a savepoint inside an open one) with the post's `DELETE`:

- **`:destroy`** also calls `delete!` on each tag. A tag whose `before_destroy` halts stays, without its join row, and the post is still deleted.
- **`:delete_all`** also deletes the tag rows without callbacks. A soft-deletable `Tag` is soft deleted instead, as `Tag.where(...).delete_all` would: tags already deleted keep their `deleted_at`, and destroy callbacks or `dependent:` associations on `Tag` make it go one `delete!` at a time.

`Post.where(...).delete_all` deletes record by record on a model with a `many_to_many`, so the join rows go too. The class-level `Post.delete!(id)`, `delete_by!` and `delete_all` skip them (except `delete!(id)` and `delete_by!` on a soft-deletable model); the `on_delete: :cascade` foreign keys above cover those.

## See Also

- [Set Up Has Many](has-many.md)
- [Set Up Belongs To](belongs-to.md)
- [Define a Model](../models/define-model.md)
- [Use Transactions](../data-operations/transactions.md)
- [Implement Soft Deletes](../models/soft-delete.md)
