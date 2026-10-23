# Set Up Many-to-Many

This guide shows you how to set up a many-to-many relationship using a join table.

## When to Use

Use many-to-many when:
- A Post has many Tags, and a Tag has many Posts
- A User belongs to many Groups, and a Group has many Users
- A Product is in many Categories, and a Category has many Products

## Schema Setup

Create three tables: two main tables and a join table. The join table needs its own primary key because it is mapped by a model too.

```crystal
schema.table :posts do
  primary :id, Int64, auto_increment: true
  column :title, String
  timestamps
end
schema.posts.create!

schema.table :tags do
  primary :id, Int64, auto_increment: true
  column :name, String
  timestamps
end
schema.tags.create!

# Join table, named after the join model (PostTag -> post_tag)
schema.table :post_tag do
  primary :id, Int64, auto_increment: true
  column :post_id, Int64, null: false
  column :tag_id, Int64, null: false
  timestamps

  foreign_key [:post_id], references: :posts, references_columns: [:id], on_delete: :cascade
  foreign_key [:tag_id], references: :tags, references_columns: [:id], on_delete: :cascade
end
schema.post_tag.create!

# Prevent duplicate links (indexes are created with schema.alter, see Create Indexes)
schema.alter :post_tag do
  create_index :idx_post_tag_unique, [:post_id, :tag_id], unique: true
end
```

## Define the Models

### Join Table Model

```crystal
struct PostTag
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :post_tag

  property post_id : Int64?
  property tag_id : Int64?

  belongs_to :post, Post, :post_id
  belongs_to :tag, Tag, :tag_id

  def initialize(@post_id : Int64? = nil, @tag_id : Int64? = nil)
  end
end
```

### Post and Tag Models

Use the `many_to_many` macro on both sides:

```crystal
struct Post
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :posts

  property id : Int64?
  property title : String
  property created_at : Time?
  property updated_at : Time?

  many_to_many :tags, Tag, join_through: PostTag

  def initialize(@title : String)
  end
end

struct Tag
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :tags

  property id : Int64?
  property name : String
  property created_at : Time?
  property updated_at : Time?

  many_to_many :posts, Post, join_through: PostTag

  def initialize(@name : String)
  end
end
```

The macro signature is `many_to_many(name, klass, join_through, foreign_key = nil, association_foreign_key = nil, dependent = :nullify, validate = true, autosave = false)`. Two naming conventions matter:

- The association name must match the target table name (`:tags` for the `tags` table), because the generated join is built from it.
- `join_through` is the join model class (or its snake_case name as a symbol, like `:movies_actor` for `MoviesActor`), and its table name must be the underscored class name (`PostTag` -> `post_tag`).

Foreign keys default to the owner's name plus `_id` (`post_id`) and the target's name plus `_id` (`tag_id`). Override them with `foreign_key:` and `association_foreign_key:`.

## Create Relationships

### Add Tags to a Post

```crystal
post = Post.create!(title: "My Post")
tag1 = Tag.create!(name: "Crystal")
tag2 = Tag.create!(name: "ORM")

# Add existing tags (creates the join rows, ignores duplicates)
post.tags << tag1
post.add_tag(tag2)

# Create a new tag and link it in one step
post.tags.create(name: "Databases")

post.tags.reload
post.tags.map(&.name)  # => ["Crystal", "ORM", "Databases"]
```

### Replace the Whole Set

```crystal
post.tags_ids = [tag1.id!, tag2.id!]   # also available as post.tags.ids = [...]
```

### Create Join Records Directly

```crystal
PostTag.create!(post_id: post.id!, tag_id: tag1.id!)
```

## Query Through Join Table

### Get Tags for a Post

```crystal
post = Post.find!(1)
post.tags.each { |tag| puts tag.name }

post.tags_count          # => Int64
post.tags_any?           # => Bool
post.tags_include?(tag)  # => Bool
post.tags_ids            # => Array(Int64)
```

### Get Posts for a Tag

```crystal
tag = Tag.find_by(name: "Crystal")
tag.posts.each { |post| puts post.title } if tag
```

### Find Within the Association

```crystal
post.tags.find(name: "Crystal")           # => Array(Tag)
post.tags.find_by(name: "Crystal")        # => Tag?
post.tags.exists?(name: "Crystal")        # => Bool
```

## Remove Relationships

### Remove a Tag from Post

```crystal
post.remove_tag(tag)    # or post.tags.delete(tag)
```

This deletes the join row. What happens to the tag itself depends on `dependent:`: `:nullify` (the default) leaves it alone, `:destroy` and `:delete_all` also remove the tag.

### Remove All Tags from Post

```crystal
post.tags.clear
```

## Verify It Works

```crystal
post = Post.create!(title: "Test")
tag = Tag.create!(name: "Test Tag")

post.add_tag(tag)

post.tags.reload
post.tags.map(&.name)    # => ["Test Tag"]
tag.posts.map(&.title)   # => ["Test"]

post.remove_tag(tag)
post.tags.reload
post.tags.to_a           # => []
```

## Related

- [Set Up Has Many](has-many.md)
- [Set Up Belongs To](belongs-to.md)
- [Use Transactions](../data-operations/transactions.md)
