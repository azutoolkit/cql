# Set Up Many-to-Many

This guide shows you how to set up a many-to-many relationship using a join table.

## When to Use

Use many-to-many when:
- A Post has many Tags, and a Tag has many Posts
- A User belongs to many Groups, and a Group has many Users
- A Product is in many Categories, and a Category has many Products

## Schema Setup

Create three tables: two main tables and a join table.

```crystal
schema.create :posts do
  primary :id, Int64, auto_increment: true
  text :title
  timestamps
end

schema.create :tags do
  primary :id, Int64, auto_increment: true
  text :name
  timestamps
end

# Join table
schema.create :post_tags do
  bigint :post_id, null: false
  bigint :tag_id, null: false
  timestamp :created_at

  foreign_key [:post_id], references: :posts, references_columns: [:id], on_delete: "CASCADE"
  foreign_key [:tag_id], references: :tags, references_columns: [:id], on_delete: "CASCADE"
end

schema.alter :post_tags do
  create_index :idx_post_tags_post, [:post_id]
  create_index :idx_post_tags_tag, [:tag_id]
  create_index :idx_post_tags_unique, [:post_id, :tag_id], unique: true
end
```

## Define the Models

### Post Model

```crystal
struct Post
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :posts

  property id : Int64?
  property title : String

  has_many :post_tags, PostTag, foreign_key: :post_id

  def initialize(@title : String)
  end

  # Helper to get tags
  def tags : Array(Tag)
    tag_ids = post_tags.all.map(&.tag_id)
    return [] of Tag if tag_ids.empty?
    Tag.where { id.in(tag_ids) }.all
  end

  # Helper to add a tag
  def add_tag(tag : Tag)
    PostTag.create!(post_id: id.not_nil!, tag_id: tag.id.not_nil!)
  end

  # Helper to remove a tag
  def remove_tag(tag : Tag)
    PostTag.where(post_id: id, tag_id: tag.id).each(&.delete!)
  end
end
```

### Tag Model

```crystal
struct Tag
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :tags

  property id : Int64?
  property name : String

  has_many :post_tags, PostTag, foreign_key: :tag_id

  def initialize(@name : String)
  end

  # Helper to get posts
  def posts : Array(Post)
    post_ids = post_tags.all.map(&.post_id)
    return [] of Post if post_ids.empty?
    Post.where { id.in(post_ids) }.all
  end
end
```

### Join Table Model

```crystal
struct PostTag
  include CQL::ActiveRecord::Model(Int64)
  db_context MyDB, :post_tags

  property post_id : Int64
  property tag_id : Int64
  property created_at : Time?

  belongs_to :post, Post, foreign_key: :post_id
  belongs_to :tag, Tag, foreign_key: :tag_id

  def initialize(@post_id : Int64, @tag_id : Int64)
  end
end
```

## Create Relationships

### Add Tags to a Post

```crystal
post = Post.create!(title: "My Post")
tag1 = Tag.create!(name: "Crystal")
tag2 = Tag.create!(name: "ORM")

# Add tags
post.add_tag(tag1)
post.add_tag(tag2)

post.tags.map(&.name)  # => ["Crystal", "ORM"]
```

### Create Join Records Directly

```crystal
PostTag.create!(post_id: post.id.not_nil!, tag_id: tag.id.not_nil!)
```

## Query Through Join Table

### Get Tags for a Post

```crystal
post = Post.find(1)
tags = post.tags
tags.each { |tag| puts tag.name }
```

### Get Posts for a Tag

```crystal
tag = Tag.find_by(name: "Crystal")
posts = tag.posts if tag
posts.each { |post| puts post.title }
```

### Find Posts with Specific Tag

```crystal
crystal_tag = Tag.find_by(name: "Crystal")
if crystal_tag
  post_ids = PostTag.where(tag_id: crystal_tag.id).all.map(&.post_id)
  crystal_posts = Post.where { id.in(post_ids) }.all
end
```

## Remove Relationships

### Remove a Tag from Post

```crystal
post.remove_tag(tag)
```

### Remove All Tags from Post

```crystal
post.post_tags.all.each(&.delete!)
```

## Verify It Works

```crystal
post = Post.create!(title: "Test")
tag = Tag.create!(name: "Test Tag")

post.add_tag(tag)

post.tags.map(&.name)  # => ["Test Tag"]
tag.posts.map(&.title)  # => ["Test"]

post.remove_tag(tag)
post.tags  # => []
```

## Related

- [Set Up Has Many](has-many.md)
- [Set Up Belongs To](belongs-to.md)
- [Use Transactions](../data-operations/transactions.md)
